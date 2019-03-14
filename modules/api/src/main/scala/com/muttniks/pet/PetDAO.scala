package com.muttniks.pet

import org.joda.time.DateTime

import scala.concurrent.{ExecutionContext, Future}

/**
 * An implementation dependent DAO.  This could be implemented by Slick, Cassandra, or a REST API.
 */
trait PetDAO {

  def close(): Future[Unit]

  def count(implicit ec: ExecutionContext): Future[Int]

  def getPets(page: Int = 0, pageSize: Int, externalIds: Option[Seq[Long]] = None)(implicit ec: ExecutionContext): Future[Page[Pet]]

  def allPets()(implicit ec: ExecutionContext): Future[Seq[Pet]]

  def upsertPetAdopter(petExternalId: Long, adopterAddress: Option[String], createdAt: DateTime = DateTime.now(), updatedAt: Option[DateTime] = None)(implicit ec: ExecutionContext): Future[Int]

  def petsByAdopter(page: Int, pageSize: Int, adopterAddress: String)(implicit ec: ExecutionContext): Future[Page[Pet]]

}

/**
 * Implementation independent aggregate root.
 *
 * Note that this uses Joda Time classes and UUID, which are specifically mapped
 * through the custom postgres driver.
 */
case class Pet(externalId: Long, internalId: java.util.UUID, title: Option[String], imageSource: Option[String], createdAt: DateTime, updatedAt: Option[DateTime] = None)

trait PetDAOExecutionContext extends ExecutionContext

case class Page[A](items: Seq[A], page: Int, offset: Int, total: Int) {
  lazy val previous: Option[Int] = Option(page - 1).filter(_ >= 0)
  lazy val next: Option[Int] = Option(page + 1).filter(_ => (offset + items.size) < total)
}
