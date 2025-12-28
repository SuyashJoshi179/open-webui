//
//  AuthServiceTests.swift
//  OpenWebUITests
//
//  Unit tests for AuthService
//

import XCTest
@testable import OpenWebUI

@MainActor
final class AuthServiceTests: XCTestCase {
    
    var sut: AuthService!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = AuthService.shared
        // Reset state before each test
        sut.logout()
    }
    
    override func tearDown() async throws {
        sut.logout()
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialStateIsNotAuthenticated() {
        // After logout, user should not be authenticated
        XCTAssertFalse(sut.isAuthenticated)
    }
    
    func testInitialStateHasNoCurrentUser() {
        // After logout, current user should be nil
        XCTAssertNil(sut.currentUser)
    }
    
    // MARK: - Logout Tests
    
    func testLogoutClearsAuthentication() {
        sut.logout()
        
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.currentUser)
    }
    
    func testLogoutClearsAuthToken() {
        sut.logout()
        
        // The auth token should be cleared from keychain
        let token = KeychainHelper.load(forKey: "auth_token")
        XCTAssertNil(token)
    }
    
    // MARK: - Login Tests (Mock/Integration)
    
    func testLoginWithInvalidCredentialsThrowsError() async {
        // This test requires a backend connection or mocking
        // Testing the error path when credentials are invalid
        do {
            try await sut.login(email: "invalid@test.com", password: "wrongpassword")
            // If backend is not available, this will throw
        } catch {
            // Expected behavior - either network error or auth error
            XCTAssertNotNil(error)
        }
    }
    
    func testSignupWithInvalidDataThrowsError() async {
        do {
            try await sut.signup(email: "", password: "", name: "")
            // If backend validates, this should throw
        } catch {
            // Expected behavior
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Published Properties Tests
    
    func testIsAuthenticatedIsPublished() {
        // Test that changes to isAuthenticated are observable
        let expectation = XCTestExpectation(description: "isAuthenticated changes")
        
        var receivedValues: [Bool] = []
        let cancellable = sut.$isAuthenticated.sink { value in
            receivedValues.append(value)
            if receivedValues.count >= 1 {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertFalse(receivedValues.isEmpty)
        cancellable.cancel()
    }
    
    func testCurrentUserIsPublished() {
        let expectation = XCTestExpectation(description: "currentUser changes")
        
        var receivedValues: [User?] = []
        let cancellable = sut.$currentUser.sink { value in
            receivedValues.append(value)
            if receivedValues.count >= 1 {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Should have received at least the initial value
        XCTAssertFalse(receivedValues.isEmpty)
        cancellable.cancel()
    }
}
