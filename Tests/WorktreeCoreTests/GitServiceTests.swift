import XCTest
@testable import WorktreeCore

final class GitServiceTests: XCTestCase {
    func testAddExistingBranchBuildsArgs() throws {
        let fake = FakeProcessRunner()
        try GitService(runner: fake).addWorktree(
            repoPath: "/repo", worktreePath: "/wt/x", branch: "feature", newBranchBase: nil)
        XCTAssertEqual(fake.calls.first?.executable, "git")
        XCTAssertEqual(fake.calls.first?.args,
                       ["-C", "/repo", "worktree", "add", "/wt/x", "feature"])
    }

    func testAddNewBranchBuildsArgs() throws {
        let fake = FakeProcessRunner()
        try GitService(runner: fake).addWorktree(
            repoPath: "/repo", worktreePath: "/wt/x", branch: "feature", newBranchBase: "develop")
        XCTAssertEqual(fake.calls.first?.args,
                       ["-C", "/repo", "worktree", "add", "-b", "feature", "/wt/x", "develop"])
    }

    func testNonZeroExitThrows() {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 128, stdout: "", stderr: "fatal: boom")]
        XCTAssertThrowsError(try GitService(runner: fake).removeWorktree(
            repoPath: "/repo", worktreePath: "/wt/x")) { error in
            XCTAssertEqual(error as? GitError,
                           .command(args: ["-C", "/repo", "worktree", "remove", "/wt/x"],
                                    exitCode: 128, stderr: "fatal: boom"))
        }
    }

    func testParsesWorktreeListPorcelain() throws {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 0, stdout: """
        worktree /repo
        HEAD abc123
        branch refs/heads/main

        worktree /wt/randevu
        HEAD def456
        branch refs/heads/randevu

        worktree /wt/detached
        HEAD ff0011
        detached

        """, stderr: "")]
        let result = try GitService(runner: fake).worktrees(repoPath: "/repo")
        XCTAssertEqual(result, [
            Worktree(path: "/repo", branch: "main"),
            Worktree(path: "/wt/randevu", branch: "randevu"),
            Worktree(path: "/wt/detached", branch: "(detached)"),
        ])
    }

    func testParsesBranches() throws {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 0, stdout: "main\ndevelop\nfeature\n", stderr: "")]
        XCTAssertEqual(try GitService(runner: fake).branches(repoPath: "/repo"),
                       ["main", "develop", "feature"])
    }

    func testPruneBuildsArgs() throws {
        let fake = FakeProcessRunner()
        try GitService(runner: fake).prune(repoPath: "/repo")
        XCTAssertEqual(fake.calls.first?.args, ["-C", "/repo", "worktree", "prune"])
    }

    func testIsDirtyTrueWhenPorcelainNonEmpty() throws {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 0, stdout: " M file.swift\n", stderr: "")]
        XCTAssertTrue(try GitService(runner: fake).isDirty(worktreePath: "/wt/x"))
        XCTAssertEqual(fake.calls.first?.args, ["-C", "/wt/x", "status", "--porcelain"])
    }

    func testIsDirtyFalseWhenPorcelainEmpty() throws {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 0, stdout: "", stderr: "")]
        XCTAssertFalse(try GitService(runner: fake).isDirty(worktreePath: "/wt/x"))
    }

    func testIsDirtyFalseWhenPorcelainWhitespaceOnly() throws {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 0, stdout: "\n", stderr: "")]
        XCTAssertFalse(try GitService(runner: fake).isDirty(worktreePath: "/wt/x"))
    }

    func testIsDirtyThrowsOnNonZeroExit() {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 128, stdout: "", stderr: "fatal: not a git repo")]
        XCTAssertThrowsError(try GitService(runner: fake).isDirty(worktreePath: "/wt/x")) { error in
            XCTAssertEqual(error as? GitError,
                           .command(args: ["-C", "/wt/x", "status", "--porcelain"],
                                    exitCode: 128, stderr: "fatal: not a git repo"))
        }
    }

    func testWorktreeIsDirtyDefaultsFalse() {
        XCTAssertFalse(Worktree(path: "/wt/x", branch: "main").isDirty)
    }
}
