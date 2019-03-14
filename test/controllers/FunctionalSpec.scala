package controllers

import org.scalatestplus.play.{BaseOneAppPerSuite, PlaySpec}
import play.api.test.FakeRequest
import play.api.test.Helpers._
import com.muttniks.pet._

import scala.concurrent.{Await, Future}
import scala.concurrent.duration.Duration
import scala.concurrent.ExecutionContext.Implicits.global
import org.slf4j.Logger
import org.scalatest._
import Matchers._
import play.api.libs.json.JodaWrites._
import play.api.libs.json.JodaReads._
import play.api.libs.json.{JsObject, Json, OFormat}

class FunctionalSpec extends PlaySpec with BaseOneAppPerSuite with MyApplicationFactory {

  private val logger: Logger = org.slf4j.LoggerFactory.getLogger(this.getClass)

  implicit val petFormat: OFormat[Pet] = Json.format[Pet]

  "HomeController" should {

    "get pets" in {
      val future = route(app, FakeRequest(GET, "/api/allPets")).get
      val s = contentAsString(future)
      val parsed = Json.parse(s).as[JsObject]
      val pets = parsed.value("pets")
      val petList = pets.as[List[Pet]]
      petList.count(p => p.title.contains("Strelka")) shouldBe 1

      // default page size for GET is 5
      val ids = Set(petList.map(_.externalId): _*)
      ids.size shouldBe 5
    }
  }

  private val petDao = app.injector.instanceOf[PetDAO]

  "Pets" should {
    "be created" in {
      val pets = Await.result(petDao.allPets(), Duration.Inf)
      pets.length shouldBe 6
    }
    "be adopted" in {
      val pets = Await.result(petDao.allPets(), Duration.Inf)

      val r = scala.util.Random
      val adopter1 = s"adopter${r.nextInt()}"
      val adopter2 = s"adopter${r.nextInt()}"

      petDao.upsertPetAdopter(pets(0).externalId, Some(adopter1))
      petDao.upsertPetAdopter(pets(1).externalId, Some(adopter1))
      petDao.upsertPetAdopter(pets(2).externalId, Some(adopter2))

      var adopted1 = Await.result(petDao.petsByAdopter(0, pets.size, adopter1), Duration.Inf).items
      var adopted2 = Await.result(petDao.petsByAdopter(0, pets.size, adopter2), Duration.Inf).items

      logger.warn(adopted1.toString())

      adopted1.length shouldBe 2
      adopted2.length shouldBe 1

      adopted1.count(_.externalId == 1) shouldBe 1
      adopted1.count(_.externalId == 2) shouldBe 1
      adopted2.count(_.externalId == 3) shouldBe 1

      petDao.upsertPetAdopter(pets(0).externalId, Some(adopter2))

      adopted1 = Await.result(petDao.petsByAdopter(0, pets.size, adopter1), Duration.Inf).items
      adopted2 = Await.result(petDao.petsByAdopter(0, pets.size, adopter2), Duration.Inf).items

      adopted1.length shouldBe 1
      adopted2.length shouldBe 2

      adopted1.count(_.externalId == 2) shouldBe 1
      adopted2.count(_.externalId == 1) shouldBe 1
      adopted2.count(_.externalId == 3) shouldBe 1
    }
    "be paged" in {
      val allPets = Await.result(petDao.allPets(), Duration.Inf)
      var pets = Await.result(petDao.getPets(0, allPets.length, Some(Seq(1))), Duration.Inf).items
      pets.length shouldBe 1
      pets(0).externalId shouldBe 1

      pets = Await.result(petDao.getPets(0, allPets.length, Some(Seq(1, 3))), Duration.Inf).items
      pets.length shouldBe 2
      pets.count(_.externalId == 1) shouldBe 1
      pets.count(_.externalId == 3) shouldBe 1

      var pagedIds1 = Await.result(petDao.getPets(0, 2), Duration.Inf).items.map(_.externalId)
      var pagedIds2 = Await.result(petDao.getPets(1, 2), Duration.Inf).items.map(_.externalId)
      var pagedIds3 = Await.result(petDao.getPets(2, 2), Duration.Inf).items.map(_.externalId)

      val pagesSet = Set((pagedIds1 ++ pagedIds2 ++ pagedIds3): _*)
      pagesSet.size shouldBe 6
    }
  }
}
