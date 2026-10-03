package muttniks.controllers

import scala.jdk.CollectionConverters.*
import muttniks.domain.LikeObservation
import muttniks.likes.{TackyLikeRules, Like, LikeContext}

final case class LikeDecision(decision: String, reasons: Seq[String])

final class LikeEvaluator():
  private val rules = new TackyLikeRules(10, 5, 10L, 60L)

  private def toLike(v: LikeObservation): Like =
    new Like(v.likeId, v.petId, v.session, v.network, v.epochSecond, v.sessionCreatedAtEpochSecond)

  def evaluate(current: LikeObservation, recent: Seq[LikeObservation]): LikeDecision =
    val result = rules.evaluate(new LikeContext(toLike(current), recent.map(toLike).asJava))
    LikeDecision(result.getDisposition.toString.toLowerCase, result.getReasons.asScala.toSeq)
