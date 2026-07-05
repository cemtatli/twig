import Foundation

public enum Language: String, Codable, CaseIterable {
    case en, tr
    public var label: String { self == .en ? "English" : "Türkçe" }
    /// Resolve a stored raw value to a Language, defaulting to English.
    public static func from(_ raw: String) -> Language { Language(rawValue: raw) ?? .en }
}

public enum L10nKey: String, CaseIterable {
    // Sidebar / rail
    case sidebarRepos, addRepo, settings, quit, refresh, new, newWorktreeHelp
    case sidebarShow, sidebarHide, sidebarLabel
    // Repo detail + worktree rows
    case noWorktreesYet, createFirstWorktree, deletePrompt, worktreeWord, branchPlus
    case cancel, finder, delete, noRepositories, loading, pickFolderHint
    case statusClean, statusDirty, moveUp, moveDown
    // New worktree form
    case newWorktreeTitle, existingBranch, newBranchTab, branch, newBranchName
    case branchPlaceholder, baseBranch, taskNameFolder, taskPlaceholder, working, close, create
    // Settings
    case settingsTitle, repoSourcesTitle, repoSourcesCaption, noSourcesYet
    case kindRoot, kindRepo, addFromFinder
    case scanDepthTitle, scanDepthCaption, terminalTitle, terminalCaption
    case editorTitle, editorCaption, packageManagerTitle, packageManagerCaption
    case noReposFound, startupCommandTitle, startupCommandCaption, startupPlaceholder
    case editConfigHint, pmNone, remove, languageTitle, languageCaption
    // Add-source panel
    case addPanelPrompt, addPanelMessage
    // Shortcuts (Settings bölümü)
    case shortcutsTitle, shortcutSelectRepo, shortcutCycleRepos, shortcutCloseEsc
    // Brand
    case tagline
}

public enum L10n {
    public static func string(_ key: L10nKey, language: Language) -> String {
        table[language]?[key] ?? table[.en]?[key] ?? key.rawValue
    }

    public static func worktreeCount(_ n: Int, language: Language) -> String {
        switch language {
        case .en: return n == 1 ? "1 worktree" : "\(n) worktrees"
        case .tr: return "\(n) worktree"
        }
    }

    private static let table: [Language: [L10nKey: String]] = [
        .en: [
            .sidebarRepos: "Repositories", .addRepo: "Add repo", .settings: "Settings",
            .quit: "Quit", .refresh: "Refresh", .new: "New", .newWorktreeHelp: "New worktree",
            .sidebarShow: "Show sidebar", .sidebarHide: "Hide sidebar", .sidebarLabel: "Sidebar",
            .noWorktreesYet: "No worktrees yet",
            .createFirstWorktree: "Create your first with \u{201C}New\u{201D}",
            .deletePrompt: "Delete?", .worktreeWord: "Worktree", .branchPlus: "+ Branch",
            .cancel: "Cancel", .finder: "Finder", .delete: "Delete",
            .noRepositories: "No repositories", .loading: "Loading\u{2026}",
            .pickFolderHint: "Pick a folder via \u{201C}Add repo\u{201D} on the left",
            .statusClean: "No uncommitted changes",
            .statusDirty: "Uncommitted changes",
            .moveUp: "Move Up", .moveDown: "Move Down",
            .newWorktreeTitle: "New Worktree", .existingBranch: "Existing branch",
            .newBranchTab: "New branch", .branch: "Branch", .newBranchName: "New branch name",
            .branchPlaceholder: "e.g. feat/booking", .baseBranch: "Base branch (to copy)",
            .taskNameFolder: "Task name (folder)", .taskPlaceholder: "e.g. booking",
            .working: "Working\u{2026}", .close: "Close", .create: "Create",
            .settingsTitle: "Settings", .repoSourcesTitle: "Repository Sources",
            .repoSourcesCaption: "Pick a folder: one with .git is a single repo, others become scanned roots.",
            .noSourcesYet: "No sources yet", .kindRoot: "root", .kindRepo: "repo",
            .addFromFinder: "Add from Finder", .scanDepthTitle: "Scan Depth",
            .scanDepthCaption: "How many levels under a root to search",
            .terminalTitle: "Terminal", .terminalCaption: "Which terminal opens the worktree",
            .editorTitle: "Editor", .editorCaption: "Which editor opens the worktree",
            .packageManagerTitle: "Package Manager",
            .packageManagerCaption: "On selected repos, install runs after creation, then the dev server opens in a terminal.",
            .noReposFound: "No repositories found",
            .startupCommandTitle: "Terminal Startup Command",
            .startupCommandCaption: "Runs in the worktree when the terminal opens (optional). Save with Enter.",
            .startupPlaceholder: "e.g. npm run dev",
            .editConfigHint: "Edit config.json by hand for env/command rules:",
            .pmNone: "None", .remove: "Remove",
            .languageTitle: "Language", .languageCaption: "Interface language",
            .addPanelPrompt: "Add",
            .addPanelMessage: "Pick a repo folder or a root folder containing repos",
            .shortcutsTitle: "Shortcuts",
            .shortcutSelectRepo: "Select repo",
            .shortcutCycleRepos: "Cycle repos",
            .shortcutCloseEsc: "Cancel / close pane",
            .tagline: "Spin up a worktree.",
        ],
        .tr: [
            .sidebarRepos: "Depolar", .addRepo: "Repo ekle", .settings: "Ayarlar",
            .quit: "Çıkış", .refresh: "Yenile", .new: "Yeni", .newWorktreeHelp: "Yeni worktree",
            .sidebarShow: "Kenar çubuğunu göster", .sidebarHide: "Kenar çubuğunu gizle",
            .sidebarLabel: "Kenar çubuğu",
            .noWorktreesYet: "Henüz worktree yok",
            .createFirstWorktree: "\u{201C}Yeni\u{201D} ile ilk worktree\u{2019}yi oluştur",
            .deletePrompt: "Sil?", .worktreeWord: "Worktree", .branchPlus: "+ Branch",
            .cancel: "Vazgeç", .finder: "Finder", .delete: "Sil",
            .noRepositories: "Repo yok", .loading: "Yükleniyor\u{2026}",
            .pickFolderHint: "Soldaki \u{201C}Repo ekle\u{201D} ile bir klasör seç",
            .statusClean: "Kaydedilmemiş değişiklik yok",
            .statusDirty: "Kaydedilmemiş değişiklik var",
            .moveUp: "Yukarı Taşı", .moveDown: "Aşağı Taşı",
            .newWorktreeTitle: "Yeni Worktree", .existingBranch: "Var olan branch",
            .newBranchTab: "Yeni branch", .branch: "Branch", .newBranchName: "Yeni branch adı",
            .branchPlaceholder: "ör. feat/randevu", .baseBranch: "Base branch (kopyalanacak)",
            .taskNameFolder: "Task adı (klasör)", .taskPlaceholder: "ör. randevu",
            .working: "Çalışıyor\u{2026}", .close: "Kapat", .create: "Oluştur",
            .settingsTitle: "Ayarlar", .repoSourcesTitle: "Repo Kaynakları",
            .repoSourcesCaption: "Klasör seç: içinde .git olan tek repo, diğerleri taranan kök olur.",
            .noSourcesYet: "Henüz kaynak yok", .kindRoot: "kök", .kindRepo: "repo",
            .addFromFinder: "Finder\u{2019}dan Ekle", .scanDepthTitle: "Tarama Derinliği",
            .scanDepthCaption: "Kök altında kaç seviye derine bakılsın",
            .terminalTitle: "Terminal", .terminalCaption: "Worktree hangi terminalde açılsın",
            .editorTitle: "Editör", .editorCaption: "Worktree hangi editörde açılsın",
            .packageManagerTitle: "Paket Yöneticisi",
            .packageManagerCaption: "Seçili repolarda worktree oluşunca install çalışır, sonra dev sunucusu terminalde açılır.",
            .noReposFound: "Repo bulunamadı",
            .startupCommandTitle: "Terminal Başlangıç Komutu",
            .startupCommandCaption: "Terminal açılınca worktree\u{2019}de çalışır (opsiyonel). Enter ile kaydet.",
            .startupPlaceholder: "ör. npm run dev",
            .editConfigHint: "Env/komut kuralları için config.json\u{2019}ı elle düzenle:",
            .pmNone: "Yok", .remove: "Kaldır",
            .languageTitle: "Dil", .languageCaption: "Arayüz dili",
            .addPanelPrompt: "Ekle",
            .addPanelMessage: "Bir repo klasörü ya da repoları içeren bir kök klasör seç",
            .shortcutsTitle: "Kısayollar",
            .shortcutSelectRepo: "Repo seç",
            .shortcutCycleRepos: "Repolar arasında gez",
            .shortcutCloseEsc: "Vazgeç / paneli kapat",
            .tagline: "Bir worktree başlat.",
        ],
    ]
}
