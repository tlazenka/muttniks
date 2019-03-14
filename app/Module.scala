import javax.inject.{Inject, Provider, Singleton}

import com.muttniks.pet.slick.SlickPetDAO
import com.muttniks.pet.{PetDAO, PetDAOExecutionContext}
import com.google.inject.AbstractModule
import com.typesafe.config.Config
import helpers.{CacheTask}
import play.api.inject.ApplicationLifecycle
import play.api.{Configuration, Environment}

import scala.concurrent.{ExecutionContext, Future}

class Module(environment: Environment,
             configuration: Configuration) extends AbstractModule {
  override def configure(): Unit = {
    bind(classOf[PetDAOExecutionContext]).toProvider(classOf[SlickPetDAOExecutionContextProvider])

    bind(classOf[slick.jdbc.JdbcBackend.Database]).toProvider(classOf[DatabaseProvider])
    bind(classOf[PetDAO]).to(classOf[SlickPetDAO])

    bind(classOf[PetDAOCloseHook]).asEagerSingleton()
  }
}

class CacheTaskModule(environment: Environment,
                         configuration: Configuration) extends AbstractModule {
  override def configure(): Unit = {
    bind(classOf[CacheTask]).asEagerSingleton()
  }
}

@Singleton
class DatabaseProvider @Inject() (config: Config) extends Provider[slick.jdbc.JdbcBackend.Database] {

  private val db = slick.jdbc.JdbcBackend.Database.forConfig("myapp.database", config)

  override def get(): slick.jdbc.JdbcBackend.Database = db
}

@Singleton
class SlickPetDAOExecutionContextProvider @Inject() (actorSystem: akka.actor.ActorSystem) extends Provider[PetDAOExecutionContext] {
  private val instance = {
    val ec = actorSystem.dispatchers.lookup("myapp.database-dispatcher")
    new SlickPetDAOExecutionContext(ec)
  }

  override def get(): SlickPetDAOExecutionContext = instance
}

class SlickPetDAOExecutionContext(ec: ExecutionContext) extends PetDAOExecutionContext {
  override def execute(runnable: Runnable): Unit = ec.execute(runnable)

  override def reportFailure(cause: Throwable): Unit = ec.reportFailure(cause)
}

/** Closes database connections safely.  Important on dev restart. */
class PetDAOCloseHook @Inject()(dao: PetDAO, lifecycle: ApplicationLifecycle) {
  private val logger = org.slf4j.LoggerFactory.getLogger("application")

  lifecycle.addStopHook { () =>
    Future.successful {
      logger.info("Now closing database connections!")
      dao.close()
    }
  }
}
