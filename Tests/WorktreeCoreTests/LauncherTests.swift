import XCTest
@testable import WorktreeCore

final class LauncherTests: XCTestCase {
    func testOpenInEditor() throws {
        let fake = FakeProcessRunner()
        try Launcher(runner: fake).openInEditor("Cursor", path: "/wt/x")
        XCTAssertEqual(fake.calls.first?.executable, "open")
        XCTAssertEqual(fake.calls.first?.args, ["-a", "Cursor", "/wt/x"])
    }

    func testOpenInTerminal() throws {
        let fake = FakeProcessRunner()
        try Launcher(runner: fake).openInTerminal("iTerm", path: "/wt/x")
        XCTAssertEqual(fake.calls.first?.args, ["-a", "iTerm", "/wt/x"])
    }

    func testOpenInFinder() throws {
        let fake = FakeProcessRunner()
        try Launcher(runner: fake).openInFinder(path: "/wt/x")
        XCTAssertEqual(fake.calls.first?.args, ["/wt/x"])
    }

    func testFailureThrows() {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 1, stdout: "", stderr: "no app")]
        XCTAssertThrowsError(try Launcher(runner: fake).openInFinder(path: "/x")) { error in
            XCTAssertEqual(error as? LaunchError, .failed(stderr: "no app"))
        }
    }
}
