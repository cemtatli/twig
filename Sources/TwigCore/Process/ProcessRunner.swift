import Foundation

public struct ProcessResult: Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public protocol ProcessRunner {
    /// `executable` PATH'ten çözülür; `cwd` verilirse o dizinde çalışır.
    func run(_ executable: String, _ args: [String], cwd: String?) throws -> ProcessResult
}

public extension ProcessRunner {
    func run(_ executable: String, _ args: [String]) throws -> ProcessResult {
        try run(executable, args, cwd: nil)
    }
}

public struct SystemProcessRunner: ProcessRunner {
    public init() {}

    public func run(_ executable: String, _ args: [String], cwd: String?) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + args
        if let cwd { process.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        process.environment = Self.environmentWithCommonPaths()

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()

        // Drain both pipes concurrently — reading one to EOF before the other
        // deadlocks when the undrained pipe fills its OS buffer (~64KB).
        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "ProcessRunner.drain", attributes: .concurrent)
        queue.async(group: group) { outData = outPipe.fileHandleForReading.readDataToEndOfFile() }
        queue.async(group: group) { errData = errPipe.fileHandleForReading.readDataToEndOfFile() }
        group.wait()
        process.waitUntilExit()

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self)
        )
    }

    /// A GUI app launched from Finder gets a minimal PATH that omits Homebrew,
    /// /usr/local/bin, etc., so `cursor`/`npm` wouldn't be found. Prepend the
    /// common tool locations so commands resolve the same as in a terminal.
    static func environmentWithCommonPaths() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        let extra = [
            "/opt/homebrew/bin", "/opt/homebrew/sbin",
            "/usr/local/bin",
            "\(home)/.local/bin", "\(home)/bin",
        ]
        let existing = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let merged = (extra + existing.split(separator: ":").map(String.init))
            .reduce(into: [String]()) { acc, p in if !acc.contains(p) { acc.append(p) } }
        env["PATH"] = merged.joined(separator: ":")
        return env
    }
}
