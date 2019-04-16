package mpp

import io.ktor.client.HttpClient
import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.response.HttpResponse
import io.ktor.client.response.readText
import io.ktor.http.isSuccess
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.list

@Serializable
data class Pet(val externalId: Int?, val title: String?)

@Serializable
data class AdoptersLastUpdated(val adoptersLastUpdated: Long?)

@Serializable
data class PetName(val name: String?, val lastUpdateTime: Long?)

suspend fun getPets(client: HttpClient, baseUrl: String, adopter: String): List<Pet>? {
    val response = client.get<HttpResponse>("${baseUrl}api/petsByAdopter") {
        url {
            parameters.append(name = "adopter", value = adopter)
        }
    }
    if (!(response.status.isSuccess())) {
        return null
    }
    val responseText = response.readText()
    return Json.nonstrict.parse(deserializer = Pet.serializer().list, string = responseText)
}

suspend fun adoptPet(client: HttpClient, baseUrl: String, privateKey: String, petId: Int): Boolean {
    val response = client.post<HttpResponse>("${baseUrl}api/adopt") {
        url {
            parameters.append(name = "privateKey", value = privateKey)
            parameters.append(name = "petId", value = petId.toString())
        }
    }
    return response.status.isSuccess()
}

suspend fun assignNameToPet(client: HttpClient, baseUrl: String, privateKey: String, petId: Int, name: String): Boolean {
    val response = client.post<HttpResponse>("${baseUrl}api/assignName") {
        url {
            parameters.append(name = "privateKey", value = privateKey)
            parameters.append(name = "petId", value = petId.toString())
            parameters.append(name = "name", value = name)
        }
    }
    return response.status.isSuccess()
}

suspend fun getLastKnownAdoptersUpdate(client: HttpClient, baseUrl: String): AdoptersLastUpdated? {
    val response = client.get<HttpResponse>("${baseUrl}api/lastKnownAdoptersUpdate")
    if (!(response.status.isSuccess())) {
        return null
    }
    val responseText = response.readText()
    return Json.nonstrict.parse(deserializer = AdoptersLastUpdated.serializer(), string = responseText)
}

suspend fun getPetName(client: HttpClient, baseUrl: String, petId: Int): PetName? {
    val response = client.get<HttpResponse>("${baseUrl}petName/${petId}")
    if (!(response.status.isSuccess())) {
        return null
    }
    val responseText = response.readText()
    return Json.nonstrict.parse(deserializer = PetName.serializer(), string = responseText)
}