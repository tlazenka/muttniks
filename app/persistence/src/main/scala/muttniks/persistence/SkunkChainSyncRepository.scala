package muttniks.persistence

import cats.effect.{IO, Resource}
import cats.syntax.all.*
import skunk.*
import skunk.codec.all.*
import skunk.implicits.*

final case class SyncedChainEvent(
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

final class SkunkChainSyncRepository(
    session: Resource[IO, Session[IO]],
    chainId: Long,
    contractAddress: String
):
  private val checkpointQ = sql"""select last_finalized_block, block_hash from chain_sync_checkpoint
    where chain_id=$int8 and contract_address=$text""".query(int8 *: text)
  private val blockQ = sql"""select block_hash from chain_sync_blocks
    where chain_id=$int8 and contract_address=$text and block_number=$int8""".query(text)
  private val identityQ = sql"""select genesis_hash from chain_sync_identity
    where chain_id=$int8 and contract_address=$text""".query(text)

  private val saveIdentityC = sql"""insert into chain_sync_identity(chain_id,contract_address,genesis_hash)
    values($int8,$text,$text) on conflict(chain_id,contract_address) do update
    set genesis_hash=excluded.genesis_hash, observed_at=now()""".command
  private val deleteEventsC = sql"delete from processed_chain_events where chain_id=$int8".command
  private val deleteEventsAfterC =
    sql"delete from processed_chain_events where chain_id=$int8 and block_number>$int8".command
  private val deleteBlocksC = sql"delete from chain_sync_blocks where chain_id=$int8 and contract_address=$text".command
  private val deleteBlocksAfterC =
    sql"delete from chain_sync_blocks where chain_id=$int8 and contract_address=$text and block_number>$int8".command
  private val deleteCheckpointC =
    sql"delete from chain_sync_checkpoint where chain_id=$int8 and contract_address=$text".command
  private val deletePetsC = sql"delete from pets".command
  private val replayQ = sql"""select event_type,pet_id,adopter,recipient,assigned_name from processed_chain_events
    where chain_id=$int8 order by block_number,log_index""".query(text *: int8 *: text.opt *: text.opt *: text.opt)

  private val markQ = sql"""insert into processed_chain_events
    (chain_id,transaction_hash,log_index,block_number,block_hash,event_type,pet_id,adopter,recipient,assigned_name)
    values($int8,$text,$int4,$int8,$text,$text,$int8,${text.opt},${text.opt},${text.opt})
    on conflict(chain_id,transaction_hash,log_index) do nothing returning transaction_hash""".query(text)
  private val createPetC =
    sql"insert into pets(id,adopter,name) values($int8,null,null) on conflict(id) do nothing".command
  private val adoptPetC =
    sql"insert into pets(id,adopter) values($int8,$text) on conflict(id) do update set adopter=excluded.adopter".command
  private val transferPetC = sql"update pets set adopter=$text where id=$int8".command
  private val namePetC = sql"update pets set name=$text where id=$int8".command
  private val saveBlockC = sql"""insert into chain_sync_blocks(chain_id,contract_address,block_number,block_hash)
    values($int8,$text,$int8,$text) on conflict do nothing""".command
  private val saveCheckpointC =
    sql"""insert into chain_sync_checkpoint(chain_id,contract_address,last_finalized_block,block_hash)
    values($int8,$text,$int8,$text) on conflict(chain_id,contract_address) do update
    set last_finalized_block=excluded.last_finalized_block, block_hash=excluded.block_hash""".command

  def checkpoint: IO[Option[(Long, String)]] = session.use(_.option(checkpointQ)((chainId, contractAddress)))
  def storedBlock(n: Long): IO[Option[String]] = session.use(_.option(blockQ)((chainId, contractAddress, n)))
  def identity: IO[Option[String]] = session.use(_.option(identityQ)((chainId, contractAddress)))

  def resetForIdentity(hash: String): IO[Unit] = session.use { s =>
    s.transaction.use { _ =>
      resetChainOn(s) *> s.execute(saveIdentityC)((chainId, contractAddress, hash)).void
    }
  }
  def saveIdentity(hash: String): IO[Unit] =
    session.use(_.execute(saveIdentityC)((chainId, contractAddress, hash)).void)

  def recover(ancestor: Long): IO[Unit] = session.use { s =>
    s.transaction.use { _ =>
      for
        _ <- s.execute(deleteEventsAfterC)((chainId, ancestor))
        _ <- s.execute(deleteBlocksAfterC)((chainId, contractAddress, ancestor))
        _ <- s.execute(deletePetsC)
        rows <- s.execute(replayQ)(chainId)
        _ <- rows.traverse_ { case (kind, petId, adopter, recipient, assignedName) =>
          applyEventOn(s, SyncedChainEvent(kind, petId, 0, "", "", 0, adopter, recipient, assignedName))
        }
        _ <-
          if ancestor < 0 then s.execute(deleteCheckpointC)((chainId, contractAddress)).void
          else
            s.option(blockQ)((chainId, contractAddress, ancestor)).flatMap {
              case Some(hash) => saveCheckpointOn(s, ancestor, hash)
              case None => IO.raiseError(new IllegalStateException(s"Missing block $ancestor"))
            }
      yield ()
    }
  }

  def ingestBlock(n: Long, hash: String, events: Vector[SyncedChainEvent]): IO[Vector[SyncedChainEvent]] = session.use {
    s =>
      s.transaction.use { _ =>
        events
          .foldLeft(IO.pure(Vector.empty[SyncedChainEvent])) { (acc, event) =>
            acc.flatMap { applied =>
              s.option(markQ)(
                (
                  chainId,
                  event.transactionHash,
                  event.logIndex,
                  event.blockNumber,
                  event.blockHash,
                  event.kind,
                  event.petId,
                  event.adopter,
                  event.recipient,
                  event.assignedName
                )
              ).flatMap {
                case Some(_) => applyEventOn(s, event).as(applied :+ event)
                case None => IO.pure(applied)
              }
            }
          }
          .flatTap(_ => s.execute(saveBlockC)((chainId, contractAddress, n, hash)).void *> saveCheckpointOn(s, n, hash))
      }
  }

  private def resetChainOn(s: Session[IO]): IO[Unit] =
    s.execute(deleteEventsC)(chainId).void *>
      s.execute(deleteBlocksC)((chainId, contractAddress)).void *>
      s.execute(deleteCheckpointC)((chainId, contractAddress)).void *>
      s.execute(deletePetsC).void

  private def saveCheckpointOn(s: Session[IO], n: Long, hash: String): IO[Unit] =
    s.execute(saveCheckpointC)((chainId, contractAddress, n, hash)).void

  private def applyEventOn(s: Session[IO], e: SyncedChainEvent): IO[Unit] = e.kind match
    case "pet/created" => s.execute(createPetC)(e.petId).void
    case "pet/adopted" =>
      s.execute(adoptPetC)(
        (e.petId, e.adopter.getOrElse(throw new IllegalStateException("Adopted event missing adopter")))
      ).void
    case "pet/transferred" =>
      s.execute(transferPetC)(
        (e.recipient.getOrElse(throw new IllegalStateException("Transferred event missing recipient")), e.petId)
      ).void
    case "pet/name-assigned" =>
      s.execute(namePetC)(
        (e.assignedName.getOrElse(throw new IllegalStateException("Name event missing name")), e.petId)
      ).void
    case other => IO.raiseError(new IllegalArgumentException(s"Unknown event $other"))
