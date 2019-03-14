import com.typesafe.sbt.SbtNativePackager.Universal
import com.typesafe.sbt.packager.MappingsHelper._

name := """muttniks"""

version := "1.1-SNAPSHOT"

scalaVersion in ThisBuild := "2.11.8"

initialize := {
  val _ = initialize.value
  if (sys.props("java.specification.version") != "1.8")
    sys.error("Java 8 is required for this project.")
}

lazy val flyway = (project in file("modules/flyway"))
  .enablePlugins(FlywayPlugin)

lazy val api = (project in file("modules/api"))
  .settings(Common.projectSettings)

lazy val slick = (project in file("modules/slick"))
  .settings(Common.projectSettings)
  .aggregate(api)
  .dependsOn(api)

lazy val root = (project in file("."))
  .enablePlugins(PlayScala)
  .settings(
    libraryDependencies += guice,
    libraryDependencies += cache,
    libraryDependencies += ws,
    libraryDependencies += "com.typesafe.play" % "play-json-joda_2.11" % "2.6.0",
    libraryDependencies += "org.web3j" % "core" % "3.3.1",
    libraryDependencies += "org.scalatestplus.play" %% "scalatestplus-play" % "3.1.2" % Test,
    libraryDependencies += "com.h2database" % "h2" % "1.4.196" % Test,
    javaOptions in Test += "-Dconfig.file=conf/application.test.conf",
    unmanagedResourceDirectories in Compile += (baseDirectory.value / "sol" / "build" / "contracts"),
    mappings in Universal ++= directory(baseDirectory.value  / "sol" / "build" / "contracts" / "Adoption.json"),
    // Adding this means no explicit import in *.scala.html files
    TwirlKeys.templateImports += "com.muttniks.pet.Pet"
  ).aggregate(api, slick)
  .dependsOn(api, slick, flyway)

addCommandAlias("testWithMigrate", ";flyway/flywayMigrate;test")
addCommandAlias("runWithMigrate", ";flyway/flywayMigrate;run")