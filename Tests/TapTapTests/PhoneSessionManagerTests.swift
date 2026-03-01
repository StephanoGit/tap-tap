import XCTest
@testable import TapTap

final class PhoneSessionManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // ensure some state present
        ReplyManager.shared.reset()
        ReplyManager.shared.replies = ["X", "Y"]
        ReplyManager.shared.selectedIndex = 0
    }

    func testPushReplyStateIncludesGestureAck() {
        let state = PhoneSessionManager.shared.pushReplyState(gestureAck: "singleTap")
        XCTAssertEqual(state["replies"] as? [String], ["X", "Y"])
        XCTAssertEqual(state["selectedIndex"] as? Int, 0)
        XCTAssertEqual(state["gestureAck"] as? String, "singleTap")
    }

    func testGestureRouterSingleAndDoubleTapAdvanceSelection() {
        ReplyManager.shared.replies = ["1", "2", "3"]
        ReplyManager.shared.selectedIndex = 0

        // single tap
        GestureRouter.shared.handle("singleTap")
        XCTAssertEqual(ReplyManager.shared.selectedIndex, 1)

        // double tap should also advance now
        GestureRouter.shared.handle("doubleTap")
        XCTAssertEqual(ReplyManager.shared.selectedIndex, 2)
    }
}
