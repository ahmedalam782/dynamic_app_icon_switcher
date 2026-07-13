import Flutter
import UIKit
import XCTest

@testable import dynamic_app_icon_switcher

class RunnerTests: XCTestCase {

  func testSupportsAlternateIcons() {
    let plugin = DynamicAppIconSwitcherPlugin()
    let call = FlutterMethodCall(methodName: "supportsAlternateIcons", arguments: nil)

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertTrue(result is Bool)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

}
