import Foundation

public enum LaunchError: Error, Equatable {
    case failed(stderr: String)
}

public struct Launcher {
    private let runner: ProcessRunner

    public init(runner: ProcessRunner) { self.runner = runner }

    private func open(_ args: [String]) throws {
        let result = try runner.run("open", args, cwd: nil)
        guard result.exitCode == 0 else { throw LaunchError.failed(stderr: result.stderr) }
    }

    public func openInEditor(_ editorApp: String, path: String) throws {
        try open(["-a", editorApp, path])
    }

    public func openInTerminal(_ terminalApp: String, path: String) throws {
        try open(["-a", terminalApp, path])
    }

    public func openInFinder(path: String) throws {
        try open([path])
    }
}
