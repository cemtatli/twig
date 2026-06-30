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

        progress("git worktree add \(path)")
        try git.addWorktree(repoPath: req.repo.path, worktreePath: path,
                            branch: req.branch, newBranchBase: req.newBranchBase)

        let repoSettings = settings(for: req.repo)
        if let rules = repoSettings?.envRules, !rules.isEmpty {
            progress("applying env rules")
            try setup.applyEnvRules(rules, baseRepoPath: req.repo.path,
                                    worktreePath: path, resolver: resolver)
        }
        if let commands = repoSettings?.setupCommands, !commands.isEmpty {
            try setup.runCommands(commands, worktreePath: path, resolver: resolver, progress: progress)
        }
        return Worktree(path: path, branch: req.branch)
    }
}
