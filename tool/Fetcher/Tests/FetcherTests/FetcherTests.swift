import XCTest
import class Foundation.Bundle
import Shared

let apiBaseUrl = URL(string: ProcessInfo.processInfo.environment["API_BASE_URL"]!)!
let cacheBaseUrl =  URL(string: ProcessInfo.processInfo.environment["CACHE_BASE_URL"]!)!
let petId = Int(ProcessInfo.processInfo.environment["TEST_PET_ID"]!)!
let account = ProcessInfo.processInfo.environment["TEST_ACCOUNT"]!
let privateKey = ProcessInfo.processInfo.environment["TEST_PRIVATE_KEY"]!
let allowAdoptionErrors = Int(ProcessInfo.processInfo.environment["TEST_ALLOW_ADOPTION_ERRORS"] ?? String(0))!;

let urlSession: URLSession = {
    let sessionConfiguration = URLSessionConfiguration.default
    sessionConfiguration.timeoutIntervalForRequest = 30.0
    sessionConfiguration.timeoutIntervalForResource = 30.0
    return URLSession(configuration: sessionConfiguration)
}()

func randomAlphanumericString(length: Int) -> String  {
    let scalars = [UnicodeScalar("a").value...UnicodeScalar("z").value, UnicodeScalar("A").value...UnicodeScalar("Z").value, UnicodeScalar("0").value...UnicodeScalar("9").value].joined()
    let characters = scalars.map { Character(UnicodeScalar($0)!) }
    
    let result = (0..<length).map { _ in characters.randomElement()! }
    return String(result)
}

final class FetcherTests: XCTestCase {
    func testAdoption() throws {
        let sleepDuration: TimeInterval = 60
        
        print("Adopting: \(petId) from private key: \(privateKey) account: \(account)")
        
        do {
            let adoptPetResult = try adoptPet(urlSession: urlSession, baseUrl: apiBaseUrl, privateKey: privateKey, petId: petId)
            print("adoptPetResult: \(adoptPetResult)")
        }
        catch {
            if allowAdoptionErrors == 0 {
                throw error
            }
            else {
                print("Error adopting pet id: \(petId) but ignoring due to TEST_ALLOW_ADOPTION_ERRORS being set to: \(allowAdoptionErrors)");
            }
        }

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
        }
        
        let getPetsByAdopterResult = try getPets(urlSession: urlSession, baseUrl: apiBaseUrl, adopter: account)
        print("getPetsByAdopterResult: \(getPetsByAdopterResult)");
        let pets = getPetsByAdopterResult.filter { $0.externalId == petId }
        XCTAssert(pets.count == 1)
        
        let randomString = randomAlphanumericString(length: 16)
        
        print("Assigning name: \(randomString) to: \(petId)")
        
        let assignNameToPetResult = try assignNameToPet(urlSession: urlSession, baseUrl: apiBaseUrl, privateKey: privateKey, petId: petId, name: randomString)
        
        print("assignNameToPetResult: \(assignNameToPetResult)")

        do {
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
