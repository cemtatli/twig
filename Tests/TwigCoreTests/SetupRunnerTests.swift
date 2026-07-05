import XCTest
@testable import TwigCore

final class SetupRunnerTests: XCTestCase {
    func testUpdateEnvLineReplacesOnlyTargetKey() {
        let content = "APP_ENV=development\nVITE_API_URL=https://old.example.com/api\nFOO=bar\n"
        let updated = SetupRunner.updateEnvLine(
            content: content, key: "VITE_API_URL", value: "https://student-randevu.dev.example.com/api")
        XCTAssertEqual(updated, """
        APP_ENV=development
        VITE_API_URL=https://student-randevu.dev.example.com/api
        FOO=bar

        """)
    }

    func testUpdateEnvLineAppendsWhenMissing() {
        let updated = SetupRunner.updateEnvLine(content: "FOO=bar\n", key: "VITE_API_URL", value: "x")
        XCTAssertEqual(updated, "FOO=bar\nVITE_API_URL=x\n")
    }

    func testApplyEnvRulesWritesResolvedFile() throws {
        let base = NSTemporaryDirectory() + "base-\(UUID().uuidString)"
        let wt = NSTemporaryDirectory() + "wt-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: base, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: wt, withIntermediateDirectories: true)
        try "VITE_API_URL=https://old/api\n".write(toFile: base + "/.env.development", atomically: true, encoding: .utf8)

        let runner = SetupRunner(runner: FakeProcessRunner())
        let resolver = PlaceholderResolver(values: ["taskName": "randevu"])
        try runner.applyEnvRules(
            [EnvRule(file: ".env.development", key: "VITE_API_URL",
                     value: "https://student-{taskName}.dev.example.com/api")],
            baseRepoPath: base, worktreePath: wt, resolver: resolver)

        let written = try String(contentsOfFile: wt + "/.env.development", encoding: .utf8)
        XCTAssertEqual(written, "VITE_API_URL=https://student-randevu.dev.example.com/api\n")
    }

    func testApplyEnvRulesWithMissingBaseFile() throws {
        let base = NSTemporaryDirectory() + "base-\(UUID().uuidString)"   // never created
        let wt = NSTemporaryDirectory() + "wt-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: wt, withIntermediateDirectories: true)
        let runner = SetupRunner(runner: FakeProcessRunner())
        let resolver = PlaceholderResolver(values: ["taskName": "randevu"])
        try runner.applyEnvRules(
            [EnvRule(file: ".env.development", key: "VITE_API_URL",
                     value: "https://{taskName}.dev.example.com/api")],
            baseRepoPath: base, worktreePath: wt, resolver: resolver)
        let written = try String(contentsOfFile: wt + "/.env.development", encoding: .utf8)
        XCTAssertEqual(written, "VITE_API_URL=https://randevu.dev.example.com/api\n")
    }

    func testApplyEnvRulesFallsBackToExampleFile() throws {
        let base = NSTemporaryDirectory() + "base-\(UUID().uuidString)"
        let wt = NSTemporaryDirectory() + "wt-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: base, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: wt, withIntermediateDirectories: true)
        // Only the .example exists (real .env.development is git-ignored / absent).
        try "APP_ENV=development\nVITE_API_URL=https://old/api\n"
            .write(toFile: base + "/.env.development.example", atomically: true, encoding: .utf8)

        let runner = SetupRunner(runner: FakeProcessRunner())
        let resolver = PlaceholderResolver(values: ["taskName": "randevu"])
        try runner.applyEnvRules(
            [EnvRule(file: ".env.development", key: "VITE_API_URL",
                     value: "https://{taskName}.dev.example.com/api")],
            baseRepoPath: base, worktreePath: wt, resolver: resolver)

        // Copied from .example, with only the keyed line rewritten, written to the real file.
        let written = try String(contentsOfFile: wt + "/.env.development", encoding: .utf8)
        XCTAssertEqual(written, "APP_ENV=development\nVITE_API_URL=https://randevu.dev.example.com/api\n")
    }

    func testRunCommandsExecutesInWorktreeViaShell() throws {
        let fake = FakeProcessRunner()
        let runner = SetupRunner(runner: fake)
        try runner.runCommands(["npm install"], worktreePath: "/wt/x",
                               resolver: PlaceholderResolver(values: [:]), progress: { _ in })
        XCTAssertEqual(fake.calls.first?.executable, "sh")
        XCTAssertEqual(fake.calls.first?.args, ["-c", "npm install"])
        XCTAssertEqual(fake.calls.first?.cwd, "/wt/x")
    }

    func testRunCommandsThrowsOnFailure() {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 1, stdout: "", stderr: "boom")]
        let runner = SetupRunner(runner: fake)
        XCTAssertThrowsError(try runner.runCommands(["bad"], worktreePath: "/wt/x",
            resolver: PlaceholderResolver(values: [:]), progress: { _ in })) { error in
            XCTAssertEqual(error as? SetupError, .command(command: "bad", exitCode: 1, stderr: "boom"))
        }
    }

    func testUpdateEnvLineOnEmptyContentHasNoLeadingNewline() {
        let updated = SetupRunner.updateEnvLine(content: "", key: "VITE_API_URL", value: "x")
        XCTAssertEqual(updated, "VITE_API_URL=x\n")
    }
}
