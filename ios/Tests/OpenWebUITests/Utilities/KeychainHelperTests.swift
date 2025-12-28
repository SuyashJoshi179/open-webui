//
//  KeychainHelperTests.swift
//  OpenWebUITests
//
//  Unit tests for KeychainHelper
//

import XCTest
@testable import OpenWebUI

final class KeychainHelperTests: XCTestCase {
    
    let testKey = "test_keychain_key"
    let testValue = "test_keychain_value"
    
    override func setUp() {
        super.setUp()
        // Clean up before each test
        KeychainHelper.delete(forKey: testKey)
    }
    
    override func tearDown() {
        // Clean up after each test
        KeychainHelper.delete(forKey: testKey)
        super.tearDown()
    }
    
    // MARK: - Save Tests
    
    func testSaveValueSuccessfully() {
        let result = KeychainHelper.save(testValue, forKey: testKey)
        XCTAssertTrue(result)
    }
    
    func testSaveEmptyString() {
        let result = KeychainHelper.save("", forKey: testKey)
        XCTAssertTrue(result)
    }
    
    func testSaveLongValue() {
        let longValue = String(repeating: "a", count: 10000)
        let result = KeychainHelper.save(longValue, forKey: testKey)
        XCTAssertTrue(result)
    }
    
    func testSaveSpecialCharacters() {
        let specialValue = "!@#$%^&*()_+-=[]{}|;':\",./<>?`~"
        let result = KeychainHelper.save(specialValue, forKey: testKey)
        XCTAssertTrue(result)
        
        let loadedValue = KeychainHelper.load(forKey: testKey)
        XCTAssertEqual(loadedValue, specialValue)
    }
    
    func testSaveUnicodeCharacters() {
        let unicodeValue = "Hello 🌍 世界 مرحبا العالم"
        let result = KeychainHelper.save(unicodeValue, forKey: testKey)
        XCTAssertTrue(result)
        
        let loadedValue = KeychainHelper.load(forKey: testKey)
        XCTAssertEqual(loadedValue, unicodeValue)
    }
    
    // MARK: - Load Tests
    
    func testLoadExistingValue() {
        KeychainHelper.save(testValue, forKey: testKey)
        
        let loadedValue = KeychainHelper.load(forKey: testKey)
        XCTAssertEqual(loadedValue, testValue)
    }
    
    func testLoadNonExistentKey() {
        let loadedValue = KeychainHelper.load(forKey: "non_existent_key")
        XCTAssertNil(loadedValue)
    }
    
    func testLoadAfterOverwrite() {
        let originalValue = "original"
        let newValue = "new_value"
        
        KeychainHelper.save(originalValue, forKey: testKey)
        KeychainHelper.save(newValue, forKey: testKey)
        
        let loadedValue = KeychainHelper.load(forKey: testKey)
        XCTAssertEqual(loadedValue, newValue)
    }
    
    // MARK: - Delete Tests
    
    func testDeleteExistingKey() {
        KeychainHelper.save(testValue, forKey: testKey)
        
        let deleteResult = KeychainHelper.delete(forKey: testKey)
        XCTAssertTrue(deleteResult)
        
        let loadedValue = KeychainHelper.load(forKey: testKey)
        XCTAssertNil(loadedValue)
    }
    
    func testDeleteNonExistentKey() {
        let deleteResult = KeychainHelper.delete(forKey: "non_existent_key")
        XCTAssertTrue(deleteResult) // Should return true for non-existent keys
    }
    
    // MARK: - Clear All Tests
    
    func testClearAll() {
        let key1 = "test_key_1"
        let key2 = "test_key_2"
        
        KeychainHelper.save("value1", forKey: key1)
        KeychainHelper.save("value2", forKey: key2)
        
        let clearResult = KeychainHelper.clearAll()
        XCTAssertTrue(clearResult)
        
        // Clean up test keys
        KeychainHelper.delete(forKey: key1)
        KeychainHelper.delete(forKey: key2)
    }
    
    // MARK: - Integration Tests
    
    func testSaveLoadDeleteCycle() {
        // Save
        let saveResult = KeychainHelper.save(testValue, forKey: testKey)
        XCTAssertTrue(saveResult)
        
        // Load
        var loadedValue = KeychainHelper.load(forKey: testKey)
        XCTAssertEqual(loadedValue, testValue)
        
        // Delete
        let deleteResult = KeychainHelper.delete(forKey: testKey)
        XCTAssertTrue(deleteResult)
        
        // Verify deleted
        loadedValue = KeychainHelper.load(forKey: testKey)
        XCTAssertNil(loadedValue)
    }
    
    func testMultipleKeysSamePrefix() {
        let key1 = "auth_token"
        let key2 = "auth_refresh_token"
        let value1 = "access_token_123"
        let value2 = "refresh_token_456"
        
        KeychainHelper.save(value1, forKey: key1)
        KeychainHelper.save(value2, forKey: key2)
        
        XCTAssertEqual(KeychainHelper.load(forKey: key1), value1)
        XCTAssertEqual(KeychainHelper.load(forKey: key2), value2)
        
        // Clean up
        KeychainHelper.delete(forKey: key1)
        KeychainHelper.delete(forKey: key2)
    }
    
    func testAuthTokenStorage() {
        // Simulate real auth token storage
        let authToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ"
        let authKey = "auth_token_test"
        
        // Save token
        XCTAssertTrue(KeychainHelper.save(authToken, forKey: authKey))
        
        // Load token
        XCTAssertEqual(KeychainHelper.load(forKey: authKey), authToken)
        
        // Clean up
        KeychainHelper.delete(forKey: authKey)
    }
}
