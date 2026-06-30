import Foundation

public struct Repo: Equatable, Identifiable, Hashable {
    public var path: String
    public var name: String
    public var group: String
    public var id: String { path }

    public init(path: String, name: String, group: String) {
        self.path = path; self.name = name; self.group = group
    }
}

public struct Worktree: Equatable, Identifiable, Hashable {
    public var path: String
    public var branch: String
    public var id: String { path }

    public init(path: String, branch: String) {
        self.path = path; self.branch = branch
    }
}

public struct WorktreeRequest {
    public var repo: Repo
    public var branch: String
    public var taskName: String
    public var newBranchBase: String?

    public init(repo: Repo, branch: String, taskName: String, newBranchBase: String?) {
        self.repo = repo; self.branch = branch
        self.taskName = taskName; self.newBranchBase = newBranchBase
    }
}
