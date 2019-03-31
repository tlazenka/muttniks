import Foundation

public struct Pet: Codable {
	public let externalId: Int
    public let title: String?
}

public struct AdoptersLastUpdated: Codable {
    public let adoptersLastUpdated: Int?
}

public struct PetName: Codable {
    public let name: String?
    public let lastUpdateTime: Int?
}

extension URLSession {
    func synchronousDataTask(with request: URLRequest, errorDomain: String = #function) throws -> (Data, URLResponse?) {
        var result : (Data?, URLResponse?, Error?)
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let dataTask = self.dataTask(with: request) {
            result.0 = $0
            result.1 = $1
            result.2 = $2
            
            semaphore.signal()
        }
        dataTask.resume()
        
        semaphore.wait()
        
        guard let data = result.0 else {
            throw result.2 ?? NSError(domain: errorDomain, code:result.1.httpStatusCodeOrUnknown)
        }
        if let error = result.2 {
            throw error
        }
        
        return (data, result.1)
    }
}

extension Optional where Wrapped == URLResponse {
    var httpStatusCodeOrUnknown: Int {
        guard let httpUrlResponse = self as? HTTPURLResponse else {
            return -1
        }
        return httpUrlResponse.statusCode
    }
}

extension HTTPURLResponse {
    var isSuccess: Bool {
        return 200...299 ~= statusCode
    }
}

let decoder = JSONDecoder()

public func getPets(urlSession: URLSession, baseUrl: URL, adopter: String) throws -> [Pet] {
    var urlComponents = URLComponents(url: baseUrl, resolvingAgainstBaseURL: true)!
    urlComponents.path = "/api/petsByAdopter"
    urlComponents.queryItems = [URLQueryItem(name:"adopter", value:adopter)]
    let url = urlComponents.url!
    var request = URLRequest(url:url)
    request.httpMethod = "GET"
    
    let result = try urlSession.synchronousDataTask(with: request)
    guard let response = result.1 as? HTTPURLResponse, response.isSuccess else {
        throw NSError(domain: #function, code: result.1.httpStatusCodeOrUnknown)
    }
    return try decoder.decode([Pet].self, from: result.0)
}

public func adoptPet(urlSession: URLSession, baseUrl: URL, privateKey: String, petId: Int) throws -> Bool {
    var urlComponents = URLComponents(url: baseUrl, resolvingAgainstBaseURL: true)!
    urlComponents.path = "/api/adopt"
    urlComponents.queryItems = [
        URLQueryItem(name:"privateKey", value:privateKey),
        URLQueryItem(name:"petId", value:String(petId))]
    let url = urlComponents.url!
    var request = URLRequest(url:url)
    request.httpMethod = "POST"
    
    let result = try urlSession.synchronousDataTask(with: request)
    guard let response = result.1 as? HTTPURLResponse, response.isSuccess else {
        throw NSError(domain: #function, code: result.1.httpStatusCodeOrUnknown)
    }
    return true
}

public func assignNameToPet(urlSession: URLSession, baseUrl: URL, privateKey: String, petId: Int, name: String) throws -> Bool {
    var urlComponents = URLComponents(url: baseUrl, resolvingAgainstBaseURL: true)!
    urlComponents.path = "/api/assignName"
    urlComponents.queryItems = [
        URLQueryItem(name:"privateKey", value:privateKey),
        URLQueryItem(name:"petId", value:String(petId)),
        URLQueryItem(name:"name", value:name),
    ]
    let url = urlComponents.url!
    var request = URLRequest(url:url)
    request.httpMethod = "POST"
    
    let result = try urlSession.synchronousDataTask(with: request)
    guard let response = result.1 as? HTTPURLResponse, response.isSuccess else {
        throw NSError(domain: #function, code: result.1.httpStatusCodeOrUnknown)
    }
    return true
}


public func getLastKnownAdoptersUpdate(urlSession: URLSession, baseUrl: URL) throws -> AdoptersLastUpdated {
    var urlComponents = URLComponents(url: baseUrl, resolvingAgainstBaseURL: true)!
    urlComponents.path = "/api/lastKnownAdoptersUpdate"
    let url = urlComponents.url!
    var request = URLRequest(url:url)
    request.httpMethod = "GET"
    
    let result = try urlSession.synchronousDataTask(with: request)
    guard let response = result.1 as? HTTPURLResponse, response.isSuccess else {
        throw NSError(domain: #function, code: result.1.httpStatusCodeOrUnknown)
    }
    return try decoder.decode(AdoptersLastUpdated.self, from: result.0)
}

public func getPetName(urlSession: URLSession, baseUrl: URL, petId: Int) throws -> PetName {
    var urlComponents = URLComponents(url: baseUrl, resolvingAgainstBaseURL: true)!
    urlComponents.path = "/petName/\(String(petId))"
    let url = urlComponents.url!
    var request = URLRequest(url:url)
    request.httpMethod = "GET"
    
    let result = try urlSession.synchronousDataTask(with: request)
    guard let response = result.1 as? HTTPURLResponse, response.isSuccess else {
        throw NSError(domain: #function, code: result.1.httpStatusCodeOrUnknown)
    }
    return try decoder.decode(PetName.self, from: result.0)
}

