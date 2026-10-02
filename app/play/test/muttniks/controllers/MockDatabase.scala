package muttniks.controllers

import play.api.db.{Database, Databases}
import play.api.db.evolutions.Evolutions

object MockDatabase:
  private val url = sys.env.getOrElse(
    "MUTTNIKS_JDBC_URL",
    "jdbc:postgresql://localhost:5432/muttniks"
  )
  private val user = sys.env.getOrElse("MUTTNIKS_DB_USER", "muttniks")
  private val password = sys.env.getOrElse("MUTTNIKS_DB_PASSWORD", "muttniks")

  def withDatabase[A](f: Database => A): A =
    Databases.withDatabase(
      driver = "org.postgresql.Driver",
      url = url,
      config = Map("username" -> user, "password" -> password)
    )(f)

  def resetAndEvolve(): Unit =
    withDatabase { database =>
      val connection = database.getConnection()
      try
        val statement = connection.createStatement()
        try
          statement.execute("DROP SCHEMA public CASCADE")
          statement.execute("CREATE SCHEMA public")
        finally statement.close()
      finally connection.close()

      Evolutions.applyEvolutions(database)
    }
