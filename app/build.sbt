import java.nio.file.Paths

name := "muttniks-app"

ThisBuild / scalaVersion := "3.3.6"
ThisBuild / organization := "com.muttniks"
ThisBuild / version := "0.2.0-SNAPSHOT"

// We use publisTohMavenLocal on local machines
ThisBuild / resolvers += sys.env
  .get("MUTTNIKS_MAVEN_REPO")
  .map(path => "embedded-likes" at Paths.get(path).toUri.toString)
  .getOrElse(Resolver.mavenLocal)

val catsEffectVersion = "3.6.3"
val munitVersion = "1.1.1"
val skunkVersion = "0.6.5"

lazy val muttniksDomain = project
  .in(file("domain"))
  .settings(
    name := "muttniks-domain",
    libraryDependencies += "org.scalameta" %% "munit" % munitVersion % Test
  )

lazy val muttniksPersistence = project
  .in(file("persistence"))
  .dependsOn(muttniksDomain)
  .settings(
    name := "muttniks-persistence",
    libraryDependencies ++= Seq(
      "org.typelevel" %% "cats-effect" % catsEffectVersion,
      "org.tpolecat" %% "skunk-core" % skunkVersion,
      "org.scalameta" %% "munit" % munitVersion % Test
    )
  )

lazy val muttniksPlay = project
  .in(file("play"))
  .enablePlugins(PlayScala)
  .dependsOn(muttniksDomain, muttniksPersistence)
  .settings(
    name := "muttniks-play",
    Test / parallelExecution := false,
    libraryDependencies ++= Seq(
      jdbc,
      evolutions,
      "org.postgresql" % "postgresql" % "42.7.8",
      "org.bouncycastle" % "bcprov-jdk18on" % "1.82",
      "com.muttniks" % "like-rules" % "0.1.0-SNAPSHOT",
      "org.scalameta" %% "munit" % munitVersion % Test
    )
  )

addCommandAlias("testPersistence", ";muttniksPlay/testOnly muttniks.persistence.SkunkRepositorySuite")
addCommandAlias("testEvolutions", ";muttniksPlay/test")

lazy val root = project
  .in(file("."))
  .aggregate(muttniksDomain, muttniksPersistence, muttniksPlay)
  .settings(publish / skip := true)
