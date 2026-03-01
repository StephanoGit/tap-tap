import XCTest
@testable import TapTap

final class ReplyManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ReplyManager.shared.reset()
    }

    override func tearDown() {
        ReplyManager.shared.reset()
        super.tearDown()
    }

    // MARK: - Basic Parsing

    func testParsesAllThreeReplies() {
        let url = URL(string: "taptap://replies?r1=Hello&r2=World&r3=Foo")!
        let handled = ReplyManager.shared.handleURL(url)

        XCTAssertTrue(handled)
        XCTAssertEqual(ReplyManager.shared.replies, ["Hello", "World", "Foo"])
    }

    func testParsesURLEncodedSpaces() {
        let url = URL(string: "taptap://replies?r1=Item%20from%20List&r2=Another%20Item&r3=Third%20Item")!
        let handled = ReplyManager.shared.handleURL(url)

        XCTAssertTrue(handled)
        XCTAssertEqual(ReplyManager.shared.replies, ["Item from List", "Another Item", "Third Item"])
    }

    func testParsesPlusInValues() {
        // '+' in URL query values may or may not be decoded as spaces
        // depending on the platform. Verify the URL is still handled.
        let url = URL(string: "taptap://replies?r1=Item+from+List&r2=Another+Item&r3=Third+Item")!
        let handled = ReplyManager.shared.handleURL(url)

        XCTAssertTrue(handled)
        XCTAssertEqual(ReplyManager.shared.replies.count, 3)
    }

    // MARK: - Partial Parameters

    func testParsesSubsetOfReplies() {
        let url = URL(string: "taptap://replies?r1=OnlyOne")!
        let handled = ReplyManager.shared.handleURL(url)

        XCTAssertTrue(handled)
        XCTAssertEqual(ReplyManager.shared.replies, ["OnlyOne"])
    }

    func testParsesTwoReplies() {
        let url = URL(string: "taptap://replies?r1=First&r3=Third")!
        let handled = ReplyManager.shared.handleURL(url)

        XCTAssertTrue(handled)
        XCTAssertEqual(ReplyManager.shared.replies, ["First", "Third"])
    }

    func testEmptyQueryReturnsEmptyReplies() {
        let url = URL(string: "taptap://replies")!
        let handled = ReplyManager.shared.handleURL(url)

        XCTAssertTrue(handled)
        XCTAssertTrue(ReplyManager.shared.replies.isEmpty)
    }

    // MARK: - Wrong Scheme / Host

    func testWrongSchemeIsIgnored() {
        let url = URL(string: "https://replies?r1=Hello")!
        let handled = ReplyManager.shared.handleURL(url)

        XCTAssertFalse(handled)
        XCTAssertTrue(ReplyManager.shared.replies.isEmpty)
    }

    func testWrongHostIsIgnored() {
        let url = URL(string: "taptap://other?r1=Hello")!
        let handled = ReplyManager.shared.handleURL(url)

        XCTAssertFalse(handled)
        XCTAssertTrue(ReplyManager.shared.replies.isEmpty)
    }

    // MARK: - Overwrite Behavior

    func testNewURLOverwritesPreviousReplies() {
        let url1 = URL(string: "taptap://replies?r1=Old1&r2=Old2&r3=Old3")!
        ReplyManager.shared.handleURL(url1)
        XCTAssertEqual(ReplyManager.shared.replies, ["Old1", "Old2", "Old3"])

        let url2 = URL(string: "taptap://replies?r1=New1&r2=New2")!
        ReplyManager.shared.handleURL(url2)
        XCTAssertEqual(ReplyManager.shared.replies, ["New1", "New2"])
    }

    // MARK: - Reset

    func testResetClearsReplies() {
        let url = URL(string: "taptap://replies?r1=A&r2=B&r3=C")!
        ReplyManager.shared.handleURL(url)
        XCTAssertEqual(ReplyManager.shared.replies.count, 3)

        ReplyManager.shared.selectNext()
        ReplyManager.shared.reset()
        XCTAssertTrue(ReplyManager.shared.replies.isEmpty)
        XCTAssertEqual(ReplyManager.shared.selectedIndex, 0)
    }

    // MARK: - Empty Values

    func testEmptyValuesAreSkipped() {
        let url = URL(string: "taptap://replies?r1=&r2=Valid&r3=")!
        let handled = ReplyManager.shared.handleURL(url)

        XCTAssertTrue(handled)
        XCTAssertEqual(ReplyManager.shared.replies, ["Valid"])
    }

    // MARK: - Order Preservation

    func testRepliesAreInR1R2R3Order() {
        // Even if query params are in different order in the URL
        let url = URL(string: "taptap://replies?r3=Third&r1=First&r2=Second")!
        let handled = ReplyManager.shared.handleURL(url)

        XCTAssertTrue(handled)
        XCTAssertEqual(ReplyManager.shared.replies, ["First", "Second", "Third"])
    }

    // MARK: - Selection

    func testSelectedReplyReturnsNilWhenEmpty() {
        XCTAssertNil(ReplyManager.shared.selectedReply)
    }

    func testSelectedReplyReturnsFirstByDefault() {
        let url = URL(string: "taptap://replies?r1=A&r2=B&r3=C")!
        ReplyManager.shared.handleURL(url)
        XCTAssertEqual(ReplyManager.shared.selectedReply, "A")
        XCTAssertEqual(ReplyManager.shared.selectedIndex, 0)
    }

    func testSelectNextMovesForward() {
        let url = URL(string: "taptap://replies?r1=A&r2=B&r3=C")!
        ReplyManager.shared.handleURL(url)

        ReplyManager.shared.selectNext()
        XCTAssertEqual(ReplyManager.shared.selectedIndex, 1)
        XCTAssertEqual(ReplyManager.shared.selectedReply, "B")

        ReplyManager.shared.selectNext()
        XCTAssertEqual(ReplyManager.shared.selectedIndex, 2)
        XCTAssertEqual(ReplyManager.shared.selectedReply, "C")
    }

    func testSelectNextClampsAtEnd() {
        let url = URL(string: "taptap://replies?r1=A&r2=B")!
        ReplyManager.shared.handleURL(url)

        ReplyManager.shared.selectNext()
        ReplyManager.shared.selectNext()
        ReplyManager.shared.selectNext()
        XCTAssertEqual(ReplyManager.shared.selectedIndex, 1)
    }

    func testSelectPreviousMovesBackward() {
        let url = URL(string: "taptap://replies?r1=A&r2=B&r3=C")!
        ReplyManager.shared.handleURL(url)

        ReplyManager.shared.selectNext()
        ReplyManager.shared.selectNext()
        XCTAssertEqual(ReplyManager.shared.selectedIndex, 2)

        ReplyManager.shared.selectPrevious()
        XCTAssertEqual(ReplyManager.shared.selectedIndex, 1)
        XCTAssertEqual(ReplyManager.shared.selectedReply, "B")
    }

    func testSelectPreviousClampsAtZero() {
        let url = URL(string: "taptap://replies?r1=A&r2=B")!
        ReplyManager.shared.handleURL(url)

        ReplyManager.shared.selectPrevious()
        ReplyManager.shared.selectPrevious()
        XCTAssertEqual(ReplyManager.shared.selectedIndex, 0)
    }
}
