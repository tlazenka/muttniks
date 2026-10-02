package muttniks.controllers

class EthereumSyncSuite extends munit.FunSuite:
  test("finalize") {
    assertEquals(EthereumSync.finalizedHead(100, 12), 88L)
    assertEquals(EthereumSync.finalizedHead(5, 12), 0L)
  }

  test("common ancestor") {
    val stored = Map(97L -> "a", 98L -> "b", 99L -> "old-c", 100L -> "old-d")
    val canonical = Map(97L -> "a", 98L -> "b", 99L -> "new-c", 100L -> "new-d")
    assertEquals(EthereumSync.findCommonAncestor(100, stored.get, canonical.get), 98L)
  }

  test("quantities round trip") {
    assertEquals(EthereumSync.quantity(0), "0x0")
    assertEquals(EthereumSync.quantity(30), "0x1e")
    assertEquals(EthereumSync.parseQuantity("0x6eda"), 28378L)
  }
