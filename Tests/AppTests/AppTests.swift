import Hummingbird
import HummingbirdXCT
import XCTest
@testable import App

final class AppTests: XCTestCase {
    
    func testHelloWorld() throws {
        let app = HBApplication(testing: .live)
        try app.configure()
        
        try app.XCTStart()
        defer { app.XCTStop() }
        
        try app.XCTExecute(uri: "/", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
            
            let expectation = "Hello, world!"
            let res = response.body.map { String(buffer: $0) }
            XCTAssertEqual(res, expectation)
        }
    }
}
