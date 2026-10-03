package muttniks.controllers

import cats.effect.IO
import cats.syntax.all.*
import com.typesafe.config.Config
import play.api.mvc.*

import scala.concurrent.ExecutionContext

final class SsrController(
  cc: ControllerComponents,
  database: SkunkDatabase,
  config: Config
)(using ec: ExecutionContext) extends AbstractController(cc):

  private val PageSize = 4
  private val adoptionAddress = config.getString("muttniks.ethereum.adoption-address")
  private val chainId = config.getLong("muttniks.ethereum.chain-id")

  def index(page: Int) = Action.async:
    val safePage = page.max(1)
    val offset = (safePage.toLong - 1L) * PageSize
    val result = for
      pets <- database.pets.page(offset, PageSize)
      total <- database.pets.count
      rows <- pets.foldLeft(IO.pure(List.empty[(muttniks.domain.PetListing, muttniks.domain.LikeCounts)])) { (acc, pet) =>
        (acc, database.likes.counts(pet.id)).mapN((rows, counts) => rows :+ (pet -> counts))
      }
    yield (rows, total)
    result.unsafeToFuture()(using database.runtime).map { case (rows, total) =>
      Ok(views.html.index(rows, safePage, PageSize, total, adoptionAddress, chainId))
    }
