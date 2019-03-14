package helpers

object Helpers {
  def isAscii(character: Char): Boolean = {
    character <= 127
  }

  def isAscii(string: String): Boolean = string.forall(c => Helpers.isAscii(c))
}
