import XCTest
@testable import TapTap

final class WatchReplyViewModelTests: XCTestCase {
    func testGestureAckSingleTapShowsLabelAndClears() {
        let vm = WatchReplyViewModel()
        vm.handleGestureAck("singleTap")
        XCTAssertEqual(vm.gestureLabel, "Tap")
        XCTAssertFalse(vm.showSentConfirmation)
        // color should not be default dark grey
        XCTAssertNotEqual(vm.backgroundColor, Color(white: 0.15))

        // after a little while the label should clear
        let expectation = XCTestExpectation(description: "label cleared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            XCTAssertNil(vm.gestureLabel)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    func testGestureAckDoubleTapShowsLabelAndSendConfirmation() {
        let vm = WatchReplyViewModel()
        vm.handleGestureAck("doubleTap")
        XCTAssertEqual(vm.gestureLabel, "Double Tap")
        XCTAssertTrue(vm.showSentConfirmation)
        XCTAssertNotEqual(vm.backgroundColor, Color(white: 0.15))

        let expectation = XCTestExpectation(description: "sent confirmation cleared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            XCTAssertNil(vm.gestureLabel)
            XCTAssertFalse(vm.showSentConfirmation)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    func testLocalGestureSingleTapAdvancesIndexAndSends() {
        let vm = WatchReplyViewModel()
        vm.replies = ["A", "B", "C"]
        vm.selectedIndex = 0

        vm.handleLocalGesture("singleTap")
        XCTAssertEqual(vm.selectedIndex, 1)
        // local feedback should also be set
        XCTAssertEqual(vm.gestureLabel, "Tap")
    }
}
