package muttniks.domain

final case class PetListing(id: Long, name: Option[String], adopter: Option[String], imageUrl: Option[String])
