package controllers

import javax.inject.{Inject, Singleton}

import com.muttniks.pet._
import play.api.Configuration
import play.api.http.HttpErrorHandler
import play.api.i18n.I18nSupport
import play.api.libs.json.JsValue
import play.api.libs.ws.WSClient
import play.api.mvc.{AbstractController, ControllerComponents, _}
import views.html

@Singleton
class FrontEndController @Inject() (petDAO: PetDAO,
                                    homeController: HomeController,
                                    assets: Assets,
                                    config: Configuration,
                                    errorHandler: HttpErrorHandler,
                                    ws: WSClient,
                                    cc: ControllerComponents) extends AbstractController(cc) with I18nSupport {

  implicit val ec: PetDAOExecutionContext = homeController.ec

  val adoptionJson: JsValue = homeController.adoptionJson
  val web3HttpServicePublicUrl: String = homeController.web3HttpServicePublicUrl
  val defaultPageSize: Int = homeController.defaultPageSize

  def assetOrDefault(resource: String): Action[AnyContent] = if (resource.startsWith(config.get[String]("apiPrefix"))) {
    Action.async(r => errorHandler.onClientError(r, NOT_FOUND, "Not found"))
  } else {
    if (resource.contains(".")) assets.at(resource) else index
  }

  def index: Action[AnyContent] = all()

  def all(page: Int = 0): Action[AnyContent] = Action.async { implicit request =>
    for {
      petsPageAndJson <- homeController.petsAndJson(page = page, pageSize = defaultPageSize)
    } yield {
      Ok(html.allPets(
        petsJson = petsPageAndJson._2,
        adoptionContractJson = adoptionJson,
        web3HttpServiceUrl = web3HttpServicePublicUrl,
        currentPage = petsPageAndJson._1
      ))
    }
  }

}
