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
    @Published var toasts: [Toast] = []
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

    private var refreshTask: Task<Void, Never>?

    func refresh() {
        // Scan + per-repo `git worktree list` run off the main thread so the
        // menubar popup never freezes. Ardışık çağrılar coalesce edilir
        // (~150ms); ağır per-worktree durum (isDirty/mergeStatus) burada değil,
        // loadStatus(for:) ile yalnız seçili repo için lazy hesaplanır.
        let config = self.config
        isRefreshing = true
        refreshTask?.cancel()
        refreshTask = Task.detached { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }
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
                map[repo.path] = all.filter { $0.path != repo.path && fm.fileExists(atPath: $0.path) }
            }
            if Task.isCancelled { return }
            let ordered = AppState.applyOrder(scanned, order: config.repoOrder)
            await MainActor.run {
                self?.repos = ordered
                self?.worktreesByRepo = map
                self?.isRefreshing = false
            }
        }
    }

    /// Seçili repo için ağır per-worktree durumu (isDirty + mergeStatus +
    /// isPrimary) lazily hesapla — tüm repolar için her refresh'te git
    /// çalıştırmamak için. Repo seçilince/refresh'te çağrılır.
    func loadStatus(for repo: Repo) {
        let base = config.repos["\(repo.group)/\(repo.name)"]?.defaultBase ?? config.defaults.defaultBase
        let path = repo.path
        Task.detached { [weak self] in
            guard let current = await self?.worktreesByRepo[path], !current.isEmpty else { return }
            let git = GitService(runner: SystemProcessRunner())
            let enriched = current.map { wt -> Worktree in
                var wt = wt
                wt.isDirty = (try? git.isDirty(worktreePath: wt.path)) ?? false
                wt.isPrimary = (wt.branch == base)
                wt.sync = wt.isPrimary ? .unknown
                    : git.mergeStatus(repoPath: path, branch: wt.branch, base: base)
                return wt
            }
            await MainActor.run { self?.worktreesByRepo[path] = enriched }
        }
    }

    // MARK: — Toast

    private var toastDismiss: Task<Void, Never>?

    func toast(_ message: String, kind: ToastKind = .success) {
        let t = Toast(message: message, kind: kind)
        toasts = [t]   // tek toast — stack yok
        toastDismiss?.cancel()
        let secs: Double = kind == .error ? 4.0 : 2.5
        toastDismiss = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(secs * 1_000_000_000))
            if Task.isCancelled { return }
            await MainActor.run { self?.toasts.removeAll { $0.id == t.id } }
        }
    }

    func dismissToast(_ id: UUID) { toasts.removeAll { $0.id == id } }

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

    func repoSettings(for repo: Repo) -> RepoSettings {
        config.repos["\(repo.group)/\(repo.name)"] ?? RepoSettings()
    }

    /// Sheet'ten gelen ayarları yaz. Boş alanlar zaten nil normalize edilmiş
    /// gelir; tamamen boşsa anahtarı kaldır. saveConfig refresh tetikler.
    func saveRepoSettings(_ settings: RepoSettings, for repo: Repo) {
        let key = "\(repo.group)/\(repo.name)"
        if settings == RepoSettings() { config.repos[key] = nil }
        else { config.repos[key] = settings }
        saveConfig()
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
                    self?.toast("\(req.taskName) \(self?.t(.toastCreated) ?? "")")
                    self?.refresh()
                }
            } catch {
                await MainActor.run {
                    self?.toast(friendlyMessage(error), kind: .error)
                    self?.refresh()
                }
            }
        }
    }

    func removeWorktree(repo: Repo, worktree: Worktree, deleteBranch: Bool, force: Bool = false) {
        do {
            try git.removeWorktree(repoPath: repo.path, worktreePath: worktree.path, force: force)
            if deleteBranch { try? git.deleteBranch(repoPath: repo.path, branch: worktree.branch) }
            let verb = force ? t(.toastForceRemoved) : t(.toastRemoved)
            toast("\(worktree.branch) \(verb)")
            refresh()
        } catch { toast(friendlyMessage(error), kind: .error) }
    }

    /// Worktree'ler ki merge edilmiş + temiz + primary değil — hepsini
    /// worktree+branch olarak sil. Dirty merged olanlar atlanır (kayıp riski).
    func cleanMergedWorktrees(repo: Repo) {
        let safe = (worktreesByRepo[repo.path] ?? []).filter { $0.isSafeToClean }
        for wt in safe {
            try? git.removeWorktree(repoPath: repo.path, worktreePath: wt.path)  // temiz → force yok
            try? git.deleteBranch(repoPath: repo.path, branch: wt.branch)
        }
        if !safe.isEmpty { toast("\(safe.count) \(t(.toastCleaned))") }
        refresh()
    }

    /// Repo'da merge edilmiş+temiz (silinebilir) worktree sayısı — buton aktifliği için.
    func mergedCleanCount(for repo: Repo) -> Int {
        (worktreesByRepo[repo.path] ?? []).filter { $0.isSafeToClean }.count
    }

    /// Merge edilmiş ama dirty olduğu için atlanacak worktree sayısı — onay notu için.
    func mergedDirtyCount(for repo: Repo) -> Int {
        (worktreesByRepo[repo.path] ?? []).filter { $0.sync == .merged && $0.isDirty && !$0.isPrimary }.count
    }

    /// Stale (klasörü silinmiş) worktree kayıtlarını açıkça temizle.
    func pruneStale(repo: Repo) {
        try? git.prune(repoPath: repo.path)
        refresh()
    }

    // MARK: — Favoriler

    func isFavorite(_ repo: Repo) -> Bool {
        config.favoriteRepos.contains("\(repo.group)/\(repo.name)")
    }

    /// Favori ekle/çıkar. saveConfig yerine yalnız kaydet + @Published config
    /// mutasyonu ile sidebar'ı tazele (full refresh flicker'ı olmasın).
    func toggleFavorite(_ repo: Repo) {
        let key = "\(repo.group)/\(repo.name)"
        let added: Bool
        if let i = config.favoriteRepos.firstIndex(of: key) { config.favoriteRepos.remove(at: i); added = false }
        else { config.favoriteRepos.append(key); added = true }
        try? store.save(config)
        toast("\(repo.name) \(added ? t(.toastFavAdded) : t(.toastFavRemoved))", kind: .info)
    }

    /// Sidebar section katlama — favoriler için "★favorites", diğerleri grup adı.
    static let favoritesSectionKey = "★favorites"

    func isSectionCollapsed(_ key: String) -> Bool {
        config.collapsedSections.contains(key)
    }

    func toggleSection(_ key: String) {
        if let i = config.collapsedSections.firstIndex(of: key) { config.collapsedSections.remove(at: i) }
        else { config.collapsedSections.append(key) }
        try? store.save(config)   // @Published config mutasyonu sidebar'ı tazeler
    }

    /// Favori repolar, config sırasıyla; artık taranmayan anahtarlar atlanır.
    var favoriteRepos: [Repo] {
        config.favoriteRepos.compactMap { key in
            repos.first { "\($0.group)/\($0.name)" == key }
        }
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
