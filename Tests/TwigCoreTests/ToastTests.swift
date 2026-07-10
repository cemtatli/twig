import XCTest
@testable import TwigCore

final class ToastTests: XCTestCase {
    func testToastCarriesMessageAndKind() {
        let t = Toast(message: "oluşturuldu", kind: .success)
        XCTAssertEqual(t.message, "oluşturuldu")
        XCTAssertEqual(t.kind, .success)
    }

    func testToastsWithDistinctIdsAreNotEqual() {
        let a = Toast(message: "x", kind: .error)
        let b = Toast(message: "x", kind: .error)
        XCTAssertNotEqual(a, b)   // unique id per instance
    }

    // MARK: friendlyMessage

    func testFriendlyMessageUsesLastNonEmptyStderrLine() {
        let err = GitError.command(args: ["worktree", "remove"], exitCode: 128,
                                   stderr: "warning: something\nfatal: worktree is dirty\n")
        XCTAssertEqual(friendlyMessage(err), "fatal: worktree is dirty")
    }

    func testFriendlyMessageFallsBackWhenStderrEmpty() {
        let err = GitError.command(args: ["a"], exitCode: 1, stderr: "   \n")
        XCTAssertEqual(friendlyMessage(err), "git error (exit 1)")
    }

    func testFriendlyMessageForNonGitError() {
        struct Boom: Error {}
        XCTAssertFalse(friendlyMessage(Boom()).isEmpty)
    }
}
