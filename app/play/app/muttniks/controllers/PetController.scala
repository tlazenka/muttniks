package muttniks.controllers

import play.api.libs.json.*
import play.api.mvc.*
import muttniks.domain.*

import scala.concurrent.{ExecutionContext, Future}

final class PetController(
  cc: ControllerComponents,
  database: SkunkDatabase
)(using ec: ExecutionContext) extends AbstractController(cc):

  private def json(pet: PetListing, counts: LikeCounts): JsObject = Json.obj(
    "id" -> pet.id,
    "name" -> pet.name,
    "status" -> (if pet.adopter.isDefined then "adopted" else "unadopted"),
    "adopter" -> pet.adopter,
    "imageUrl" -> pet.imageUrl,
    "rawLikes" -> counts.raw,
    "trustedLikes" -> counts.trusted
  )

  def get(id: Long) = Action.async:
    if id < 0 then Future.successful(BadRequest(Json.obj("error" -> "invalid_pet_id")))
    else
      database.pets.find(id).unsafeToFuture()(using database.runtime).flatMap:
        case Some(pet) => database.likes.counts(id).unsafeToFuture()(using database.runtime).map(c => Ok(json(pet, c)))
        case None => Future.successful(NotFound(Json.obj("error" -> "pet_not_found", "id" -> id)))
