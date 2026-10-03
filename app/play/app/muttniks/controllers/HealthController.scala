package muttniks.controllers

import play.api.mvc.*

final class HealthController(cc: ControllerComponents) extends AbstractController(cc):
  def health = Action { Ok("{\"status\":\"ok\"}").as("application/json") }
