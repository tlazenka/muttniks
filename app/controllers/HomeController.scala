package controllers

import java.io.InputStream

import javax.inject.{Inject, Singleton}
import java.math.BigInteger
import java.time.Instant
import java.util.concurrent.TimeUnit

import com.muttniks.pet._
import contracts.Adoption
import helpers.Helpers
import play.api.mvc.{AbstractController, ControllerComponents}
import okhttp3.OkHttpClient
import org.slf4j.Logger
import org.web3j.crypto.Credentials
import org.web3j.protocol.Web3j
import org.web3j.protocol.http.HttpService
import play.Environment
import play.api.cache.AsyncCacheApi
import play.api.libs.json._
import play.api.libs.ws.WSClient

// For Joda implicit -- don't remove
import play.api.libs.json.JodaWrites._
import play.api.libs.json.JodaReads._

import scala.io.Source
import scala.concurrent.Future
import scala.compat.java8.FutureConverters._

object PetListPageType extends Enumeration {
  val Generic: PetListPageType.Value = Value(0)
  val NotAdopted: PetListPageType.Value = Value(1)
  val PetsByAdopter: PetListPageType.Value = Value(2)
}

@Singleton
class HomeController @Inject() (petDAO: PetDAO,
                                petDAOExecutionContext: PetDAOExecutionContext,
                                ws: WSClient,
                                cache: AsyncCacheApi,
                                environment: Environment,
                                cc: ControllerComponents) extends AbstractController(cc) {

  private val logger: Logger = org.slf4j.LoggerFactory.getLogger(this.getClass)

  private val adoptersLastUpdatedKey = "adopters_last_updated"

  val defaultPageSize: Int = sys.env("PET_PAGE_SIZE").toInt

  val web3HttpServicePrivateUrl: String = sys.env("ETH_PRIVATE_URL")
  val web3HttpServicePublicUrl: String = sys.env("ETH_PUBLIC_URL")

  implicit val ec: PetDAOExecutionContext = petDAOExecutionContext

  implicit val petFormat: OFormat[Pet] = Json.format[Pet]

  def stringFromResource(name: String): String = {
    val stream : InputStream = getClass.getResourceAsStream(name)
    Source.fromInputStream(stream).getLines.mkString
  }

  def jsonFromResource(name: String): JsValue = {
    Json.parse(stringFromResource(name = name))
  }

  val adoptionJson: JsValue = jsonFromResource("/Adoption.json")

  def numPets(): Future[Int] = {
    petDAO.count
  }

  def pets(page: Int, pageSize: Int): Future[Page[Pet]] = {
    for {
      petsPage <- petDAO.getPets(page = page, pageSize = pageSize)
    } yield {
      petsPage
    }
  }

  def petsAndJson(page: Int, pageSize: Int): Future[(Page[Pet], JsArray)] = {
    for {
      petsPage <- pets(page = page, pageSize = pageSize)
      petsJson = JsArray(petsPage.items.map { Json.toJson(_) })
    } yield {
      (petsPage, petsJson)
    }
  }

  def petAndPage(externalId: Long): Future[(Page[Pet], Seq[Pet])] = {
    val page = 0
    val pageSize = 1
    for {
      petPage: Page[Pet] <- petDAO.getPets(page = page, pageSize = pageSize, externalIds = Some(Seq((externalId))))
      pets: Seq[Pet] = petPage.items
    } yield (petPage, pets)
  }

  def petAndJson(externalId: Long): Future[(Page[Pet], JsArray)] = {
    for {
      petAndPage <- petAndPage(externalId = externalId)
      m = petAndPage._2.map { i => Json.toJson(i) }
      petJson = JsArray(m)
    }
      yield (petAndPage._1, petJson)
  }

  def updatePetAdopters(): Future[Int] = {
    for {
      petsAndAdopters <- petsAndAdopters()
      j = petsAndAdopters.map(i => petDAO.upsertPetAdopter(i._1.externalId, Some(i._2)))
      m <- Future.sequence(j)
      _ <- cache.set(adoptersLastUpdatedKey, Instant.now.getEpochSecond)
    }
    yield m.length
  }

  def lastKnownAdoptersUpdate(): Future[JsObject] = {
    for {
      lastUpdated <- cache.get[Long](adoptersLastUpdatedKey)
      result = JsObject(Map(
        ("adoptersLastUpdated", Json.toJson(lastUpdated))
      ))
    }
      yield result
  }

  def cachedPetsByAdopter(adopter: String, page: Int, pageSize: Int): Future[Page[Pet]] = {
    for {
      petsPage <- petDAO.petsByAdopter(page, pageSize, adopter)
    } yield {
      petsPage
    }
  }

  def cachedPetsByAdopterJson(adopter: String, page: Int, pageSize: Int): Future[JsArray] = {
    for {
      page <- cachedPetsByAdopter(adopter = adopter, page = page, pageSize = pageSize)
      items = JsArray(page.items.map { Json.toJson(_) })
    }
      yield items
  }


  val serverAccountPrivateKey: String = sys.env("ETH_SERVER_ACCOUNT_PRIVATE_KEY")
  val credentials: Credentials = Credentials.create(serverAccountPrivateKey)
  val gasLimit: Long = sys.env("ETH_GAS_LIMIT").toLong
  val gasPrice: Long = sys.env("ETH_GAS_PRICE").toLong
  val adoptionContractAddress: String = sys.env("ETH_ADOPTION_CONTRACT_ADDRESS")

  val timeoutSeconds: Long = sys.env.getOrElse("WEB3J_TIMEOUT_SECONDS", 10.toString).toLong

  val httpClient: OkHttpClient = new OkHttpClient.Builder()
    .connectTimeout(timeoutSeconds, TimeUnit.SECONDS)
    .readTimeout(timeoutSeconds, TimeUnit.SECONDS)
    .writeTimeout(timeoutSeconds, TimeUnit.SECONDS)
    .build()


  val web3j: Web3j = Web3j.build(new HttpService(web3HttpServicePrivateUrl, httpClient, false))
  val adoption: Adoption = Adoption.load(adoptionContractAddress, web3j, credentials, BigInteger.valueOf(gasPrice), BigInteger.valueOf(gasLimit))

  def petsAndAdopters(): Future[Seq[(Pet, String)]] = {
    for {
      allPets <- petDAO.allPets()
      futPetsAndAdoptersIds = allPets.map { i => adoption.adopterOf(BigInteger.valueOf(i.externalId)).sendAsync().toScala.map(j => { (i, j) }) }
      petsAndAdoptersIds <- Future.sequence(futPetsAndAdoptersIds)
    } yield {
      petsAndAdoptersIds
    }
  }

  def petsAndAdoptersJson(): Future[JsArray] = {
    petsAndAdopters().map(i => { JsArray(i.map { Json.toJson(_) }) })
  }

  def adopt(petId: Long, privateKey: String): Future[String] = {
    val credentials = Credentials.create(privateKey)
    val adoption: Adoption = Adoption.load(adoptionContractAddress, web3j, credentials, BigInteger.valueOf(gasPrice), BigInteger.valueOf(gasLimit))
    val id = BigInteger.valueOf(petId)
    for {
      isAdopted <- adoption.isAdopted(id).sendAsync().toScala
      transactionReceipt <- if (!(isAdopted)) { adoption.adopt(id).sendAsync().toScala } else { Future.failed(new Exception(s"Pet ${id} is already adopted")) }
    }
      yield transactionReceipt.getTransactionHash
  }

  def assignName(petId: Long, name: String, privateKey: String): Future[String] = {
    if (!(Helpers.isAscii(name))) {
      Future.failed(new Exception(s"${name} is not an Ascii string"))
    }
    else {
      val credentials = Credentials.create(privateKey)
      val adopterAddress = credentials.getAddress
      val adoption: Adoption = Adoption.load(adoptionContractAddress, web3j, credentials, BigInteger.valueOf(gasPrice), BigInteger.valueOf(gasLimit))
      val id = BigInteger.valueOf(petId)
      for {
        isAdopted <- adoption.isAdopted(id).sendAsync().toScala
        currentAdopter <- if (isAdopted) { adoption.adopterOf(id).sendAsync().toScala } else { Future.failed(new Exception(s"Pet ${id} is not adopted")) }
        transactionReceipt <- if (adopterAddress == currentAdopter)
          { adoption.assignName(BigInteger.valueOf(petId), name.padTo(32, ' ').getBytes()).sendAsync().toScala } else
          { Future.failed(new Exception(s"Adopter of ${id} is: ${currentAdopter} not: ${adopterAddress}")) }
      }
        yield transactionReceipt.getTransactionHash
    }
  }
}
