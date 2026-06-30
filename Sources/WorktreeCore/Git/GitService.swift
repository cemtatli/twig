import Foundation

public enum GitError: Error, Equatable {
    case command(args: [String], exitCode: Int32, stderr: String)
}

public struct GitService {
    private let runner: ProcessRunner

    public init(runner: ProcessRunner) { self.runner = runner }

    @discardableResult
    private func git(_ args: [String]) throws -> String {
        let result = try runner.run("git", args, cwd: nil)
        guard result.exitCode == 0 else {
            throw GitError.command(args: args, exitCode: result.exitCode, stderr: result.stderr)
        }
        return result.stdout
    }

    public func branches(repoPath: String) throws -> [String] {
        let out = try git(["-C", repoPath, "branch", "--format=%(refname:short)"])
        return out.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    public func worktrees(repoPath: String) throws -> [Worktree] {
        let out = try git(["-C", repoPath, "worktree", "list", "--porcelain"])
        var result: [Worktree] = []
        var path: String?
        var branch = "(detached)"
        func flush() {
            if let path { result.append(Worktree(path: path, branch: branch)) }
            path = nil; branch = "(detached)"
        }
        for line in out.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("worktree ") {
                flush()
                path = String(line.dropFirst("worktree ".count))
            } else if line.hasPrefix("branch refs/heads/") {
                branch = String(line.dropFirst("branch refs/heads/".count))
            }
        }
        flush()
        return result
    }

    public func addWorktree(repoPath: String, worktreePath: String,
                            branch: String, newBranchBase: String?) throws {
        var args = ["-C", repoPath, "worktree", "add"]
        if let base = newBranchBase {
            args += ["-b", branch, worktreePath, base]
        } else {
            args += [worktreePath, branch]
        }
        try git(args)
    }

    /// Fetches a single branch from origin. Non-fatal: returns false when there
    /// is no remote or the fetch fails (e.g. offline), so creation can proceed.
    @discardableResult
    public func fetch(repoPath: String, branch: String) -> Bool {
        guard let r = try? runner.run("git", ["-C", repoPath, "fetch", "origin", branch], cwd: nil)
        else { return false }
        return r.exitCode == 0
    }

    /// True if a ref (e.g. `origin/master`) resolves in the repo.
    public func hasRef(repoPath: String, ref: String) -> Bool {
        guard let r = try? runner.run("git", ["-C", repoPath, "rev-parse", "--verify", "--quiet", ref], cwd: nil)
        else { return false }
        return r.exitCode == 0
    }

    public func removeWorktree(repoPath: String, worktreePath: String) throws {
        try git(["-C", repoPath, "worktree", "remove", worktreePath])
    }

    public func deleteBranch(repoPath: String, branch: String) throws {
        try git(["-C", repoPath, "branch", "-D", branch])
    }

    /// Drops registrations for worktrees whose directories no longer exist.
    public func prune(repoPath: String) throws {
        try git(["-C", repoPath, "worktree", "prune"])
    }
}
