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

    func testOpenInTerminalWithStartupCommandOpensScript() throws {
        let fake = FakeProcessRunner()
        let wt = NSTemporaryDirectory() + "wt-\(UUID().uuidString)"
        try Launcher(runner: fake).openInTerminal("cmux", path: wt, startupCommand: "npm run dev")
        let call = try XCTUnwrap(fake.calls.first)
        XCTAssertEqual(call.executable, "open")
        XCTAssertEqual(call.args.count, 3)
        XCTAssertEqual(call.args[0], "-a")
        XCTAssertEqual(call.args[1], "cmux")
        let scriptPath = call.args[2]
        XCTAssertTrue(scriptPath.hasSuffix(".command"))
        let contents = try String(contentsOfFile: scriptPath, encoding: .utf8)
        XCTAssertTrue(contents.contains("npm run dev"))
        XCTAssertTrue(contents.contains("cd '\(wt)'"))
    }

    func testOpenInTerminalEmptyCommandJustOpensPath() throws {
        let fake = FakeProcessRunner()
        try Launcher(runner: fake).openInTerminal("Terminal", path: "/wt/x", startupCommand: "   ")
        XCTAssertEqual(fake.calls.first?.args, ["-a", "Terminal", "/wt/x"])
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
