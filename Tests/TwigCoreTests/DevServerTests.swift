import XCTest
@testable import TwigCore

final class DevServerTests: XCTestCase {
    func testListeningPIDParsesLsofOutput() {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 0, stdout: "p1234\nf5\n", stderr: "")]
        XCTAssertEqual(DevServer(runner: fake).listeningPID(port: 3000), 1234)
        XCTAssertEqual(fake.calls.first?.args,
                       ["-nP", "-iTCP:3000", "-sTCP:LISTEN", "-Fp"])
    }

    func testListeningPIDNilWhenNoListener() {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 1, stdout: "", stderr: "")]
        XCTAssertNil(DevServer(runner: fake).listeningPID(port: 3000))
    }

    func testProcessCwdParsesLsofOutput() {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 0, stdout: "p1234\nfcwd\nn/Users/x/wt\n", stderr: "")]
        XCTAssertEqual(DevServer(runner: fake).processCwd(pid: 1234), "/Users/x/wt")
        XCTAssertEqual(fake.calls.first?.args, ["-a", "-p", "1234", "-d", "cwd", "-Fn"])
    }

    func testIsRunningTrueWhenCwdUnderWorktree() {
        let fake = FakeProcessRunner()
        fake.results = [
            ProcessResult(exitCode: 0, stdout: "p1234\n", stderr: ""),          // listeningPID
            ProcessResult(exitCode: 0, stdout: "fcwd\nn/Users/x/wt\n", stderr: ""), // processCwd
        ]
        XCTAssertTrue(DevServer(runner: fake).isRunning(port: 3000, worktreePath: "/Users/x/wt"))
    }

    func testIsRunningFalseWhenCwdElsewhere() {
        let fake = FakeProcessRunner()
        fake.results = [
            ProcessResult(exitCode: 0, stdout: "p1234\n", stderr: ""),
            ProcessResult(exitCode: 0, stdout: "n/Users/x/other\n", stderr: ""),
        ]
        XCTAssertFalse(DevServer(runner: fake).isRunning(port: 3000, worktreePath: "/Users/x/wt"))
    }

    func testIsRunningFalseWhenNoListener() {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 1, stdout: "", stderr: "")]
        XCTAssertFalse(DevServer(runner: fake).isRunning(port: 3000, worktreePath: "/Users/x/wt"))
    }

    func testStopKillsListeningPID() throws {
        let fake = FakeProcessRunner()
        fake.results = [
            ProcessResult(exitCode: 0, stdout: "p1234\n", stderr: ""),   // listeningPID
            ProcessResult(exitCode: 0, stdout: "", stderr: ""),          // kill
        ]
        try DevServer(runner: fake).stop(port: 3000)
        XCTAssertEqual(fake.calls.last?.executable, "kill")
        XCTAssertEqual(fake.calls.last?.args, ["1234"])
    }

    func testStopNoOpWhenNoListener() throws {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 1, stdout: "", stderr: "")]
        try DevServer(runner: fake).stop(port: 3000)
        XCTAssertEqual(fake.calls.count, 1)   // yalnız lsof; kill yok
    }

    func testWorktreeDevRunningDefaultsFalse() {
        XCTAssertFalse(Worktree(path: "/wt/x", branch: "b").devRunning)
    }

    func testLauncherOpensURL() throws {
        let fake = FakeProcessRunner()
        try Launcher(runner: fake).openURL("http://localhost:3000")
        XCTAssertEqual(fake.calls.first?.executable, "open")
        XCTAssertEqual(fake.calls.first?.args, ["http://localhost:3000"])
    }
}
