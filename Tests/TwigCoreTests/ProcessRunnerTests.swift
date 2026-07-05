import XCTest
@testable import TwigCore

final class ProcessRunnerTests: XCTestCase {
    func testSystemRunnerRunsEcho() throws {
        let runner = SystemProcessRunner()
        let result = try runner.run("echo", ["hello"], cwd: nil)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, "hello\n")
    }

    func testFakeRecordsCallsAndReturnsResults() throws {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 0, stdout: "ok", stderr: "")]
        let r = try fake.run("git", ["status"], cwd: "/tmp")
        XCTAssertEqual(r.stdout, "ok")
        XCTAssertEqual(fake.calls, [.init(executable: "git", args: ["status"], cwd: "/tmp")])
    }
}
