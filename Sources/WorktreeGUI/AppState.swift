import Foundation
import SwiftUI
import WorktreeCore

@MainActor
final class AppState: ObservableObject {
    @Published var config: Config
    @Published var repos: [Repo] = []
    @Published var worktreesByRepo: [String: [Worktree]] = [:]
    @Published var log: [String] = []
    @Published var lastError: String?
    @Published var isRefreshing = false
    @Published var newWorktreeRepoPath: String?   // repo to show in the New Worktree window

    private let store: ConfigStore
    private let runner: ProcessRunner = SystemProcessRunner()
    private var git: GitService { GitService(runner: runner) }
    private var launcher: Launcher { Launcher(runner: runner) }

    init() {
        let store = ConfigStore(path: ConfigStore.defaultPath)
        self.store = store
        self.config = (try? store.load()) ?? .default
    }

    func refresh() {
        // Scan + per-repo `git worktree list` run off the main thread so the
        // menubar popup never freezes while many repos are inspected.
        let config = self.config
        isRefreshing = true
        Task.detached { [weak self] in
            let scanned = RepoScanner().scan(roots: config.scanRoots,
                                             depth: config.scanDepth,
                                             manual: config.manualRepos)
            let git = GitService(runner: SystemProcessRunner())
            var map: [String: [Worktree]] = [:]
            for repo in scanned {
                map[repo.path] = (try? git.worktrees(repoPath: repo.path)) ?? []
            }
            await MainActor.run {
                self?.repos = scanned
                self?.worktreesByRepo = map
                self?.isRefreshing = false
            }
        }
    }

    func branches(for repo: Repo) -> [String] {
        (try? git.branches(repoPath: repo.path)) ?? []
    }

    func defaultBase(for repo: Repo) -> String {
        config.repos["\(repo.group)/\(repo.name)"]?.defaultBase ?? config.defaults.defaultBase
    }

    func createWorktree(_ req: WorktreeRequest) {
        log = []
        lastError = nil
        let creator = WorktreeCreator(config: config, git: git,
                                      setup: SetupRunner(runner: runner))
        Task.detached { [weak self] in
            do {
                let wt = try creator.create(req) { line in
                    Task { @MainActor in self?.log.append(line) }
                }
                await MainActor.run {
                    self?.log.append("✓ \(wt.path)")
                    self?.refresh()
                }
            } catch {
                await MainActor.run {
                    self?.lastError = "\(error)"
                    self?.refresh()
                }
            }
        }
    }

    func removeWorktree(repo: Repo, worktree: Worktree, deleteBranch: Bool) {
        do {
            try git.removeWorktree(repoPath: repo.path, worktreePath: worktree.path)
            if deleteBranch { try? git.deleteBranch(repoPath: repo.path, branch: worktree.branch) }
            refresh()
        } catch { lastError = "\(error)" }
    }

    func openEditor(_ path: String) { try? launcher.openInEditor(config.editorApp, path: path) }
    func openTerminal(_ path: String) { try? launcher.openInTerminal(config.terminalApp, path: path) }
    func openFinder(_ path: String) { try? launcher.openInFinder(path: path) }

    func saveConfig() { try? store.save(config); refresh() }
}
