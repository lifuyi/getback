import XCTest
@testable import TrojanVPNModels
@testable import TrojanVPNCore

final class TrojanVPNTests: XCTestCase {
    
    func testServerProfileCreation() throws {
        let profile = ServerProfile(
            name: "Test Server",
            serverAddress: "test.example.com",
            port: 443,
            password: "testpassword"
        )
        
        XCTAssertEqual(profile.name, "Test Server")
        XCTAssertEqual(profile.serverAddress, "test.example.com")
        XCTAssertEqual(profile.port, 443)
        XCTAssertEqual(profile.password, "testpassword")
        XCTAssertFalse(profile.isDefault)
        XCTAssertFalse(profile.isFavorite)
    }
    
    func testServerProfileWithUpdatedConnection() throws {
        let profile = ServerProfile(
            name: "Test Server",
            serverAddress: "test.example.com",
            port: 443,
            password: "testpassword"
        )
        
        let updatedProfile = profile.withUpdatedConnection()
        
        XCTAssertNotNil(updatedProfile.lastConnected)
        XCTAssertNil(profile.lastConnected) // Original should be unchanged
    }
    
    func testServerProfileToggleFavorite() throws {
        let profile = ServerProfile(
            name: "Test Server",
            serverAddress: "test.example.com",
            port: 443,
            password: "testpassword"
        )
        
        let favoriteProfile = profile.withToggledFavorite()
        
        XCTAssertTrue(favoriteProfile.isFavorite)
        XCTAssertFalse(profile.isFavorite) // Original should be unchanged
    }
    
    func testServerProfileForExport() throws {
        let profile = ServerProfile(
            name: "Test Server",
            serverAddress: "test.example.com",
            port: 443,
            password: "secretpassword"
        )
        
        let exportProfile = profile.forExport()
        
        XCTAssertEqual(exportProfile.name, "Test Server")
        XCTAssertEqual(exportProfile.serverAddress, "test.example.com")
        XCTAssertEqual(exportProfile.port, 443)
        XCTAssertEqual(exportProfile.password, "") // Password should be empty for export
    }
}