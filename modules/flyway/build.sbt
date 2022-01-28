

// Database Migrations:
// run with "sbt flywayMigrate"
// http://flywaydb.org/getstarted/firststeps/sbt.html

//$ export DB_DEFAULT_URL="jdbc:h2:/tmp/example.db"
//$ export DB_DEFAULT_USER="sa"
//$ export DB_DEFAULT_PASSWORD=""

libraryDependencies += "org.flywaydb" % "flyway-core" % "5.0.0"

lazy val databaseUrl = sys.env.getOrElse("JDBC_URL", "jdbc:postgresql:muttniks")
lazy val databaseUser = sys.env.getOrElse("JDBC_USER", "muttniks")
lazy val databasePassword = sys.env.getOrElse("JDBC_PASS", "")

flywayLocations := Seq("classpath:db/migration")

flywayUrl := databaseUrl
flywayUser := databaseUser
flywayPassword := databasePassword
