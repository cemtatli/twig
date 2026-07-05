import Foundation
@testable import TwigCore

final class FakeProcessRunner: ProcessRunner {
    struct Call: Equatable {
        let executable: String
        let args: [String]
        let cwd: String?
    }

    private(set) var calls: [Call] = []
    var results: [ProcessResult] = []
    var defaultResult = ProcessResult(exitCode: 0, stdout: "", stderr: "")
    var stubbedError: Error?

    func run(_ executable: String, _ args: [String], cwd: String?) throws -> ProcessResult {
        calls.append(Call(executable: executable, args: args, cwd: cwd))
        if let stubbedError { throw stubbedError }
        if results.isEmpty { return defaultResult }
        return results.removeFirst()
    }
}
