package helpers

import javax.inject.{Inject, Singleton}

import scala.concurrent.duration._
import akka.actor.ActorSystem
import akka.dispatch.MessageDispatcher
import com.muttniks.pet.PetDAO
import controllers.HomeController
import org.slf4j.Logger
import play.Environment

import scala.concurrent.ExecutionContext

class CacheTask @Inject() (actorSystem: ActorSystem,
                           homeController: HomeController,
                           environment: Environment,
                           petDAO: PetDAO,
                           cacheExecutionContext: CacheExecutionContext) {

  private val logger: Logger = org.slf4j.LoggerFactory.getLogger(this.getClass)

  implicit val ec: ExecutionContext = cacheExecutionContext.ec

  private val initialDelay =  sys.env("CACHE_TASK_INITIAL_DELAY_SECONDS").toInt.seconds
  private val interval = sys.env("CACHE_TASK_INTERVAL_MINUTES").toInt.minutes
  private val waitTime = interval - initialDelay

  logger.warn(s"Scheduled cache update with initial delay: ${initialDelay} interval: ${interval} wait time: ${waitTime}")

  actorSystem.scheduler.schedule(initialDelay = initialDelay, interval = interval) {
    val p = homeController.updatePetAdopters()
    p.map(i => logger.warn(s"Cache task result: ${i.toString}"))
  }
}

@Singleton
class CacheExecutionContext @Inject() (actorSystem: ActorSystem) {
  val ec: MessageDispatcher = actorSystem.dispatchers.lookup("cache-context")
}

