package controllers

import javax.inject.{Inject, Singleton}

import com.muttniks.pet._
import org.slf4j.Logger
import play.Environment
import play.api.i18n.I18nSupport
import play.api.libs.json._
import play.api.libs.ws.WSClient
import play.api.mvc.{AbstractController, ControllerComponents, _}

import scala.concurrent.Future

@Singleton
class ApiController @Inject() (petDAO: PetDAO,
                               homeController: HomeController,
                               ws: WSClient,
                               environment: Environment,
                               cc: ControllerComponents) extends AbstractController(cc) with I18nSupport {

  private val logger: Logger = org.slf4j.LoggerFactory.getLogger(this.getClass)

  implicit val ec: PetDAOExecutionContext = homeController.ec

  val adoptionJson: JsValue = homeController.adoptionJson
  val web3HttpServicePublicUrl: String = homeController.web3HttpServicePublicUrl
  val defaultPageSize: Int = homeController.defaultPageSize

  def petsAndPageResult(pets: JsArray, currentPage: Int): JsObject = JsObject(Map(
    ("pets", pets),
    ("nextPage", JsNumber(currentPage + 1)))
  )

  def numPets(): Action[AnyContent] = Action.async { implicit request =>
    homeController.numPets().map {
      numPets =>
        val result = JsObject(Map(("numPets", JsNumber(numPets))))
        Ok(result)
    }
  }

  def pets(page: Int = 0): Action[AnyContent] = Action.async { implicit request =>
    homeController.petsAndJson(page = page, pageSize = defaultPageSize).map {
      petsPageAndJson => Ok(
        petsAndPageResult(petsPageAndJson._2, page)
      )
    }
  }

  def pet(externalId: Long): Action[AnyContent] = Action.async { implicit request =>
    homeController.petAndJson(externalId = externalId).map { petsPageAndJson => Ok(petsPageAndJson._2) }
  }

  def petsAndAdopters(): Action[AnyContent] = Action.async { implicit request =>
    homeController.petsAndAdoptersJson().map { i =>
      Ok(
        JsObject(Map(("pets", i)))
      )
    }
  }

  def lastKnownAdoptersUpdate(): Action[AnyContent] = Action.async { implicit request =>
    homeController.lastKnownAdoptersUpdate().map { Ok(_) }
  }

  def petsByAdopter(adopter: String, page: Int, pageSize: Int = defaultPageSize): Action[AnyContent] = Action.async { implicit request =>
    homeController.cachedPetsByAdopterJson(adopter: String, page: Int, pageSize: Int).map { Ok(_) }
  }

  def adopt(petId: Long, privateKey: String): Action[AnyContent] = Action.async { implicit request =>
    (for {
      transactionHash <- homeController.adopt(petId = petId, privateKey = privateKey)
    } yield Ok(JsObject(Map(("transactionHash", JsString(transactionHash))))))
      .recoverWith { case e => Future { BadRequest(e.getLocalizedMessage) } }
  }

  def assignName(petId: Long, name: String, privateKey: String): Action[AnyContent] = Action.async { implicit request =>
    (for {
      transactionHash <- homeController.assignName(petId = petId, name = name, privateKey = privateKey)
    } yield Ok(JsObject(Map(("transactionHash", JsString(transactionHash))))))
      .recoverWith { case e => Future { BadRequest(e.getLocalizedMessage) } }
  }
}
