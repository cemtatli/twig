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

    /// True if the worktree has any uncommitted changes (tracked or
    /// untracked). `git status --porcelain` prints one line per dirty path
    /// and nothing when clean.
    public func isDirty(worktreePath: String) throws -> Bool {
        let out = try git(["-C", worktreePath, "status", "--porcelain"])
        return !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    /// Pushes a branch to origin and sets upstream (`git push -u origin <branch>`).
    /// Non-fatal: returns false when there is no remote or the push fails (e.g.
    /// offline), so creation can proceed. `stderr` carries the reason for logging.
    @discardableResult
    public func push(repoPath: String, branch: String) -> (ok: Bool, stderr: String) {
        guard let r = try? runner.run("git", ["-C", repoPath, "push", "-u", "origin", branch], cwd: nil)
        else { return (false, "git push failed to run") }
        return (r.exitCode == 0, r.stderr)
    }

    /// True if a ref (e.g. `origin/master`) resolves in the repo.
    public func hasRef(repoPath: String, ref: String) -> Bool {
        guard let r = try? runner.run("git", ["-C", repoPath, "rev-parse", "--verify", "--quiet", ref], cwd: nil)
        else { return false }
        return r.exitCode == 0
    }

    public func removeWorktree(repoPath: String, worktreePath: String, force: Bool = false) throws {
        var args = ["-C", repoPath, "worktree", "remove", worktreePath]
        if force { args.append("--force") }
        try git(args)
    }

    public func deleteBranch(repoPath: String, branch: String) throws {
        try git(["-C", repoPath, "branch", "-D", branch])
    }

    /// Drops registrations for worktrees whose directories no longer exist.
    public func prune(repoPath: String) throws {
        try git(["-C", repoPath, "worktree", "prune"])
    }

    /// A branch's position relative to `base`. Non-throwing: any git error or
    /// unresolvable base yields `.unknown` so callers treat it as unsafe.
    /// Resolves `origin/<base>` first, falls back to the local `<base>` ref.
    public func mergeStatus(repoPath: String, branch: String, base: String) -> SyncStatus {
        func resolves(_ ref: String) -> Bool {
            let r = try? runner.run("git", ["-C", repoPath, "rev-parse", "--verify", "--quiet", ref], cwd: nil)
            return r?.exitCode == 0
        }
        let resolvedBase: String
        if resolves("origin/\(base)") { resolvedBase = "origin/\(base)" }
        else if resolves(base) { resolvedBase = base }
        else { return .unknown }

        // Fully contained in base → merged (implies 0 ahead).
        if let anc = try? runner.run("git",
                ["-C", repoPath, "merge-base", "--is-ancestor", branch, resolvedBase], cwd: nil),
           anc.exitCode == 0 {
            return .merged
        }

        // "<behind>\t<ahead>" — left side is base-only commits, right is branch-only.
        guard let rev = try? runner.run("git",
                ["-C", repoPath, "rev-list", "--left-right", "--count", "\(resolvedBase)...\(branch)"], cwd: nil),
              rev.exitCode == 0 else { return .unknown }
        let parts = rev.stdout.split(whereSeparator: { $0 == "\t" || $0 == " " || $0 == "\n" })
            .compactMap { Int($0) }
        guard parts.count == 2 else { return .unknown }
        let behind = parts[0], ahead = parts[1]
        switch (ahead, behind) {
        case (0, 0):           return .even
        case let (a, 0):       return .ahead(a)
        case let (0, b):       return .behind(b)
        case let (a, b):       return .diverged(ahead: a, behind: b)
        }
    }
}
