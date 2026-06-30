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
        var lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
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
            let basePath = baseRepoPath + "/" + rule.file
            let original = (try? String(contentsOfFile: basePath, encoding: .utf8)) ?? ""
            let resolvedValue = try resolver.resolve(rule.value)
            let updated = Self.updateEnvLine(content: original, key: rule.key, value: resolvedValue)
            try updated.write(toFile: worktreePath + "/" + rule.file, atomically: true, encoding: .utf8)
        }
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
