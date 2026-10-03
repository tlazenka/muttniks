package muttniks.controllers

import play.api.*
import play.api.ApplicationLoader.Context
import play.api.db.{DBComponents, HikariCPComponents}
import play.api.db.evolutions.EvolutionsComponents
import play.api.routing.Router
import play.filters.HttpFiltersComponents

import scala.concurrent.Future

final class MuttniksApplicationLoader extends ApplicationLoader:
  override def load(context: Context): Application =
    LoggerConfigurator(context.environment.classLoader).foreach:
      _.configure(
        context.environment,
        context.initialConfiguration,
        Map.empty
      )

    new MuttniksComponents(context).application


final class MuttniksComponents(context: Context)
  extends BuiltInComponentsFromContext(context)
    with DBComponents
    with HikariCPComponents
    with EvolutionsComponents
    with HttpFiltersComponents
    with _root_.controllers.AssetsComponents:

  applicationEvolutions

  private given scala.concurrent.ExecutionContext = executionContext

  lazy val database =
    new SkunkDatabase(configuration.underlying)

  lazy val likeEvaluator =
    new LikeEvaluator()

  lazy val healthController =
    new HealthController(controllerComponents)

  lazy val petController =
    new PetController(
      controllerComponents,
      database
    )

  lazy val ssrController =
    new SsrController(
      controllerComponents,
      database,
      configuration.underlying
    )

  lazy val likeController =
    new LikeController(
      controllerComponents,
      database,
      likeEvaluator
    )

  lazy val chainSync =
    new ChainSync(
      configuration,
      database
    )

  chainSync.start()

  applicationLifecycle.addStopHook { () =>
    chainSync.stop()
    Future.successful(())
  }

  override lazy val router: Router =
    new _root_.router.Routes(
      httpErrorHandler,
      ssrController,
      healthController,
      petController,
      likeController,
      assets
    )