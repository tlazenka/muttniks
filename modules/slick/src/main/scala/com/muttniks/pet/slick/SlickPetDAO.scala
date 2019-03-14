package com.muttniks.pet.slick

import javax.inject.{Inject, Singleton}
import com.muttniks.slick.generated.Tables
import org.joda.time.DateTime
import slick.driver.JdbcProfile
import slick.jdbc.JdbcBackend.Database
import slick.lifted.TableQuery
import com.muttniks.pet._

import scala.concurrent.{ExecutionContext, Future}
import scala.language.implicitConversions

/**
 * A DAO implemented with Slick, leveraging Slick code gen.
 *
 * Note that you must run "flyway/flywayMigrate" before "compile" here.
 */
@Singleton
class SlickPetDAO @Inject()(db: Database) extends PetDAO with Tables {

  private val pets = TableQuery[Pets]
  private val petAdopters = TableQuery[PetAdopter]

  // Use the custom postgresql driver.
  override val profile: JdbcProfile = MyPostgresDriver

  import profile.api._

  def count(implicit ec: ExecutionContext): Future[Int] = {
    db.run(pets.length.result)
  }

  def count(externalIds: Option[Seq[Long]])(implicit ec: ExecutionContext): Future[Int] = {
    db.run(queryPets(externalIds = externalIds).length.result)
  }

  def queryPets(externalIds: Option[Seq[Long]] = None)(implicit ec: ExecutionContext): Query[Pets, PetsRow, Seq] = {
    externalIds match {
      case None => pets
      case Some(ids) => pets.filter(pet =>
        ids.map {
          case (externalId: Long) =>
            (pet.externalId === externalId)
        }.reduce((_: Rep[Boolean]) || (_: Rep[Boolean]))
      )
    }

  }

  def getPets(page: Int, pageSize: Int, externalIds: Option[Seq[Long]] = None)(implicit ec: ExecutionContext): Future[Page[Pet]] = {
    val offset = pageSize * page
    val query0 = queryPets(externalIds = externalIds)
    val query1 = query0 joinLeft PetDisplay on ((y, x) => { (x.petExternalId === y.externalId) })
    val query3 = query1
      .drop(offset)
      .take(pageSize)

    for {
      total <- count(externalIds = externalIds)
      i <- db.run(query3.result)
      items = i.map(i => { petsRowToPet(petsRow = i._1, petDisplayRow = i._2) })
    } yield Page(items = items, page = page, offset = offset, total = total)
  }

  def allPets()(implicit ec: ExecutionContext): Future[Seq[Pet]] = {
    for {
      i <- db.run(pets.result)
      items = i.map(i => { petsRowToPet(petsRow = i, petDisplayRow = None) })
    }
      yield items
  }

  def create(pet: Pet)(implicit ec: ExecutionContext): Future[Int] = {
    db.run(
      Pets += petToPetsRow(pet.copy(createdAt = DateTime.now()))
    )
  }

  def upsertPetAdopter(petExternalId: Long, adopterAddress: Option[String], createdAt: DateTime = DateTime.now(), updatedAt: Option[DateTime] = None)(implicit ec: ExecutionContext): Future[Int] = {
    val m = for {
      rowsUpdated <- petAdopters.filter(r => r.petExternalId === petExternalId).map(_.adopter).update(adopterAddress)
      result <- rowsUpdated match {
          case 0 => petAdopters += PetAdopterRow(petExternalId, adopterAddress, createdAt, updatedAt)
          case 1 => DBIO.successful(1)
          case n => DBIO.failed(new RuntimeException(s"For petExternalId ${petExternalId}: expected 0 or 1 rows affected, got ${n}"))
        }
    } yield result
    db.run(m)
  }

  def petsByAdopter(page: Int, pageSize: Int, adopterAddress: String)(implicit ec: ExecutionContext): Future[Page[Pet]] = {
    val offset = pageSize * page
    val p = petAdopters.filter(r => r.adopter === adopterAddress)
    val z = pets.join(p).on((i, j) => j.petExternalId === i.externalId)
    val f = z joinLeft PetDisplay on ((y, x) => { (x.petExternalId === y._1.externalId) })
    val n = f.drop(offset)
      .take(pageSize)

    for {
      total <- db.run(f.length.result)
      i <- db.run(n.result)
      items = i.map(i => petsRowToPet(i._1._1, i._2))
    } yield Page(items = items, page = page, offset = offset, total = total)
  }

  def close(): Future[Unit] = {
    Future.successful(db.close())
  }

  private def petToPetsRow(pet: Pet): PetsRow = {
    PetsRow(
      externalId = pet.externalId,
      internalId = pet.internalId,
      createdAt = pet.createdAt,
      updatedAt = pet.updatedAt
    )
  }

  private def petsRowToPet(petsRow: PetsRow, petDisplayRow:Option[PetDisplayRow]): Pet = {
    Pet(
      externalId = petsRow.externalId,
      internalId = petsRow.internalId,
      title = petDisplayRow.flatMap(_.title),
      imageSource = petDisplayRow.flatMap(_.imageSource),
      createdAt = petsRow.createdAt,
      updatedAt = petsRow.updatedAt
    )
  }

}
