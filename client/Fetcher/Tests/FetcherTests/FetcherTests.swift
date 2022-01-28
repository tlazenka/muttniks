import XCTest
import class Foundation.Bundle
import Shared

let apiBaseUrl = URL(string: ProcessInfo.processInfo.environment["API_BASE_URL"]!)!
let cacheBaseUrl = URL(string: ProcessInfo.processInfo.environment["CACHE_BASE_URL"]!)!

let clientRequestTimeoutSeconds = Double(ProcessInfo.processInfo.environment["TEST_CLIENT_REQUEST_TIMEOUT_SECONDS"]!)!
let clientResourceTimeoutSeconds = Double(ProcessInfo.processInfo.environment["TEST_CLIENT_RESOURCE_TIMEOUT_SECONDS"]!)!
let cachePollDurationSeconds = Double(ProcessInfo.processInfo.environment["TEST_CACHE_POLL_DURATION_SECONDS"]!)!

let account = ProcessInfo.processInfo.environment["TEST_ACCOUNT"]!
let privateKey = ProcessInfo.processInfo.environment["TEST_PRIVATE_KEY"]!

let petId = Int(ProcessInfo.processInfo.environment["TEST_PET_ID"]!)!

let allowAdoptionErrors = Int(ProcessInfo.processInfo.environment["TEST_ALLOW_ADOPTION_ERRORS"] ?? String(0))!

func randomAlphanumericString(length: Int) -> String  {
    enum Statics {
        static let scalars = [UnicodeScalar("a").value...UnicodeScalar("z").value, UnicodeScalar("A").value...UnicodeScalar("Z").value, UnicodeScalar("0").value...UnicodeScalar("9").value].joined()

        static let characters = scalars.map { Character(UnicodeScalar($0)!) }
    }
    
    let result = (0..<length).map { _ in Statics.characters.randomElement()! }
    return String(result)
}

final class FetcherTests: XCTestCase {
    var urlSession: URLSession!
    
    override func setUp() {
        super.setUp()
        
        urlSession = {
            let sessionConfiguration = URLSessionConfiguration.default
            sessionConfiguration.timeoutIntervalForRequest = clientRequestTimeoutSeconds
            sessionConfiguration.timeoutIntervalForResource = clientResourceTimeoutSeconds
            return URLSession(configuration: sessionConfiguration)
        }()
    }
    
    func testAdoption() throws {
        print("Adopting: \(petId) from private key: \(privateKey) account: \(account)")
        
        do {
            let adoptPetResult = try adoptPet(urlSession: urlSession, baseUrl: apiBaseUrl, privateKey: privateKey, petId: petId)
            print("adoptPetResult: \(adoptPetResult)")
        }
        catch {
            if allowAdoptionErrors == 0 {
                print("Error adopting pet id: \(petId) message: \(error.localizedDescription)");
                throw error
            }
            else {
                print("Error adopting pet id: \(petId) but ignoring due to TEST_ALLOW_ADOPTION_ERRORS being set to: \(allowAdoptionErrors)");
            }
        }
        
        let sleepDuration: TimeInterval = cachePollDurationSeconds

        do {
            var x = 0
            
            while true {
                let lastKnownAdoptersUpdateResult = try getLastKnownAdoptersUpdate(urlSession: urlSession, baseUrl: apiBaseUrl)
                
                print("lastKnownAdoptersUpdateResult: \(lastKnownAdoptersUpdateResult)");
                let adoptersLastUpdated = lastKnownAdoptersUpdateResult.adoptersLastUpdated ?? 0;
                if (x != 0) && (adoptersLastUpdated > x) {
                    break;
                }
                x = adoptersLastUpdated;
                
                print("Waiting for adopter cache...");

                Thread.sleep(forTimeInterval: sleepDuration)
            }
            
            let getPetsByAdopterResult = try getPets(urlSession: urlSession, baseUrl: apiBaseUrl, adopter: account)
            print("getPetsByAdopterResult: \(getPetsByAdopterResult)");
            
            let pets = getPetsByAdopterResult.filter { $0.externalId == petId }
            XCTAssert(pets.count == 1)
        }
        
        do {
            let randomString = randomAlphanumericString(length: 16)
            
            print("Assigning name: \(randomString) to: \(petId)")
            
            let assignNameToPetResult = try assignNameToPet(urlSession: urlSession, baseUrl: apiBaseUrl, privateKey: privateKey, petId: petId, name: randomString)
            
            print("assignNameToPetResult: \(assignNameToPetResult)")
            
            var x = 0
            
            while true {
                let petNameResult = try getPetName(urlSession: urlSession, baseUrl: cacheBaseUrl, petId: petId)
                
                print("petNameResult: \(petNameResult)");
                let petNameUpdated = petNameResult.lastUpdateTime ?? 0;
                if (x != 0) && (petNameUpdated > x) {
                    XCTAssert(petNameResult.name == randomString)
                    break;
                }
                x = petNameUpdated;
                
                print("Waiting for name cache...");
                
                Thread.sleep(forTimeInterval: sleepDuration)
            }
        }
    }

    static var allTests = [
        ("testAdoption", testAdoption),
    ]
}
