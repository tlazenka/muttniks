package mpp

import platform.posix.*
import kotlinx.cinterop.*

import io.ktor.client.HttpClient
import kotlinx.coroutines.delay
import kotlin.test.*
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlin.random.Random.Default.nextInt

val apiBaseUrl: String = getenv("API_BASE_URL")!!.toKString()
val cacheBaseUrl: String = getenv("CACHE_BASE_URL")!!.toKString()

val clientTimeoutSeconds: Int = getenv("TEST_CLIENT_TIMEOUT_SECONDS")!!.toKString().toInt()
val cachePollDurationSeconds: Int = getenv("TEST_CACHE_POLL_DURATION_SECONDS")!!.toKString().toInt()

val account = getenv("TEST_ACCOUNT")!!.toKString()
val privateKey = getenv("TEST_PRIVATE_KEY")!!.toKString()

val petId: Int = getenv("TEST_PET_ID")!!.toKString().toInt()

val allowAdoptionErrors: Int = getenv("TEST_ALLOW_ADOPTION_ERRORS")?.toKString()?.toIntOrNull() ?: 0

fun randomAlphanumericString(length: Int): String {
    val characters: List<Char> by lazy { ('a'..'z') + ('A'..'Z') + ('0'..'9') }
    return (0 until length)
        .map { _ -> characters[nextInt(0, characters.size)] }
        .joinToString("")
}

suspend fun<T> withClientTimeout(block: suspend () -> T): T =
    withTimeout(timeMillis = clientTimeoutSeconds.toLong() * 1000) {
        block()
    }

class IntegrationTest {
    @Test
    fun testAdoption() = runBlocking {
        val client = HttpClient()

        println("Adopting: ${petId} from private key: ${privateKey} account: ${account}")

        val adoptPetResult = withClientTimeout {
            adoptPet(client = client, baseUrl = apiBaseUrl, privateKey = privateKey, petId = petId)
        }

        if (adoptPetResult) {
            println("adoptPetResult: ${adoptPetResult}")
        }
        else {
            if (allowAdoptionErrors == 0) {
                fail("Error adopting pet id: ${petId}")
            }
            else {
                println("Error adopting pet id: ${petId} but ignoring due to TEST_ALLOW_ADOPTION_ERRORS being set to: ${allowAdoptionErrors}");
            }
        }

        val sleepDuration = (cachePollDurationSeconds * 1000).toLong()

        run {
            var x = 0L

            while (true) {
                val lastKnownAdoptersUpdateResult = withClientTimeout {
                    getLastKnownAdoptersUpdate(client = client, baseUrl = apiBaseUrl)
                }!!

                println("lastKnownAdoptersUpdateResult: ${lastKnownAdoptersUpdateResult}")
                val adoptersLastUpdated = lastKnownAdoptersUpdateResult.adoptersLastUpdated ?: 0
                if ((x != 0L) && (adoptersLastUpdated > x)) {
                    break
                }
                x = adoptersLastUpdated;

                println("Waiting for adopter cache...");

                delay(timeMillis = sleepDuration)
            }

            val getPetsByAdopterResult = getPets(client = client, baseUrl = apiBaseUrl, adopter = account)!!
            println("getPetsByAdopterResult: ${getPetsByAdopterResult}")

            val pets = getPetsByAdopterResult.filter { it.externalId == petId }
            assert(pets.count() == 1)
        }

        run {
            val randomString = randomAlphanumericString(length = 16)

            println("Assigning name: ${randomString} to: ${petId}")

            val assignNameToPetResult = assignNameToPet(client = client, baseUrl = apiBaseUrl, privateKey = privateKey, petId = petId, name = randomString)

            println("assignNameToPetResult: ${assignNameToPetResult}")

            var x = 0L

            while (true) {
                val petNameResult = withClientTimeout {
                    getPetName(client = client, baseUrl = cacheBaseUrl, petId = petId)
                }!!

                println("petNameResult: ${petNameResult}")
                val petNameUpdated = petNameResult.lastUpdateTime ?: 0
                if ((x != 0L) && (petNameUpdated > x)) {
                    assertEquals(petNameResult.name, randomString)
                    break
                }
                x = petNameUpdated;

                println("Waiting for name cache...");

                delay(timeMillis = sleepDuration)
            }

        }

        client.close()
    }
}
