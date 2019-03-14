package helpers

import org.scalatest._
import org.slf4j.Logger

class UnitSpec extends FlatSpec with Matchers {

  private val logger: Logger = org.slf4j.LoggerFactory.getLogger(this.getClass)

  "Helpers" should "run" in {
    Helpers.isAscii('a') shouldEqual true
    Helpers.isAscii('z') shouldEqual true
    Helpers.isAscii('ü') shouldEqual false
    Helpers.isAscii(' ') shouldEqual true
    Helpers.isAscii("Strelka") shouldEqual true
    Helpers.isAscii("Die Bären") shouldEqual false
  }
}
