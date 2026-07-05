import Foundation

public struct WorktreeCreator {
    private let config: Config
    private let git: GitService
    private let setup: SetupRunner

    public init(config: Config, git: GitService, setup: SetupRunner) {
        self.config = config; self.git = git; self.setup = setup
    }

    public func settings(for repo: Repo) -> RepoSettings? {
        config.repos["\(repo.group)/\(repo.name)"]
    }

    private func deriveType(_ name: String) -> String {
        if let dash = name.firstIndex(of: "-") {
            return String(name[name.index(after: dash)...])
        }
        return name
    }

    public func placeholderValues(for req: WorktreeRequest) -> [String: String] {
        let type = settings(for: req.repo)?.type ?? deriveType(req.repo.name)
        return [
            "group": req.repo.group,
            "repo": req.repo.name,
            "type": type,
            "taskName": req.taskName,
            "branch": req.branch,
        ]
    }

    public func resolvedPath(for req: WorktreeRequest) throws -> String {
        // base = <root>: repo'nun iki üst dizini (<root>/<group>/<repo>)
        let groupDir = (req.repo.path as NSString).deletingLastPathComponent
        let root = (groupDir as NSString).deletingLastPathComponent
        let template = settings(for: req.repo)?.worktreePath ?? config.defaults.worktreePath
        let resolver = PlaceholderResolver(values: placeholderValues(for: req))
        let relative = try resolver.resolve(template)
        return root + "/" + relative
    }

    @discardableResult
    public func create(_ req: WorktreeRequest, progress: @escaping (String) -> Void) throws -> Worktree {
        let path = try resolvedPath(for: req)
        let resolver = PlaceholderResolver(values: placeholderValues(for: req))

        // New branch off a base: pull the base from origin first so the branch
        // starts from the latest remote tip, not a stale local one. Non-fatal —
        // offline / no remote falls back to the local base.
        var base = req.newBranchBase
        if let b = base {
            progress("git fetch origin \(b)")
            if git.fetch(repoPath: req.repo.path, branch: b),
               git.hasRef(repoPath: req.repo.path, ref: "origin/\(b)") {
                base = "origin/\(b)"
                progress("base updated → origin/\(b)")
            }
        }

        progress("git worktree add \(path)")
        try git.addWorktree(repoPath: req.repo.path, worktreePath: path,
                            branch: req.branch, newBranchBase: base)

        let repoSettings = settings(for: req.repo)
        // Repo-specific rules win; otherwise fall back to the global defaults.
        let rules = repoSettings?.envRules ?? config.defaults.envRules ?? []
        if !rules.isEmpty {
            progress("applying env rules")
            try setup.applyEnvRules(rules, baseRepoPath: req.repo.path,
                                    worktreePath: path, resolver: resolver)
        }
        // Package-manager install (yarn/npm) runs before any custom commands so
        // dependencies exist for them. The dev server itself is long-running and
        // is started in a terminal by the GUI after creation, not here.
        if let pmRaw = repoSettings?.packageManager,
           let pm = PackageManager(rawValue: pmRaw) {
            try setup.runCommands([pm.installCommand], worktreePath: path,
                                  resolver: resolver, progress: progress)
        }

        let commands = repoSettings?.setupCommands ?? config.defaults.setupCommands ?? []
        if !commands.isEmpty {
            try setup.runCommands(commands, worktreePath: path, resolver: resolver, progress: progress)
        }
        return Worktree(path: path, branch: req.branch)
    }
}
