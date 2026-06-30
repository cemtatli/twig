import XCTest
@testable import WorktreeCore

final class RepoScannerTests: XCTestCase {
    private var root: String!

    override func setUpWithError() throws {
        root = NSTemporaryDirectory() + "wt-scan-\(UUID().uuidString)"
        // <root>/example_repos/example-admin/.git  (repo)
        // <root>/.hidden/repo/.git (atlanmalı)
        // <root>/plain  (repo değil)
        try makeRepo("example_repos/example-admin")
        try makeDir("example_repos/plainfolder")
        try makeRepo(".hidden/repo")
        try makeDir("plain")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: root)
    }

    private func makeDir(_ rel: String) throws {
        try FileManager.default.createDirectory(atPath: root + "/" + rel, withIntermediateDirectories: true)
    }
    private func makeRepo(_ rel: String) throws {
        try makeDir(rel + "/.git")
    }

    func testFindsGitRepoAndDerivesGroup() {
        let repos = RepoScanner().scan(roots: [root], depth: 3, manual: [])
        XCTAssertEqual(repos.map(\.name), ["example-admin"])
        XCTAssertEqual(repos.first?.group, "example_repos")
        XCTAssertEqual(repos.first?.path, root + "/example_repos/example-admin")
    }

    func testSkipsHiddenDirectories() {
        let repos = RepoScanner().scan(roots: [root], depth: 3, manual: [])
        XCTAssertFalse(repos.contains { $0.path.contains("/.hidden/") })
    }

    func testMergesManualReposDeduplicated() throws {
        let manual = root + "/example_repos/example-admin"   // zaten taranıyor -> tek kalmalı
        let extra = root + "/standalone"
        try makeRepo("standalone")
        let repos = RepoScanner().scan(roots: [root], depth: 3, manual: [manual, extra])
        let paths = repos.map(\.path)
        XCTAssertEqual(paths.filter { $0 == manual }.count, 1)
        XCTAssertTrue(paths.contains(extra))
    }

    func testManualNonRepoPathIsNotAdded() throws {
        let notARepo = root + "/just-a-folder"
        try makeDir("just-a-folder")   // no .git inside
        let repos = RepoScanner().scan(roots: [root], depth: 3, manual: [notARepo])
        XCTAssertFalse(repos.contains { $0.path == notARepo })
    }

    func testSkipsGitFileWorktree() throws {
        try makeDir("worktree-style")
        try "gitdir: /some/base/.git/worktrees/x".write(
            toFile: root + "/worktree-style/.git", atomically: true, encoding: .utf8)
        let repos = RepoScanner().scan(roots: [root], depth: 3, manual: [])
        XCTAssertFalse(repos.contains { $0.path == root + "/worktree-style" })
    }
}
