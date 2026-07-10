import XCTest
@testable import TwigCore

final class PlaceholderResolverTests: XCTestCase {
    func testSubstitutesKnownTokens() throws {
        let r = PlaceholderResolver(values: ["group": "example_repos", "type": "student", "taskName": "randevu"])
        XCTAssertEqual(try r.resolve("{group}/task/{type}/{taskName}"),
                       "example_repos/task/student/randevu")
    }

    func testSubstitutesInArbitraryString() throws {
        let r = PlaceholderResolver(values: ["taskName": "randevu"])
        XCTAssertEqual(try r.resolve("https://student-{taskName}.dev.example.com/api"),
                       "https://student-randevu.dev.example.com/api")
    }

    func testUnknownTokenThrows() {
        let r = PlaceholderResolver(values: ["taskName": "x"])
        XCTAssertThrowsError(try r.resolve("{group}/{taskName}")) { error in
            XCTAssertEqual(error as? PlaceholderError, .unresolved("group"))
        }
    }

    func testEmptyTokenThrows() {
        let r = PlaceholderResolver(values: [:])
        XCTAssertThrowsError(try r.resolve("{}")) { error in
            XCTAssertEqual(error as? PlaceholderError, .unresolved(""))
        }
    }

    func testNoTokensReturnsInput() throws {
        let r = PlaceholderResolver(values: [:])
        XCTAssertEqual(try r.resolve("plain"), "plain")
    }

    func testWorktreeTokensAreKnownSet() {
        XCTAssertEqual(PlaceholderResolver.worktreeTokens,
                       ["group", "repo", "type", "taskName", "branch"])
    }

    func testUnknownWorktreeTokenReturnsOffender() {
        XCTAssertEqual(PlaceholderResolver.unknownWorktreeToken(in: "{group}/{bogus}"), "bogus")
    }

    func testValidWorktreeTemplateReturnsNil() {
        XCTAssertNil(PlaceholderResolver.unknownWorktreeToken(in: "{group}/task/{type}-{taskName}"))
    }

    func testPlainWorktreeTemplateReturnsNil() {
        XCTAssertNil(PlaceholderResolver.unknownWorktreeToken(in: "worktrees/x"))
    }
}
