import XCTest
@testable import WorktreeCore

final class ConfigStoreTests: XCTestCase {
    private func tempPath() -> String {
        NSTemporaryDirectory() + "wt-config-\(UUID().uuidString).json"
    }

    func testLoadMissingFileReturnsDefaultAndWritesIt() throws {
        let path = tempPath()
        let store = ConfigStore(path: path)
        let config = try store.load()
        XCTAssertEqual(config, Config.default)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }

    func testLoadJSONMissingKeysFallsBackToDefaults() throws {
        let path = tempPath()
        // An older/hand-edited config missing several keys (incl. the newer
        // terminalStartupCommand) must still load with sensible defaults.
        try """
        { "scanRoots": ["~/work"], "editorApp": "Zed" }
        """.write(toFile: path, atomically: true, encoding: .utf8)
        let config = try ConfigStore(path: path).load()
        XCTAssertEqual(config.scanRoots, ["~/work"])
        XCTAssertEqual(config.editorApp, "Zed")
        XCTAssertEqual(config.scanDepth, Config.default.scanDepth)       // defaulted
        XCTAssertEqual(config.terminalApp, Config.default.terminalApp)   // defaulted
        XCTAssertEqual(config.terminalStartupCommand, "")               // defaulted
        XCTAssertEqual(config.manualRepos, [])
        XCTAssertEqual(config.defaults, Config.default.defaults)
    }

    func testSaveThenLoadRoundTrips() throws {
        let path = tempPath()
        let store = ConfigStore(path: path)
        var config = Config.default
        config.repos["example_repos/example-student"] = RepoSettings(
            type: "student",
            worktreePath: nil,
            defaultBase: "develop",
            envRules: [EnvRule(file: ".env.development", key: "VITE_API_URL",
                               value: "https://student-{taskName}.dev.example.com/api")],
            setupCommands: ["npm install"]
        )
        try store.save(config)
        let loaded = try store.load()
        XCTAssertEqual(loaded, config)
    }

    func testExpandTilde() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertEqual(Config.expandTilde("~/Dev"), home + "/Dev")
        XCTAssertEqual(Config.expandTilde("/abs/path"), "/abs/path")
    }
}
