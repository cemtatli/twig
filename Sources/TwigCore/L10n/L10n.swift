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
    case openConfigButton
    // Favoriler + worktree temizlik
    case favoritesSection, addFavorite, removeFavorite
    case forceDelete, dirtyDeleteWarning, cleanMerged, pruneStale
    case syncMerged
    // Toast fiil/son ekleri (isim/sayı önüne gelir)
    case toastCreated, toastRemoved, toastForceRemoved, toastCleaned
    case toastFavAdded, toastFavRemoved
    // Repo config sheet
    case repoConfigTitle, cfgType, cfgBase, cfgWorktreePath, cfgEnvRules
    case cfgSetupCommands, cfgAddRule, cfgAddCommand, cfgFile, cfgKey, cfgValue
    case cfgDone, defaultsTitle, repoConfigHelp, cfgInsert, cfgUnknownToken, cfgCustom
    case cfgDevPort, devOpenBrowser, devStop, devRunning, toastDevStopped
    case cfgPushOnCreate, cfgPushOnCreateCaption
    // Onboarding
    case onbWelcomeTitle, onbWelcomeBody, onbRootsTitle, onbRootsBody, onbAppsTitle
    case onbNext, onbBack, onbFinish, onbSkip, onbRerun
    case launchAtLoginTitle, launchAtLoginCaption
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
            .openConfigButton: "Open config.json",
            .favoritesSection: "Favorites", .addFavorite: "Add to favorites",
            .removeFavorite: "Remove from favorites",
            .forceDelete: "Force delete", .dirtyDeleteWarning: "Uncommitted changes",
            .cleanMerged: "Clean merged", .pruneStale: "Prune stale entries",
            .syncMerged: "merged",
            .toastCreated: "created", .toastRemoved: "deleted",
            .toastForceRemoved: "force-deleted", .toastCleaned: "worktrees cleaned",
            .toastFavAdded: "added to favorites", .toastFavRemoved: "removed from favorites",
            .repoConfigTitle: "Repo Settings", .cfgType: "Type", .cfgBase: "Base branch",
            .cfgWorktreePath: "Worktree path", .cfgEnvRules: "Env rules",
            .cfgSetupCommands: "Setup commands", .cfgAddRule: "Add rule",
            .cfgAddCommand: "Add command", .cfgFile: "file", .cfgKey: "key", .cfgValue: "value",
            .cfgDone: "Done", .defaultsTitle: "Defaults (all repos)",
            .repoConfigHelp: "Empty fields fall back to defaults.",
            .cfgInsert: "Insert:", .cfgUnknownToken: "Unknown token", .cfgCustom: "Custom\u{2026}",
            .cfgDevPort: "Dev port", .devOpenBrowser: "Open in browser", .devStop: "Stop dev server",
            .devRunning: "running", .toastDevStopped: "stopped",
            .cfgPushOnCreate: "Push branch on create",
            .cfgPushOnCreateCaption: "Push the new branch to origin so it appears on the remote.",
            .onbWelcomeTitle: "Welcome to Twig",
            .onbWelcomeBody: "Create and manage git worktrees across your local repos. Let\u{2019}s set up a few things.",
            .onbRootsTitle: "Where are your repos?",
            .onbRootsBody: "Pick folders to scan for git repositories.",
            .onbAppsTitle: "Editor & Terminal",
            .onbNext: "Next", .onbBack: "Back", .onbFinish: "Finish", .onbSkip: "Skip",
            .onbRerun: "Run onboarding again",
            .launchAtLoginTitle: "Launch at login",
            .launchAtLoginCaption: "Start Twig automatically when you log in.",
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
            .openConfigButton: "config.json\u{2019}ı aç",
            .favoritesSection: "Favoriler", .addFavorite: "Favlara ekle",
            .removeFavorite: "Favlardan çıkar",
            .forceDelete: "Zorla sil", .dirtyDeleteWarning: "Kaydedilmemiş değişiklik",
            .cleanMerged: "Merged temizle", .pruneStale: "Stale kayıtları temizle",
            .syncMerged: "merged",
            .toastCreated: "oluşturuldu", .toastRemoved: "silindi",
            .toastForceRemoved: "zorla silindi", .toastCleaned: "worktree temizlendi",
            .toastFavAdded: "favlara eklendi", .toastFavRemoved: "favlardan çıkarıldı",
            .repoConfigTitle: "Repo Ayarları", .cfgType: "Tip", .cfgBase: "Base branch",
            .cfgWorktreePath: "Worktree yolu", .cfgEnvRules: "Env kuralları",
            .cfgSetupCommands: "Setup komutları", .cfgAddRule: "Kural ekle",
            .cfgAddCommand: "Komut ekle", .cfgFile: "dosya", .cfgKey: "anahtar", .cfgValue: "değer",
            .cfgDone: "Bitti", .defaultsTitle: "Defaults (tüm repolar)",
            .repoConfigHelp: "Boş alanlar defaults'a düşer.",
            .cfgInsert: "Ekle:", .cfgUnknownToken: "Bilinmeyen token", .cfgCustom: "Özel\u{2026}",
            .cfgDevPort: "Dev port", .devOpenBrowser: "Tarayıcıda aç", .devStop: "Dev server'ı durdur",
            .devRunning: "çalışıyor", .toastDevStopped: "durduruldu",
            .cfgPushOnCreate: "Oluşturunca branch'i push et",
            .cfgPushOnCreateCaption: "Yeni branch'i origin'e push eder, remote'da görünür olsun.",
            .onbWelcomeTitle: "Twig\u{2019}e hoş geldin",
            .onbWelcomeBody: "Yerel repolarında git worktree oluştur ve yönet. Birkaç şeyi ayarlayalım.",
            .onbRootsTitle: "Repoların nerede?",
            .onbRootsBody: "Git repolarının taranacağı klasörleri seç.",
            .onbAppsTitle: "Editör & Terminal",
            .onbNext: "İleri", .onbBack: "Geri", .onbFinish: "Bitir", .onbSkip: "Atla",
            .onbRerun: "Onboarding\u{2019}i tekrar çalıştır",
            .launchAtLoginTitle: "Açılışta başlat",
            .launchAtLoginCaption: "Oturum açınca Twig otomatik başlasın.",
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
