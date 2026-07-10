import Foundation

/// Bir worktree'nin dev server'ını port üzerinden gözlemler/durdurur. Twig
/// process'i sahiplenmez (terminalde çalışır); lsof ile dinleyen PID'i ve
/// cwd'sini bulup worktree ile eşleştirir. ProcessRunner seam üstünde.
public struct DevServer {
    private let runner: ProcessRunner

    public init(runner: ProcessRunner) { self.runner = runner }

    /// Portu dinleyen (LISTEN) process'in PID'i; yoksa nil.
    public func listeningPID(port: Int) -> Int? {
        guard let r = try? runner.run("lsof",
                ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-Fp"], cwd: nil),
              r.exitCode == 0 else { return nil }
        for line in r.stdout.split(separator: "\n") where line.hasPrefix("p") {
            return Int(line.dropFirst())
        }
        return nil
    }

    /// PID'in çalışma dizini (cwd); yoksa nil.
    public func processCwd(pid: Int) -> String? {
        guard let r = try? runner.run("lsof",
                ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"], cwd: nil),
              r.exitCode == 0 else { return nil }
        for line in r.stdout.split(separator: "\n") where line.hasPrefix("n") {
            return String(line.dropFirst())
        }
        return nil
    }

    /// Port dinleniyor ve dinleyen process'in cwd'si worktree altında mı.
    public func isRunning(port: Int, worktreePath: String) -> Bool {
        guard let pid = listeningPID(port: port), let cwd = processCwd(pid: pid) else { return false }
        return cwd == worktreePath || cwd.hasPrefix(worktreePath + "/")
    }

    /// Portu tutan process'i öldür. Dinleyen yoksa no-op.
    public func stop(port: Int) throws {
        guard let pid = listeningPID(port: port) else { return }
        let r = try runner.run("kill", ["\(pid)"], cwd: nil)
        guard r.exitCode == 0 else {
            throw GitError.command(args: ["kill", "\(pid)"], exitCode: r.exitCode, stderr: r.stderr)
        }
    }
}
