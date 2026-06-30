import Foundation

public enum LaunchError: Error, Equatable {
    case failed(stderr: String)
}

public struct Launcher {
    private let runner: ProcessRunner
    private let fileManager: FileManager

    public init(runner: ProcessRunner, fileManager: FileManager = .default) {
        self.runner = runner
        self.fileManager = fileManager
    }

    private func open(_ args: [String]) throws {
        let result = try runner.run("open", args, cwd: nil)
        guard result.exitCode == 0 else { throw LaunchError.failed(stderr: result.stderr) }
    }

    public func openInEditor(_ editorApp: String, path: String) throws {
        try open(["-a", editorApp, path])
    }

    /// Opens the worktree in the terminal. With a non-empty `startupCommand`,
    /// writes a temp `.command` script that cd's into the worktree, runs the
    /// command, then drops into an interactive shell, and opens that with the
    /// chosen terminal. With no command, just opens the folder in the terminal.
    public func openInTerminal(_ terminalApp: String, path: String,
                               startupCommand: String = "") throws {
        let command = startupCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            try open(["-a", terminalApp, path])
            return
        }
        let script = """
        #!/bin/zsh
        cd \(Self.shellQuote(path))
        \(command)
        exec zsh -i
        """
        let scriptPath = NSTemporaryDirectory() + "wtgui-launch-\(UInt(bitPattern: path.hashValue)).command"
        try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
        try open(["-a", terminalApp, scriptPath])
    }

    public func openInFinder(path: String) throws {
        try open([path])
    }

    static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
