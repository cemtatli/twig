import Foundation

public struct EnvRule: Codable, Equatable {
    public var file: String
    public var key: String
    public var value: String

    public init(file: String, key: String, value: String) {
        self.file = file; self.key = key; self.value = value
    }
}

public struct RepoSettings: Codable, Equatable {
    public var type: String?
    public var worktreePath: String?
    public var defaultBase: String?
    public var envRules: [EnvRule]?
    public var setupCommands: [String]?

    public init(type: String? = nil, worktreePath: String? = nil, defaultBase: String? = nil,
                envRules: [EnvRule]? = nil, setupCommands: [String]? = nil) {
        self.type = type; self.worktreePath = worktreePath; self.defaultBase = defaultBase
        self.envRules = envRules; self.setupCommands = setupCommands
    }
}

public struct Defaults: Codable, Equatable {
    public var worktreePath: String
    public var defaultBase: String

    public init(worktreePath: String, defaultBase: String) {
        self.worktreePath = worktreePath; self.defaultBase = defaultBase
    }
}

public struct Config: Codable, Equatable {
    public var scanRoots: [String]
    public var scanDepth: Int
    public var manualRepos: [String]
    public var terminalApp: String
    public var editorApp: String
    /// Command run in the terminal after opening a worktree (optional).
    public var terminalStartupCommand: String
    public var repos: [String: RepoSettings]
    public var defaults: Defaults

    public init(scanRoots: [String], scanDepth: Int, manualRepos: [String],
                terminalApp: String, editorApp: String,
                terminalStartupCommand: String = "",
                repos: [String: RepoSettings], defaults: Defaults) {
        self.scanRoots = scanRoots; self.scanDepth = scanDepth; self.manualRepos = manualRepos
        self.terminalApp = terminalApp; self.editorApp = editorApp
        self.terminalStartupCommand = terminalStartupCommand
        self.repos = repos; self.defaults = defaults
    }

    private enum CodingKeys: String, CodingKey {
        case scanRoots, scanDepth, manualRepos, terminalApp, editorApp
        case terminalStartupCommand, repos, defaults
    }

    // Resilient decoding: a hand-edited or older config.json missing keys
    // falls back to defaults instead of failing to load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Config.default
        scanRoots = try c.decodeIfPresent([String].self, forKey: .scanRoots) ?? d.scanRoots
        scanDepth = try c.decodeIfPresent(Int.self, forKey: .scanDepth) ?? d.scanDepth
        manualRepos = try c.decodeIfPresent([String].self, forKey: .manualRepos) ?? []
        terminalApp = try c.decodeIfPresent(String.self, forKey: .terminalApp) ?? d.terminalApp
        editorApp = try c.decodeIfPresent(String.self, forKey: .editorApp) ?? d.editorApp
        terminalStartupCommand = try c.decodeIfPresent(String.self, forKey: .terminalStartupCommand) ?? ""
        repos = try c.decodeIfPresent([String: RepoSettings].self, forKey: .repos) ?? [:]
        defaults = try c.decodeIfPresent(Defaults.self, forKey: .defaults) ?? d.defaults
    }

    public static let `default` = Config(
        scanRoots: ["~/Dev"],
        scanDepth: 3,
        manualRepos: [],
        terminalApp: "Terminal",
        editorApp: "Cursor",
        terminalStartupCommand: "",
        repos: [:],
        defaults: Defaults(worktreePath: "{group}/task/{type}/{taskName}", defaultBase: "main")
    )

    public static func expandTilde(_ path: String) -> String {
        guard path == "~" || path.hasPrefix("~/") else { return path }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == "~" { return home }
        return home + String(path.dropFirst(1))
    }
}
