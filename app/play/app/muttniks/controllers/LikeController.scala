package muttniks.controllers

import play.api.libs.json.*
import play.api.mvc.*
import scala.concurrent.{ExecutionContext, Future}
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.time.Instant
import java.util.UUID
import muttniks.domain.LikeObservation

final class LikeController(
    cc: ControllerComponents,
    database: SkunkDatabase,
    likeEvaluator: LikeEvaluator
)(using ec: ExecutionContext)
    extends AbstractController(cc):
  private def hash(value: String): String =
    MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)).map("%02x".format(_)).mkString

  def create(petId: Long): Action[JsValue] = Action.async(parse.json) { request =>
    val session = (request.body \ "session").asOpt[String].filter(_.nonEmpty)
    val sessionCreated = (request.body \ "sessionCreatedAtEpochSecond").asOpt[Long]
    (session, sessionCreated) match
      case (Some(s), Some(created)) =>
        val now = Instant.now().getEpochSecond
        val like =
          LikeObservation(UUID.randomUUID().toString, petId, hash(s), hash(request.remoteAddress), now, created)
        val action = for
          _ <- database.likes.insertPending(like)
          recent <- database.likes.recent(now)
          decision = likeEvaluator.evaluate(like, recent.filterNot(_.likeId == like.likeId))
          _ <- database.likes.classify(like.likeId, decision.decision, decision.reasons)
          counts <- database.likes.counts(petId)
        yield Created(
          Json.obj(
            "likeId" -> like.likeId,
            "decision" -> decision.decision,
            "reasons" -> decision.reasons,
            "rawLikes" -> counts.raw,
            "trustedLikes" -> counts.trusted
          )
        )
        action.unsafeToFuture()(using database.runtime).recover { case e =>
          InternalServerError(Json.obj("error" -> "like_failed", "message" -> e.getMessage))
        }
      case _ => Future.successful(BadRequest(Json.obj("error" -> "invalid_like")))
  }
