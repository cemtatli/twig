import XCTest
@testable import TwigCore

final class LauncherTests: XCTestCase {
    func testOpenInEditorUsesCursorCLI() throws {
        let fake = FakeProcessRunner()   // default exit 0 → CLI succeeds, no fallback
        try Launcher(runner: fake).openInEditor("Cursor", path: "/wt/x")
        XCTAssertEqual(fake.calls.count, 1)
        XCTAssertEqual(fake.calls.first?.executable, "cursor")
        XCTAssertEqual(fake.calls.first?.args, ["/wt/x"])
    }

    func testOpenInEditorFallsBackToOpenWhenCLIFails() throws {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 127, stdout: "", stderr: "not found")]  // CLI missing
        try Launcher(runner: fake).openInEditor("Cursor", path: "/wt/x")
        XCTAssertEqual(fake.calls.count, 2)
        XCTAssertEqual(fake.calls[0].executable, "cursor")
        XCTAssertEqual(fake.calls[1].executable, "open")
        XCTAssertEqual(fake.calls[1].args, ["-a", "Cursor", "/wt/x"])
    }

    func testOpenInEditorWithoutCLIUsesOpen() throws {
        let fake = FakeProcessRunner()
        try Launcher(runner: fake).openInEditor("Xcode", path: "/wt/x")
        XCTAssertEqual(fake.calls.first?.executable, "open")
        XCTAssertEqual(fake.calls.first?.args, ["-a", "Xcode", "/wt/x"])
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
