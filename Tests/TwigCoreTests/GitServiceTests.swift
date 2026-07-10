import XCTest
@testable import TwigCore

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

    func testRemoveWorktreeBuildsArgs() throws {
        let fake = FakeProcessRunner()
        try GitService(runner: fake).removeWorktree(repoPath: "/repo", worktreePath: "/wt/x")
        XCTAssertEqual(fake.calls.first?.args, ["-C", "/repo", "worktree", "remove", "/wt/x"])
    }

    func testRemoveWorktreeForceAppendsFlag() throws {
        let fake = FakeProcessRunner()
        try GitService(runner: fake).removeWorktree(repoPath: "/repo", worktreePath: "/wt/x", force: true)
        XCTAssertEqual(fake.calls.first?.args, ["-C", "/repo", "worktree", "remove", "/wt/x", "--force"])
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

    func testWorktreeSyncDefaultsUnknownAndNotPrimary() {
        let wt = Worktree(path: "/wt/x", branch: "feature")
        XCTAssertEqual(wt.sync, .unknown)
        XCTAssertFalse(wt.isPrimary)
    }

    func testIsSafeToCleanOnlyWhenMergedCleanAndNotPrimary() {
        func wt(_ sync: SyncStatus, dirty: Bool = false, primary: Bool = false) -> Worktree {
            Worktree(path: "/wt/x", branch: "b", isDirty: dirty, sync: sync, isPrimary: primary)
        }
        XCTAssertTrue(wt(.merged).isSafeToClean)
        XCTAssertFalse(wt(.merged, dirty: true).isSafeToClean)   // uncommitted work
        XCTAssertFalse(wt(.merged, primary: true).isSafeToClean) // base worktree
        XCTAssertFalse(wt(.ahead(2)).isSafeToClean)              // not merged
        XCTAssertFalse(wt(.unknown).isSafeToClean)
    }

    // MARK: mergeStatus

    /// Branch fully contained in origin/<base> → merged. Uses origin ref.
    func testMergeStatusMergedUsesOriginBase() {
        let fake = FakeProcessRunner()
        fake.results = [
            ProcessResult(exitCode: 0, stdout: "abc\n", stderr: ""),   // rev-parse origin/main
            ProcessResult(exitCode: 0, stdout: "", stderr: ""),        // merge-base --is-ancestor
        ]
        let status = GitService(runner: fake).mergeStatus(repoPath: "/repo", branch: "feature", base: "main")
        XCTAssertEqual(status, .merged)
        XCTAssertEqual(fake.calls[0].args,
                       ["-C", "/repo", "rev-parse", "--verify", "--quiet", "origin/main"])
        XCTAssertEqual(fake.calls[1].args,
                       ["-C", "/repo", "merge-base", "--is-ancestor", "feature", "origin/main"])
    }

    func testMergeStatusAhead() {
        let fake = FakeProcessRunner()
        fake.results = [
            ProcessResult(exitCode: 0, stdout: "abc\n", stderr: ""),   // rev-parse origin/main
            ProcessResult(exitCode: 1, stdout: "", stderr: ""),        // merge-base: not ancestor
            ProcessResult(exitCode: 0, stdout: "0\t3\n", stderr: ""),  // rev-list behind\tahead
        ]
        let status = GitService(runner: fake).mergeStatus(repoPath: "/repo", branch: "feature", base: "main")
        XCTAssertEqual(status, .ahead(3))
        XCTAssertEqual(fake.calls[2].args,
                       ["-C", "/repo", "rev-list", "--left-right", "--count", "origin/main...feature"])
    }

    func testMergeStatusBehind() {
        let fake = FakeProcessRunner()
        fake.results = [
            ProcessResult(exitCode: 0, stdout: "abc\n", stderr: ""),
            ProcessResult(exitCode: 1, stdout: "", stderr: ""),
            ProcessResult(exitCode: 0, stdout: "2\t0\n", stderr: ""),
        ]
        XCTAssertEqual(GitService(runner: fake).mergeStatus(repoPath: "/repo", branch: "feature", base: "main"),
                       .behind(2))
    }

    func testMergeStatusDiverged() {
        let fake = FakeProcessRunner()
        fake.results = [
            ProcessResult(exitCode: 0, stdout: "abc\n", stderr: ""),
            ProcessResult(exitCode: 1, stdout: "", stderr: ""),
            ProcessResult(exitCode: 0, stdout: "2\t3\n", stderr: ""),
        ]
        XCTAssertEqual(GitService(runner: fake).mergeStatus(repoPath: "/repo", branch: "feature", base: "main"),
                       .diverged(ahead: 3, behind: 2))
    }

    func testMergeStatusEven() {
        let fake = FakeProcessRunner()
        fake.results = [
            ProcessResult(exitCode: 0, stdout: "abc\n", stderr: ""),
            ProcessResult(exitCode: 1, stdout: "", stderr: ""),
            ProcessResult(exitCode: 0, stdout: "0\t0\n", stderr: ""),
        ]
        XCTAssertEqual(GitService(runner: fake).mergeStatus(repoPath: "/repo", branch: "feature", base: "main"),
                       .even)
    }

    /// origin/<base> missing → falls back to local <base> ref.
    func testMergeStatusFallsBackToLocalBase() {
        let fake = FakeProcessRunner()
        fake.results = [
            ProcessResult(exitCode: 128, stdout: "", stderr: ""),   // rev-parse origin/main: missing
            ProcessResult(exitCode: 0, stdout: "abc\n", stderr: ""), // rev-parse main: found
            ProcessResult(exitCode: 0, stdout: "", stderr: ""),      // merge-base ancestor
        ]
        let status = GitService(runner: fake).mergeStatus(repoPath: "/repo", branch: "feature", base: "main")
        XCTAssertEqual(status, .merged)
        XCTAssertEqual(fake.calls[2].args,
                       ["-C", "/repo", "merge-base", "--is-ancestor", "feature", "main"])
    }

    /// Neither origin/<base> nor local <base> resolves → unknown.
    func testMergeStatusUnknownWhenBaseUnresolved() {
        let fake = FakeProcessRunner()
        fake.results = [
            ProcessResult(exitCode: 128, stdout: "", stderr: ""),
            ProcessResult(exitCode: 128, stdout: "", stderr: ""),
        ]
        XCTAssertEqual(GitService(runner: fake).mergeStatus(repoPath: "/repo", branch: "feature", base: "main"),
                       .unknown)
    }
}
