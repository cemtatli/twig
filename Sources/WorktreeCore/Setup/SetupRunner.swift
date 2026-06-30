import Foundation

public enum SetupError: Error, Equatable {
    case command(command: String, exitCode: Int32, stderr: String)
}

public struct SetupRunner {
    private let runner: ProcessRunner
    private let fileManager: FileManager

    public init(runner: ProcessRunner, fileManager: FileManager = .default) {
        self.runner = runner; self.fileManager = fileManager
    }

    public static func updateEnvLine(content: String, key: String, value: String) -> String {
        let hadTrailingNewline = content.hasSuffix("\n")
        var lines = content.isEmpty ? [] : content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if hadTrailingNewline, lines.last == "" { lines.removeLast() }

        var replaced = false
        for i in lines.indices {
            if lines[i].hasPrefix(key + "=") {
                lines[i] = "\(key)=\(value)"
                replaced = true
            }
        }
        if !replaced { lines.append("\(key)=\(value)") }
        return lines.joined(separator: "\n") + "\n"
    }

    public func applyEnvRules(_ rules: [EnvRule], baseRepoPath: String,
                             worktreePath: String, resolver: PlaceholderResolver) throws {
        for rule in rules {
            let original = try baseContent(baseRepoPath: baseRepoPath, file: rule.file)
            let resolvedValue = try resolver.resolve(rule.value)
            let updated = Self.updateEnvLine(content: original, key: rule.key, value: resolvedValue)
            try Data(updated.utf8).write(to: URL(fileURLWithPath: worktreePath + "/" + rule.file),
                                         options: .atomic)
        }
    }

    /// Reads the base template for an env file. Prefers the real file, then
    /// falls back to `<file>.example` (e.g. `.env.development.example`) since
    /// the real env file is usually git-ignored and absent in a fresh worktree.
    /// Empty string if neither exists.
    private func baseContent(baseRepoPath: String, file: String) throws -> String {
        for candidate in [file, file + ".example"] {
            let path = baseRepoPath + "/" + candidate
            if fileManager.fileExists(atPath: path) {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                return String(data: data, encoding: .utf8) ?? ""
            }
        }
        return ""
    }

    public func runCommands(_ commands: [String], worktreePath: String,
                           resolver: PlaceholderResolver, progress: (String) -> Void) throws {
        for command in commands {
            let resolved = try resolver.resolve(command)
            progress("$ \(resolved)")
            let result = try runner.run("sh", ["-c", resolved], cwd: worktreePath)
            if !result.stdout.isEmpty { progress(result.stdout) }
            guard result.exitCode == 0 else {
                throw SetupError.command(command: resolved, exitCode: result.exitCode, stderr: result.stderr)
            }
        }
    }
}
