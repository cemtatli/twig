import Foundation
import SwiftUI
import AppKit
import TwigCore

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
            let ordered = AppState.applyOrder(scanned, order: config.repoOrder)
            await MainActor.run {
                self?.repos = ordered
                self?.worktreesByRepo = map
                self?.isRefreshing = false
            }
        }
    }

    /// Order scanned repos by the saved `repoOrder`, then make the result
    /// group-contiguous so the flat array matches the sectioned display order
    /// (keeps the 1-9 shortcuts aligned with what's on screen). Repos missing
    /// from `repoOrder` keep scan order, after the known ones.
    nonisolated private static func applyOrder(_ scanned: [Repo], order: [String]) -> [Repo] {
        func key(_ r: Repo) -> String { "\(r.group)/\(r.name)" }
        let sorted = scanned.enumerated().sorted { a, b in
            let ia = order.firstIndex(of: key(a.element)) ?? Int.max
            let ib = order.firstIndex(of: key(b.element)) ?? Int.max
            return ia != ib ? ia < ib : a.offset < b.offset
        }.map(\.element)
        var groupsSeen: [String] = []
        var buckets: [String: [Repo]] = [:]
        for r in sorted {
            if buckets[r.group] == nil { groupsSeen.append(r.group) }
            buckets[r.group, default: []].append(r)
        }
        return groupsSeen.flatMap { buckets[$0]! }
    }

    /// Drag-to-reorder: move `path` to `target` position within its group.
    /// Persists the new order quietly (no re-scan/flicker) so it survives refresh
    /// and relaunch; 1-9 follow it.
    func moveRepo(path: String, inGroup group: String, toGroupIndex target: Int) {
        var groupRepos = repos.filter { $0.group == group }
        guard let from = groupRepos.firstIndex(where: { $0.path == path }) else { return }
        let clamped = max(0, min(target, groupRepos.count - 1))
        guard clamped != from else { return }
        let moved = groupRepos.remove(at: from)
        groupRepos.insert(moved, at: min(clamped, groupRepos.count))
        // Rebuild group-contiguous so the flat array matches sectioned display
        // order (keeps 1-9 aligned with what's on screen).
        var groupsSeen: [String] = []
        var buckets: [String: [Repo]] = [:]
        for r in repos {
            if buckets[r.group] == nil { groupsSeen.append(r.group) }
            buckets[r.group, default: []].append(r)
        }
        buckets[group] = groupRepos
        let reordered = groupsSeen.flatMap { buckets[$0]! }
        repos = reordered
        config.repoOrder = reordered.map { "\($0.group)/\($0.name)" }
        try? store.save(config)
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

    /// config.json'ı seçili editörde aç (env/komut kurallarını elle düzenlemek
    /// için). Editör CLI'si dosyayı doğrudan açar; yoksa `open -a` fallback.
    func openConfigFile() { try? launcher.openInEditor(config.editorApp, path: ConfigStore.defaultPath) }

    func saveConfig() { try? store.save(config); refresh() }
}
