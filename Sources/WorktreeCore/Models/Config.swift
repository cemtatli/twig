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
    public var repos: [String: RepoSettings]
    public var defaults: Defaults

    public init(scanRoots: [String], scanDepth: Int, manualRepos: [String],
                terminalApp: String, editorApp: String,
                repos: [String: RepoSettings], defaults: Defaults) {
        self.scanRoots = scanRoots; self.scanDepth = scanDepth; self.manualRepos = manualRepos
        self.terminalApp = terminalApp; self.editorApp = editorApp
        self.repos = repos; self.defaults = defaults
    }

    public static let `default` = Config(
        scanRoots: ["~/Dev"],
        scanDepth: 3,
        manualRepos: [],
        terminalApp: "Terminal",
        editorApp: "Cursor",
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
