package muttniks.controllers

import org.bouncycastle.jcajce.provider.digest.Keccak
import play.api.{Configuration, Logger}
import play.api.libs.json.*

import java.net.URI
import java.net.http.{HttpClient, HttpRequest, HttpResponse}
import java.nio.charset.StandardCharsets
import java.time.Duration
import cats.effect.IO
import muttniks.persistence.SyncedChainEvent
import scala.concurrent.{ExecutionContext, Future}
import scala.concurrent.duration.*
import scala.util.control.NonFatal

private[controllers] final case class ChainEvent(
    kind: String,
    petId: Long,
    blockNumber: Long,
    blockHash: String,
    transactionHash: String,
    logIndex: Int,
    adopter: Option[String] = None,
    recipient: Option[String] = None,
    assignedName: Option[String] = None
)

private[controllers] object EthereumSync:
  def finalizedHead(head: Long, confirmations: Long): Long = math.max(0L, head - confirmations)

  def findCommonAncestor(start: Long, stored: Long => Option[String], canonical: Long => Option[String]): Long =
    Iterator.iterate(start)(_ - 1).takeWhile(_ >= 0).find(n => stored(n) == canonical(n)).getOrElse(-1L)

  def quantity(n: Long): String =
    require(n >= 0, "Quantity can't be negative")
    s"0x${java.lang.Long.toHexString(n)}"

  def parseQuantity(value: String): Long =
    require(value.startsWith("0x"), s"Invalid quantity: $value")
    java.lang.Long.parseUnsignedLong(value.drop(2), 16)

final class ChainSync(
    config: Configuration,
    database: SkunkDatabase
)(using ec: ExecutionContext):
  private val logger = Logger(getClass)
  private val rpcUrl = config.get[String]("muttniks.ethereum.rpc-url")
  private val chainId = config.get[Long]("muttniks.ethereum.chain-id")
  private val address = config.get[String]("muttniks.ethereum.adoption-address").toLowerCase
  private val confirmations = config.get[Long]("muttniks.ethereum.confirmations")
  private val startBlock = config.get[Long]("muttniks.ethereum.start-block")
  private val poll = config.get[FiniteDuration]("muttniks.ethereum.poll-interval")
  @volatile private var running = false

  private val http = HttpClient
    .newBuilder()
    .version(HttpClient.Version.HTTP_1_1)
    .connectTimeout(Duration.ofSeconds(5))
    .build()

  private def topic(signature: String): String =
    val digest = new Keccak.Digest256()
    digest.update(signature.getBytes(StandardCharsets.UTF_8))
    "0x" + digest.digest().map(b => f"${b & 0xff}%02x").mkString

  private val petCreated = topic("PetCreated(uint256)")
  private val adopted = topic("Adopted(uint256,address)")
  private val transferred = topic("Transferred(uint256,address,address)")
  private val nameAssigned = topic("NameAssigned(uint256,bytes32)")

  def start(): Unit =
    if !running then
      running = true
      Future(blockingLoop())

  def stop(): Unit = running = false

  private def rpc(method: String, params: JsArray): JsValue =
    val body = Json.stringify(Json.obj("jsonrpc" -> "2.0", "id" -> 1, "method" -> method, "params" -> params))
    val request = HttpRequest
      .newBuilder(URI.create(rpcUrl))
      .timeout(Duration.ofSeconds(10))
      .header("content-type", "application/json")
      .POST(HttpRequest.BodyPublishers.ofString(body))
      .build()
    val response = http.send(request, HttpResponse.BodyHandlers.ofString())
    if response.statusCode() >= 400 then
      throw RuntimeException(s"Ethereum HTTP ${response.statusCode()}: ${response.body()}")
    val json = Json.parse(response.body())
    (json \ "error").toOption.foreach(e => throw RuntimeException(s"Ethereum JSON RPC error: $e"))
    (json \ "result").get

  private def blockNumber(): Long = EthereumSync.parseQuantity(rpc("eth_blockNumber", Json.arr()).as[String])
  private def block(n: Long): JsObject = rpc("eth_getBlockByNumber", Json.arr(EthereumSync.quantity(n), false)) match
    case o: JsObject => o
    case JsNull => throw RuntimeException(s"Block $n not found")
    case x => throw RuntimeException(s"Unexpected response: $x")
  private def blockHash(n: Long): String = (block(n) \ "hash").as[String]
  private def logs(from: Long, to: Long): Vector[JsObject] =
    rpc(
      "eth_getLogs",
      Json.arr(
        Json.obj(
          "address" -> address,
          "fromBlock" -> EthereumSync.quantity(from),
          "toBlock" -> EthereumSync.quantity(to)
        )
      )
    )
      .as[JsArray]
      .value
      .map(_.as[JsObject])
      .toVector

  private def wordLong(word: String): Long = java.lang.Long.parseUnsignedLong(word.stripPrefix("0x").takeRight(16), 16)
  private def wordAddress(word: String): String = "0x" + word.stripPrefix("0x").takeRight(40).toLowerCase
  private def bytes32Text(word: String): String =
    val bytes = word.stripPrefix("0x").grouped(2).map(Integer.parseInt(_, 16).toByte).toArray
    new String(bytes.takeWhile(_ != 0), StandardCharsets.UTF_8)

  private def decode(log: JsObject): ChainEvent =
    val topics = (log \ "topics").as[Seq[String]]
    val sig = topics.head.toLowerCase
    val base = (
      wordLong(topics(1)),
      EthereumSync.parseQuantity((log \ "blockNumber").as[String]),
      (log \ "blockHash").as[String],
      (log \ "transactionHash").as[String],
      EthereumSync.parseQuantity((log \ "logIndex").as[String]).toInt
    )
    sig match
      case `petCreated` => ChainEvent("pet/created", base._1, base._2, base._3, base._4, base._5)
      case `adopted` =>
        ChainEvent("pet/adopted", base._1, base._2, base._3, base._4, base._5, adopter = Some(wordAddress(topics(2))))
      case `transferred` =>
        ChainEvent(
          "pet/transferred",
          base._1,
          base._2,
          base._3,
          base._4,
          base._5,
          adopter = Some(wordAddress(topics(2))),
          recipient = Some(wordAddress(topics(3)))
        )
      case `nameAssigned` =>
        ChainEvent(
          "pet/name-assigned",
          base._1,
          base._2,
          base._3,
          base._4,
          base._5,
          assignedName = Some(bytes32Text((log \ "data").as[String]))
        )
      case other => throw RuntimeException(s"Unknown Adoption event topic $other")

  private val repository = database.sync(chainId, address)
  private def run[A](io: IO[A]): A = io.unsafeRunSync()(using database.runtime)

  private def checkpoint: Option[(Long, String)] = run(repository.checkpoint)
  private def storedBlock(n: Long): Option[String] = run(repository.storedBlock(n))
  private def identity: Option[String] = run(repository.identity)

  private def ensureIdentity(): Unit =
    val current = blockHash(0)
    identity match
      case Some(old) if old != current => run(repository.resetForIdentity(current))
      case None => run(repository.saveIdentity(current))
      case _ => ()

  private def recover(searchStart: Long): Unit =
    val ancestor = EthereumSync.findCommonAncestor(searchStart, storedBlock, n => Some(blockHash(n)))
    run(repository.recover(ancestor))

  private def ensureCanonical(head: Long): Unit = checkpoint.foreach { case (n, hash) =>
    val start = math.min(n, head)
    if n > head || blockHash(n) != hash then recover(start)
  }

  private def synced(e: ChainEvent): SyncedChainEvent =
    SyncedChainEvent(
      e.kind,
      e.petId,
      e.blockNumber,
      e.blockHash,
      e.transactionHash,
      e.logIndex,
      e.adopter,
      e.recipient,
      e.assignedName
    )

  private def ingest(from: Long, to: Long): Unit = if from <= to then
    val byBlock = logs(from, to).map(decode).groupBy(_.blockNumber)
    (from to to).foreach { n =>
      val hash = blockHash(n)
      val applied = run(repository.ingestBlock(n, hash, byBlock.getOrElse(n, Vector.empty).map(synced)))
      applied.foreach(e => logger.info(s"sync type=${e.kind} pet=${e.petId} block=$n"))
    }

  private def step(): Unit =
    ensureIdentity()
    val head = blockNumber()
    ensureCanonical(head)
    val target = EthereumSync.finalizedHead(head, confirmations)
    val from = checkpoint.map(_._1 + 1).getOrElse(startBlock)
    ingest(from, target)

  private def blockingLoop(): Unit =
    logger.info(s"Chain sync started rpc=$rpcUrl chain=$chainId contract=$address confirmations=$confirmations")
    while running do
      try step()
      catch case NonFatal(e) => logger.error("Chain sync failed", e)
      Thread.sleep(poll.toMillis)
