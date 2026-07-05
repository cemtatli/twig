import XCTest
@testable import TwigCore

final class WorktreeCreatorTests: XCTestCase {
    private func makeConfig() -> Config {
        var c = Config.default
        c.repos["example_repos/example-student"] = RepoSettings(
            type: "student",
            worktreePath: nil,
            defaultBase: "develop",
            envRules: [EnvRule(file: ".env.development", key: "VITE_API_URL",
                               value: "https://student-{taskName}.dev.example.com/api")],
            setupCommands: ["npm install"]
        )
        return c
    }

    private func studentRequest() -> WorktreeRequest {
        let repo = Repo(path: "/Users/example/Dev/example_repos/example-student",
                        name: "example-student", group: "example_repos")
        return WorktreeRequest(repo: repo, branch: "randevu", taskName: "randevu", newBranchBase: nil)
    }

    func testResolvedPathUsesRootGroupTypeTaskName() throws {
        let creator = WorktreeCreator(config: makeConfig(),
                                      git: GitService(runner: FakeProcessRunner()),
                                      setup: SetupRunner(runner: FakeProcessRunner()))
        let path = try creator.resolvedPath(for: studentRequest())
        XCTAssertEqual(path, "/Users/example/Dev/example_repos/task/student-randevu")
    }

    func testDerivesTypeWhenNotConfigured() throws {
        var config = Config.default   // repos boş -> defaults + türetilmiş type
        config.defaults.worktreePath = "{group}/task/{type}/{taskName}"
        let creator = WorktreeCreator(config: config,
                                      git: GitService(runner: FakeProcessRunner()),
                                      setup: SetupRunner(runner: FakeProcessRunner()))
        let repo = Repo(path: "/Users/example/Dev/example_repos/example-admin", name: "example-admin", group: "example_repos")
        let req = WorktreeRequest(repo: repo, branch: "x", taskName: "x", newBranchBase: nil)
        XCTAssertEqual(try creator.resolvedPath(for: req),
                       "/Users/example/Dev/example_repos/task/admin/x")
    }

    func testCreateCallsGitThenSetupInOrder() throws {
        let gitFake = FakeProcessRunner()
        let setupFake = FakeProcessRunner()
        let creator = WorktreeCreator(config: makeConfig(),
                                      git: GitService(runner: gitFake),
                                      setup: SetupRunner(runner: setupFake))

        // Create the worktree directory for env rules file write
        let wtPath = "/Users/example/Dev/example_repos/task/student-randevu"
        try FileManager.default.createDirectory(atPath: wtPath, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: wtPath) }

        let wt = try creator.create(studentRequest(), progress: { _ in })

        XCTAssertEqual(wt, Worktree(path: wtPath, branch: "randevu"))
        // git worktree add çağrıldı
        XCTAssertEqual(gitFake.calls.first?.args,
                       ["-C", "/Users/example/Dev/example_repos/example-student", "worktree", "add",
                        "/Users/example/Dev/example_repos/task/student-randevu", "randevu"])
        // setupCommands sh ile çalıştı
        XCTAssertEqual(setupFake.calls.first?.executable, "sh")
        XCTAssertEqual(setupFake.calls.first?.args, ["-c", "npm install"])
    }

    func testCreateUsesDefaultEnvRulesWhenRepoHasNone() throws {
        var config = Config.default
        config.defaults.envRules = [EnvRule(file: ".env.development", key: "VITE_API_URL",
                                            value: "https://{type}-{taskName}.dev.example.com/api")]
        // Repo NOT in config.repos -> type derived from name, defaults apply.
        let repo = Repo(path: "/Users/example/Dev/example_repos/example-ekurs", name: "example-ekurs", group: "example_repos")
        let req = WorktreeRequest(repo: repo, branch: "x", taskName: "demo", newBranchBase: nil)

        let wtPath = "/Users/example/Dev/example_repos/task/ekurs-demo"
        try FileManager.default.createDirectory(atPath: wtPath, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: wtPath) }

        let creator = WorktreeCreator(config: config,
                                      git: GitService(runner: FakeProcessRunner()),
                                      setup: SetupRunner(runner: FakeProcessRunner()))
        _ = try creator.create(req, progress: { _ in })

        let written = try String(contentsOfFile: wtPath + "/.env.development", encoding: .utf8)
        XCTAssertEqual(written, "VITE_API_URL=https://ekurs-demo.dev.example.com/api\n")
    }

    func testCreateHaltsWhenGitFails() {
        let gitFake = FakeProcessRunner()
        gitFake.results = [ProcessResult(exitCode: 128, stdout: "", stderr: "fatal")]
        let setupFake = FakeProcessRunner()
        let creator = WorktreeCreator(config: makeConfig(),
                                      git: GitService(runner: gitFake),
                                      setup: SetupRunner(runner: setupFake))
        XCTAssertThrowsError(try creator.create(studentRequest(), progress: { _ in }))
        XCTAssertTrue(setupFake.calls.isEmpty)   // git başarısız -> setup hiç çalışmadı
    }
}
