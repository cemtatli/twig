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

/// A worktree branch's position relative to its base branch.
public enum SyncStatus: Equatable, Hashable {
    case merged                              // branch fully contained in base → safe to delete
    case ahead(Int)                          // N commits ahead of base
    case behind(Int)                         // M commits behind base
    case diverged(ahead: Int, behind: Int)
    case even                                // level with base
    case unknown                             // couldn't compute (no base ref, detached, error)
}

public struct Worktree: Equatable, Identifiable, Hashable {
    public var path: String
    public var branch: String
    public var isDirty: Bool
    public var sync: SyncStatus
    /// The repo's primary worktree (branch == base). Never merged-badged or deletable.
    public var isPrimary: Bool
    public var id: String { path }

    public init(path: String, branch: String, isDirty: Bool = false,
                sync: SyncStatus = .unknown, isPrimary: Bool = false) {
        self.path = path; self.branch = branch; self.isDirty = isDirty
        self.sync = sync; self.isPrimary = isPrimary
    }

    /// Merged into base, no uncommitted work, and not the base worktree — the
    /// bulk "clean merged" action removes exactly these.
    public var isSafeToClean: Bool { sync == .merged && !isDirty && !isPrimary }
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
