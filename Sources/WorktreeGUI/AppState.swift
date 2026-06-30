import Foundation
import SwiftUI
import AppKit
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
    @Published var sidebarCollapsed = false

    private let store: ConfigStore
    private let runner: ProcessRunner = SystemProcessRunner()
    private var git: GitService { GitService(runner: runner) }
    private var launcher: Launcher { Launcher(runner: runner) }

    init() {
        let store = ConfigStore(path: ConfigStore.defaultPath)
        self.store = store
        self.config = (try? store.load()) ?? .default
        refresh()   // populate eagerly so the first menu open is instant
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
            let fm = FileManager.default
            var map: [String: [Worktree]] = [:]
            for repo in scanned {
                try? git.prune(repoPath: repo.path)   // drop stale (deleted-folder) entries
                let all = (try? git.worktrees(repoPath: repo.path)) ?? []
                // Exclude the base repo's own checkout and any worktree whose
                // directory no longer exists on disk.
                let filtered = all.filter { $0.path != repo.path && fm.fileExists(atPath: $0.path) }
                map[repo.path] = filtered.map { wt in
                    var wt = wt
                    wt.isDirty = (try? git.isDirty(worktreePath: wt.path)) ?? false
                    return wt
                }
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

    var language: Language { Language.from(config.language) }
    func t(_ key: L10nKey) -> String { L10n.string(key, language: language) }
    func worktreeCountText(_ n: Int) -> String { L10n.worktreeCount(n, language: language) }
    func setLanguage(_ lang: Language) {
        config.language = lang.rawValue
        saveConfig()
    }

    func packageManager(for repo: Repo) -> PackageManager? {
        guard let raw = config.repos["\(repo.group)/\(repo.name)"]?.packageManager else { return nil }
        return PackageManager(rawValue: raw)
    }

    func setPackageManager(_ pm: PackageManager?, for repo: Repo) {
        let key = "\(repo.group)/\(repo.name)"
        var settings = config.repos[key] ?? RepoSettings()
        settings.packageManager = pm?.rawValue
        config.repos[key] = settings
        saveConfig()
    }

    func createWorktree(_ req: WorktreeRequest) {
        log = []
        lastError = nil
        let creator = WorktreeCreator(config: config, git: git,
                                      setup: SetupRunner(runner: runner))
        let pm = packageManager(for: req.repo)
        Task.detached { [weak self] in
            do {
                let wt = try creator.create(req) { line in
                    Task { @MainActor in self?.log.append(line) }
                }
                await MainActor.run {
                    self?.log.append("✓ \(wt.path)")
                    // A configured package manager means deps are now installed;
                    // open a terminal in the worktree running the dev server so it
                    // "arrives running".
                    if let pm, let self {
                        self.log.append("$ \(pm.devCommand)  (in terminal)")
                        try? self.launcher.openInTerminal(self.config.terminalApp,
                                                          path: wt.path,
                                                          startupCommand: pm.devCommand)
                    }
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

    /// Open a Finder panel to add repos. A chosen folder with a `.git`
    /// directory is added as a manual repo; any other folder is added as a
    /// scan root (it gets walked for repos inside it).
    func addReposViaPanel() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = t(.addPanelPrompt)
        panel.message = t(.addPanelMessage)
        panel.directoryURL = URL(fileURLWithPath: Config.expandTilde("~/Dev"))
        guard panel.runModal() == .OK else { return }

        var isDir: ObjCBool = false
        for url in panel.urls {
            let path = url.path
            let isGitDir = FileManager.default.fileExists(atPath: path + "/.git", isDirectory: &isDir) && isDir.boolValue
            if isGitDir {
                if !config.manualRepos.contains(path) { config.manualRepos.append(path) }
            } else {
                if !config.scanRoots.contains(path) { config.scanRoots.append(path) }
            }
        }
        saveConfig()   // persists + refresh()
    }

    /// Remove a scan root or manual repo entry (whichever matches) and refresh.
    func removeSource(_ path: String) {
        config.scanRoots.removeAll { $0 == path }
        config.manualRepos.removeAll { $0 == path }
        saveConfig()
    }

    func openEditor(_ path: String) { try? launcher.openInEditor(config.editorApp, path: path) }
    func openTerminal(_ path: String) {
        try? launcher.openInTerminal(config.terminalApp, path: path,
                                     startupCommand: config.terminalStartupCommand)
    }
    func openFinder(_ path: String) { try? launcher.openInFinder(path: path) }

    func saveConfig() { try? store.save(config); refresh() }
}
