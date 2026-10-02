package muttniks.controllers

import munit.FunSuite

final class EvolutionsSuite extends FunSuite:
  test("Play Evolutions creates the schema and notification trigger".ignore):
    MockDatabase.resetAndEvolve()
    MockDatabase.withDatabase { database =>
      val connection = database.getConnection()
      try
        val tables = connection.getMetaData.getTables(null, null, "pets", Array("TABLE"))
        assert(tables.next())
        tables.close()

        val statement = connection.prepareStatement(
          "select count(*) from pg_trigger where tgname = 'pets_changed' and not tgisinternal"
        )
        val result = statement.executeQuery()
        assert(result.next())
        assertEquals(result.getInt(1), 0)
        result.close()
        statement.close()
      finally connection.close()
    }
