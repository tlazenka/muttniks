resolvers += "Maven Central Server" at "https://repo1.maven.org/maven2"

resolvers += "Typesafe Server" at "https://repo.typesafe.com/typesafe/releases"

resolvers += "Sonatype OSS Snapshots" at "https://oss.sonatype.org/content/repositories/snapshots"

resolvers += "Flyway" at "https://flywaydb.org/repo"

// Database migration
addSbtPlugin("io.github.davidmweber" % "flyway-sbt" % "5.0.0")

// Slick code generation
// https://github.com/tototoshi/sbt-slick-codegen
addSbtPlugin("com.github.tototoshi" % "sbt-slick-codegen" % "1.3.0")

libraryDependencies += "org.postgresql" % "postgresql" % "42.2.14"

// The Play plugin
addSbtPlugin("com.typesafe.play" % "sbt-plugin" % "2.7.7")
