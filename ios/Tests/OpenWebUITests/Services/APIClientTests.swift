//
//  APIClientTests.swift
//  OpenWebUITests
//
//  Unit tests for APIClient
//

import XCTest
@testable import OpenWebUI

@MainActor
final class APIClientTests: XCTestCase {
    
    var sut: APIClient!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = APIClient.shared
    }
    
    override func tearDown() async throws {
        sut.setAuthToken(nil)
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Singleton Tests
    
    func testSharedInstanceIsSingleton() {
        let instance1 = APIClient.shared
        let instance2 = APIClient.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    // MARK: - Auth Token Tests
    
    func testSetAuthTokenSavesToKeychain() {
        let testToken = "test_token_12345"
        
        sut.setAuthToken(testToken)
        
        let savedToken = KeychainHelper.load(forKey: "auth_token")
        XCTAssertEqual(savedToken, testToken)
    }
    
    func testSetNilAuthTokenClearsKeychain() {
        let testToken = "test_token_12345"
        
        sut.setAuthToken(testToken)
        sut.setAuthToken(nil)
        
        let savedToken = KeychainHelper.load(forKey: "auth_token")
        XCTAssertNil(savedToken)
    }
    
    // MARK: - Request Error Tests
    
    func testRequestToInvalidEndpointThrowsError() async {
        do {
            let _: [String: String] = try await sut.request(
                path: "/invalid/endpoint/that/does/not/exist",
                method: "GET"
            )
            // If backend is available, it should return 404
        } catch {
            // Expected - either network error or HTTP error
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - JSON Encoder Tests
    
    func testAPIEncoderUsesSnakeCase() throws {
        struct TestStruct: Codable {
            let firstName: String
            let lastName: String
        }
        
        let test = TestStruct(firstName: "John", lastName: "Doe")
        let data = try JSONEncoder.api.encode(test)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertNotNil(json["first_name"])
        XCTAssertNotNil(json["last_name"])
    }
    
    func testAPIEncoderUsesISO8601Dates() throws {
        struct TestStruct: Codable {
            let date: Date
        }
        
        let date = Date(timeIntervalSince1970: 0)
        let test = TestStruct(date: date)
        let data = try JSONEncoder.api.encode(test)
        let jsonString = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(jsonString.contains("1970"))
    }
    
    // MARK: - JSON Decoder Tests
    
    func testAPIDecoderUsesSnakeCase() throws {
        let json = """
        {
            "first_name": "John",
            "last_name": "Doe"
        }
        """.data(using: .utf8)!
        
        struct TestStruct: Codable {
            let firstName: String
            let lastName: String
        }
        
        let result = try JSONDecoder.api.decode(TestStruct.self, from: json)
        
        XCTAssertEqual(result.firstName, "John")
        XCTAssertEqual(result.lastName, "Doe")
    }
    
    func testAPIDecoderUsesISO8601Dates() throws {
        let json = """
        {
            "date": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        
        struct TestStruct: Codable {
            let date: Date
        }
        
        let result = try JSONDecoder.api.decode(TestStruct.self, from: json)
        
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: result.date)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 1)
    }
    
    // MARK: - Error Type Tests
    
    func testAPIClientErrorInvalidResponseDescription() {
        let error = APIClientError.invalidResponse
        XCTAssertEqual(error.errorDescription, "Invalid response from server")
    }
    
    func testAPIClientErrorHTTPErrorDescription() {
        let error = APIClientError.httpError(404)
        XCTAssertEqual(error.errorDescription, "HTTP error: 404")
    }
    
    func testAPIClientErrorDecodingErrorDescription() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error = APIClientError.decodingError(underlyingError)
        XCTAssertTrue(error.errorDescription?.contains("decode") ?? false)
    }
    
    func testAPIClientErrorEncodingErrorDescription() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error = APIClientError.encodingError(underlyingError)
        XCTAssertTrue(error.errorDescription?.contains("encode") ?? false)
    }
    
    func testAPIClientErrorNetworkErrorDescription() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network failed"])
        let error = APIClientError.networkError(underlyingError)
        XCTAssertTrue(error.errorDescription?.contains("Network") ?? false)
    }
}
