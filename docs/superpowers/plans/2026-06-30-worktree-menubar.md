# Worktree Menubar Tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS menubar uygulaması — seçilen repolardan `git worktree` ile branch/task bazlı izole çalışma klasörleri açar, env şablonu + kurulum komutlarını otomatik çalıştırır, Cursor/Terminal/Finder'da açar.

**Architecture:** Swift Package Manager paketi. Tüm mantık `WorktreeCore` kütüphane target'ında (saf, XCTest ile birim test edilir); `git`, kabuk komutları ve `open` çağrıları `ProcessRunner` protokolü arkasında soyutlanır ve testte `FakeProcessRunner` ile sahtelenir. UI ise `WorktreeGUI` executable target'ında SwiftUI `MenuBarExtra` ile yazılır (manuel doğrulanır).

**Tech Stack:** Swift 5.9, SwiftUI (`MenuBarExtra`, macOS 13+), Foundation `Process`, XCTest, Swift Package Manager.

## Global Constraints

- Hedef platform: macOS 13+ (`MenuBarExtra` gereği). `Package.swift`'te `platforms: [.macOS(.v13)]`.
- Dış bağımlılık yok — yalnızca Foundation/SwiftUI ve `git` binary'si.
- Tüm süreç çağrıları `ProcessRunner` protokolünden geçer; `WorktreeCore` içinde doğrudan `Process()` kullanılmaz (testlenebilirlik için).
- `git` çağrıları `git -C <repoPath> ...` biçiminde yapılır (cwd'ye bağımlı olmamak için).
- Komut/`open` çalıştırma `/usr/bin/env <executable> <args...>` üzerinden yapılır (PATH'ten çözmek için).
- Ayar dosyası: `~/.config/worktree-gui/config.json` (insan-okunur, elle düzenlenebilir).
- Worktree yol şablonu repo dizin yapısının `<root>/<group>/<repo>` olduğunu varsayar (ör. `~/Dev/example_repos/example-admin`); şablon `<root>` dizinine göre çözülür.
- Placeholder'lar: `{group} {repo} {type} {taskName} {branch}`.
- Commit mesajları şu satırla biter:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

## File Structure

```
Package.swift
Sources/
  WorktreeCore/
    Process/ProcessRunner.swift        # ProcessResult, ProcessRunner, SystemProcessRunner
    Models/Config.swift                # Config, RepoSettings, EnvRule, Defaults (Codable)
    Models/Repo.swift                  # Repo, Worktree, WorktreeRequest
    Config/ConfigStore.swift           # JSON load/save, ~ expansion, default config
    Resolve/PlaceholderResolver.swift  # {token} çözümleme
    Scan/RepoScanner.swift             # scanRoots + manualRepos -> [Repo]
    Git/GitService.swift               # worktree add/list/remove, branch listeleme/silme
    Setup/SetupRunner.swift            # envRules uygulama + setupCommands çalıştırma
    Launch/Launcher.swift              # Cursor/Terminal/Finder açma (open)
    Create/WorktreeCreator.swift       # orkestrasyon: path çöz -> add -> setup
  WorktreeGUI/
    WorktreeGUIApp.swift               # @main App + MenuBarExtra + AppDelegate (accessory)
    AppState.swift                     # ObservableObject: config, repolar, aksiyonlar
    Views/MenuContentView.swift        # repo + worktree listesi, aksiyon menüsü
    Views/NewWorktreeView.swift        # yeni worktree formu
    Views/SettingsView.swift           # ayar düzenleme
Tests/
  WorktreeCoreTests/
    FakeProcessRunner.swift
    ConfigStoreTests.swift
    PlaceholderResolverTests.swift
    RepoScannerTests.swift
    GitServiceTests.swift
    SetupRunnerTests.swift
    LauncherTests.swift
    WorktreeCreatorTests.swift
```

---

### Task 1: Paket iskeleti + ProcessRunner soyutlaması

**Files:**
- Create: `Package.swift`
- Create: `Sources/WorktreeCore/Process/ProcessRunner.swift`
- Create: `Sources/WorktreeGUI/WorktreeGUIApp.swift` (geçici placeholder, Task 9'da değişir)
- Test: `Tests/WorktreeCoreTests/FakeProcessRunner.swift`
- Test: `Tests/WorktreeCoreTests/ProcessRunnerTests.swift`

**Interfaces:**
- Produces:
  - `struct ProcessResult: Equatable { let exitCode: Int32; let stdout: String; let stderr: String }`
  - `protocol ProcessRunner { func run(_ executable: String, _ args: [String], cwd: String?) throws -> ProcessResult }`
  - `struct SystemProcessRunner: ProcessRunner`
  - `final class FakeProcessRunner: ProcessRunner` (test) — `var calls: [(executable: String, args: [String], cwd: String?)]`, `var results: [ProcessResult]` (sırayla döner), `var defaultResult`, `var stubbedError: Error?`.

- [ ] **Step 1: `Package.swift`'i oluştur**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WorktreeGUI",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "WorktreeCore"),
        .executableTarget(
            name: "WorktreeGUI",
            dependencies: ["WorktreeCore"]
        ),
        .testTarget(
            name: "WorktreeCoreTests",
            dependencies: ["WorktreeCore"]
        ),
    ]
)
```

- [ ] **Step 2: Geçici GUI giriş noktası oluştur** (derlemenin executable target için geçmesi adına)

`Sources/WorktreeGUI/WorktreeGUIApp.swift`:

```swift
import SwiftUI

@main
struct WorktreeGUIApp: App {
    var body: some Scene {
        MenuBarExtra("Worktrees", systemImage: "arrow.triangle.branch") {
            Text("Hazırlanıyor…")
        }
    }
}
```

- [ ] **Step 3: `ProcessRunner.swift`'i oluştur**

`Sources/WorktreeCore/Process/ProcessRunner.swift`:

```swift
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

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self)
        )
    }
}
```

- [ ] **Step 4: `FakeProcessRunner`'ı (test yardımcısı) oluştur**

`Tests/WorktreeCoreTests/FakeProcessRunner.swift`:

```swift
import Foundation
@testable import WorktreeCore

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
```

- [ ] **Step 5: Başarısızlık testi yaz**

`Tests/WorktreeCoreTests/ProcessRunnerTests.swift`:

```swift
import XCTest
@testable import WorktreeCore

final class ProcessRunnerTests: XCTestCase {
    func testSystemRunnerRunsEcho() throws {
        let runner = SystemProcessRunner()
        let result = try runner.run("echo", ["hello"], cwd: nil)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, "hello\n")
    }

    func testFakeRecordsCallsAndReturnsResults() throws {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 0, stdout: "ok", stderr: "")]
        let r = try fake.run("git", ["status"], cwd: "/tmp")
        XCTAssertEqual(r.stdout, "ok")
        XCTAssertEqual(fake.calls, [.init(executable: "git", args: ["status"], cwd: "/tmp")])
    }
}
```

- [ ] **Step 6: Test çalıştır — başarısız olduğunu doğrula**

Run: `swift test --filter ProcessRunnerTests`
Expected: FAIL — `WorktreeCore` derlenmiyor / tipler bulunamıyor ("cannot find 'SystemProcessRunner'").

- [ ] **Step 7: Derle ve testi geçir**

Run: `swift test --filter ProcessRunnerTests`
Expected: PASS (2 test).

- [ ] **Step 8: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "feat: SPM scaffold + ProcessRunner abstraction

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Config modelleri + ConfigStore

**Files:**
- Create: `Sources/WorktreeCore/Models/Config.swift`
- Create: `Sources/WorktreeCore/Config/ConfigStore.swift`
- Test: `Tests/WorktreeCoreTests/ConfigStoreTests.swift`

**Interfaces:**
- Consumes: yok.
- Produces:
  - `struct Config: Codable, Equatable` alanları: `scanRoots: [String]`, `scanDepth: Int`, `manualRepos: [String]`, `terminalApp: String`, `editorApp: String`, `repos: [String: RepoSettings]`, `defaults: Defaults`.
  - `struct RepoSettings: Codable, Equatable` alanları (hepsi opsiyonel): `type: String?`, `worktreePath: String?`, `defaultBase: String?`, `envRules: [EnvRule]?`, `setupCommands: [String]?`.
  - `struct EnvRule: Codable, Equatable` alanları: `file: String`, `key: String`, `value: String`.
  - `struct Defaults: Codable, Equatable` alanları: `worktreePath: String`, `defaultBase: String`.
  - `static Config.default` — makul varsayılan (`scanRoots: ["~/Dev"]`, `scanDepth: 3`, `terminalApp: "Terminal"`, `editorApp: "Cursor"`, `defaults.worktreePath: "{group}/task/{type}/{taskName}"`, `defaults.defaultBase: "main"`).
  - `struct ConfigStore` — `init(path: String)`, `func load() throws -> Config` (dosya yoksa `Config.default` döner ve yazar), `func save(_ config: Config) throws`, `static var defaultPath: String` (`~/.config/worktree-gui/config.json`, expand edilmiş).
  - `static func expandTilde(_ path: String) -> String` (Config.swift veya ConfigStore içinde public).

- [ ] **Step 1: Round-trip ve default testlerini yaz**

`Tests/WorktreeCoreTests/ConfigStoreTests.swift`:

```swift
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
```

- [ ] **Step 2: Test çalıştır — başarısız olduğunu doğrula**

Run: `swift test --filter ConfigStoreTests`
Expected: FAIL — `Config`, `ConfigStore` bulunamıyor.

- [ ] **Step 3: `Config.swift`'i oluştur**

`Sources/WorktreeCore/Models/Config.swift`:

```swift
import Foundation

public struct EnvRule: Codable, Equatable {
    public var file: String
    public var key: String
    public var value: String

    public init(file: String, key: String, value: String) {
        self.file = file; self.key = key; self.value = value
    }
}

public struct RepoSettings: Codable, Equatable {
    public var type: String?
    public var worktreePath: String?
    public var defaultBase: String?
    public var envRules: [EnvRule]?
    public var setupCommands: [String]?

    public init(type: String? = nil, worktreePath: String? = nil, defaultBase: String? = nil,
                envRules: [EnvRule]? = nil, setupCommands: [String]? = nil) {
        self.type = type; self.worktreePath = worktreePath; self.defaultBase = defaultBase
        self.envRules = envRules; self.setupCommands = setupCommands
    }
}

public struct Defaults: Codable, Equatable {
    public var worktreePath: String
    public var defaultBase: String

    public init(worktreePath: String, defaultBase: String) {
        self.worktreePath = worktreePath; self.defaultBase = defaultBase
    }
}

public struct Config: Codable, Equatable {
    public var scanRoots: [String]
    public var scanDepth: Int
    public var manualRepos: [String]
    public var terminalApp: String
    public var editorApp: String
    public var repos: [String: RepoSettings]
    public var defaults: Defaults

    public init(scanRoots: [String], scanDepth: Int, manualRepos: [String],
                terminalApp: String, editorApp: String,
                repos: [String: RepoSettings], defaults: Defaults) {
        self.scanRoots = scanRoots; self.scanDepth = scanDepth; self.manualRepos = manualRepos
        self.terminalApp = terminalApp; self.editorApp = editorApp
        self.repos = repos; self.defaults = defaults
    }

    public static let `default` = Config(
        scanRoots: ["~/Dev"],
        scanDepth: 3,
        manualRepos: [],
        terminalApp: "Terminal",
        editorApp: "Cursor",
        repos: [:],
        defaults: Defaults(worktreePath: "{group}/task/{type}/{taskName}", defaultBase: "main")
    )

    public static func expandTilde(_ path: String) -> String {
        guard path == "~" || path.hasPrefix("~/") else { return path }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == "~" { return home }
        return home + String(path.dropFirst(1))
    }
}
```

- [ ] **Step 4: `ConfigStore.swift`'i oluştur**

`Sources/WorktreeCore/Config/ConfigStore.swift`:

```swift
import Foundation

public struct ConfigStore {
    private let path: String

    public init(path: String) { self.path = path }

    public static var defaultPath: String {
        Config.expandTilde("~/.config/worktree-gui/config.json")
    }

    public func load() throws -> Config {
        if !FileManager.default.fileExists(atPath: path) {
            try save(Config.default)
            return Config.default
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(Config.self, from: data)
    }

    public func save(_ config: Config) throws {
        let dir = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: URL(fileURLWithPath: path))
    }
}
```

- [ ] **Step 5: Test çalıştır — geçtiğini doğrula**

Run: `swift test --filter ConfigStoreTests`
Expected: PASS (3 test).

- [ ] **Step 6: Commit**

```bash
git add Sources/WorktreeCore/Models/Config.swift Sources/WorktreeCore/Config Tests/WorktreeCoreTests/ConfigStoreTests.swift
git commit -m "feat: config model and JSON store

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: PlaceholderResolver

**Files:**
- Create: `Sources/WorktreeCore/Resolve/PlaceholderResolver.swift`
- Test: `Tests/WorktreeCoreTests/PlaceholderResolverTests.swift`

**Interfaces:**
- Consumes: yok.
- Produces:
  - `enum PlaceholderError: Error, Equatable { case unresolved(String) }`
  - `struct PlaceholderResolver { let values: [String: String]; init(values: [String: String]); func resolve(_ template: String) throws -> String }`
  - `resolve`, `{token}` desenlerini `values[token]` ile değiştirir; karşılığı olmayan token için `PlaceholderError.unresolved(token)` fırlatır.

- [ ] **Step 1: Testleri yaz**

`Tests/WorktreeCoreTests/PlaceholderResolverTests.swift`:

```swift
import XCTest
@testable import WorktreeCore

final class PlaceholderResolverTests: XCTestCase {
    func testSubstitutesKnownTokens() throws {
        let r = PlaceholderResolver(values: ["group": "example_repos", "type": "student", "taskName": "randevu"])
        XCTAssertEqual(try r.resolve("{group}/task/{type}/{taskName}"),
                       "example_repos/task/student/randevu")
    }

    func testSubstitutesInArbitraryString() throws {
        let r = PlaceholderResolver(values: ["taskName": "randevu"])
        XCTAssertEqual(try r.resolve("https://student-{taskName}.dev.example.com/api"),
                       "https://student-randevu.dev.example.com/api")
    }

    func testUnknownTokenThrows() {
        let r = PlaceholderResolver(values: ["taskName": "x"])
        XCTAssertThrowsError(try r.resolve("{group}/{taskName}")) { error in
            XCTAssertEqual(error as? PlaceholderError, .unresolved("group"))
        }
    }

    func testNoTokensReturnsInput() throws {
        let r = PlaceholderResolver(values: [:])
        XCTAssertEqual(try r.resolve("plain"), "plain")
    }
}
```

- [ ] **Step 2: Test çalıştır — başarısız olduğunu doğrula**

Run: `swift test --filter PlaceholderResolverTests`
Expected: FAIL — `PlaceholderResolver` bulunamıyor.

- [ ] **Step 3: `PlaceholderResolver.swift`'i oluştur**

`Sources/WorktreeCore/Resolve/PlaceholderResolver.swift`:

```swift
import Foundation

public enum PlaceholderError: Error, Equatable {
    case unresolved(String)
}

public struct PlaceholderResolver {
    private let values: [String: String]

    public init(values: [String: String]) { self.values = values }

    public func resolve(_ template: String) throws -> String {
        var result = ""
        var rest = Substring(template)
        while let open = rest.firstIndex(of: "{") {
            result += rest[rest.startIndex..<open]
            guard let close = rest[open...].firstIndex(of: "}") else {
                result += rest[open...]
                return result
            }
            let token = String(rest[rest.index(after: open)..<close])
            guard let value = values[token] else { throw PlaceholderError.unresolved(token) }
            result += value
            rest = rest[rest.index(after: close)...]
        }
        result += rest
        return result
    }
}
```

- [ ] **Step 4: Test çalıştır — geçtiğini doğrula**

Run: `swift test --filter PlaceholderResolverTests`
Expected: PASS (4 test).

- [ ] **Step 5: Commit**

```bash
git add Sources/WorktreeCore/Resolve Tests/WorktreeCoreTests/PlaceholderResolverTests.swift
git commit -m "feat: placeholder resolver

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Repo modeli + RepoScanner

**Files:**
- Create: `Sources/WorktreeCore/Models/Repo.swift`
- Create: `Sources/WorktreeCore/Scan/RepoScanner.swift`
- Test: `Tests/WorktreeCoreTests/RepoScannerTests.swift`

**Interfaces:**
- Consumes: yok.
- Produces:
  - `struct Repo: Equatable, Identifiable, Hashable` alanları: `path: String` (mutlak), `name: String` (klasör adı), `group: String` (üst klasör adı). `var id: String { path }`.
  - `struct Worktree: Equatable, Identifiable, Hashable` alanları: `path: String`, `branch: String`. `var id: String { path }`. (Bu task'ta sadece tanımlanır; Task 5 kullanır.)
  - `struct WorktreeRequest` alanları: `repo: Repo`, `branch: String`, `taskName: String`, `newBranchBase: String?`. (Bu task'ta tanımlanır; Task 8 kullanır.)
  - `struct RepoScanner { init(fileManager: FileManager = .default); func scan(roots: [String], depth: Int, manual: [String]) -> [Repo] }`
  - Bir dizin, içinde `.git` (dosya veya klasör) varsa repo'dur; bulununca o dalda daha derine inilmez. Gizli klasörler (`.` ile başlayan) atlanır. `manual` repoları sonuca eklenir (mutlak yola expand edilir), `path`'e göre tekilleştirilir. Sonuç `path`'e göre sıralı.

- [ ] **Step 1: Testleri yaz**

`Tests/WorktreeCoreTests/RepoScannerTests.swift`:

```swift
import XCTest
@testable import WorktreeCore

final class RepoScannerTests: XCTestCase {
    private var root: String!

    override func setUpWithError() throws {
        root = NSTemporaryDirectory() + "wt-scan-\(UUID().uuidString)"
        // <root>/example_repos/example-admin/.git  (repo)
        // <root>/example_repos/task/admin/randevu/.git (gizli .worktrees yerine derin git -> bulunmalı ama derinlik sınırı içinde)
        // <root>/.hidden/repo/.git (atlanmalı)
        // <root>/plain  (repo değil)
        try makeRepo("example_repos/example-admin")
        try makeDir("example_repos/plainfolder")
        try makeRepo(".hidden/repo")
        try makeDir("plain")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: root)
    }

    private func makeDir(_ rel: String) throws {
        try FileManager.default.createDirectory(atPath: root + "/" + rel, withIntermediateDirectories: true)
    }
    private func makeRepo(_ rel: String) throws {
        try makeDir(rel + "/.git")
    }

    func testFindsGitRepoAndDerivesGroup() {
        let repos = RepoScanner().scan(roots: [root], depth: 3, manual: [])
        XCTAssertEqual(repos.map(\.name), ["example-admin"])
        XCTAssertEqual(repos.first?.group, "example_repos")
        XCTAssertEqual(repos.first?.path, root + "/example_repos/example-admin")
    }

    func testSkipsHiddenDirectories() {
        let repos = RepoScanner().scan(roots: [root], depth: 3, manual: [])
        XCTAssertFalse(repos.contains { $0.path.contains("/.hidden/") })
    }

    func testMergesManualReposDeduplicated() throws {
        let manual = root + "/example_repos/example-admin"   // zaten taranıyor -> tek kalmalı
        let extra = root + "/standalone"
        try makeRepo("standalone")
        let repos = RepoScanner().scan(roots: [root], depth: 3, manual: [manual, extra])
        let paths = repos.map(\.path)
        XCTAssertEqual(paths.filter { $0 == manual }.count, 1)
        XCTAssertTrue(paths.contains(extra))
    }
}
```

- [ ] **Step 2: Test çalıştır — başarısız olduğunu doğrula**

Run: `swift test --filter RepoScannerTests`
Expected: FAIL — `RepoScanner`, `Repo` bulunamıyor.

- [ ] **Step 3: `Repo.swift`'i oluştur**

`Sources/WorktreeCore/Models/Repo.swift`:

```swift
import Foundation

public struct Repo: Equatable, Identifiable, Hashable {
    public var path: String
    public var name: String
    public var group: String
    public var id: String { path }

    public init(path: String, name: String, group: String) {
        self.path = path; self.name = name; self.group = group
    }
}

public struct Worktree: Equatable, Identifiable, Hashable {
    public var path: String
    public var branch: String
    public var id: String { path }

    public init(path: String, branch: String) {
        self.path = path; self.branch = branch
    }
}

public struct WorktreeRequest {
    public var repo: Repo
    public var branch: String
    public var taskName: String
    public var newBranchBase: String?

    public init(repo: Repo, branch: String, taskName: String, newBranchBase: String?) {
        self.repo = repo; self.branch = branch
        self.taskName = taskName; self.newBranchBase = newBranchBase
    }
}
```

- [ ] **Step 4: `RepoScanner.swift`'i oluştur**

`Sources/WorktreeCore/Scan/RepoScanner.swift`:

```swift
import Foundation

public struct RepoScanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func scan(roots: [String], depth: Int, manual: [String]) -> [Repo] {
        var found: [String: Repo] = [:]
        for root in roots {
            let expanded = Config.expandTilde(root)
            walk(dir: expanded, depthLeft: depth, into: &found)
        }
        for m in manual {
            let path = Config.expandTilde(m)
            if found[path] == nil, isRepo(path) {
                found[path] = makeRepo(path)
            }
        }
        return found.values.sorted { $0.path < $1.path }
    }

    private func walk(dir: String, depthLeft: Int, into found: inout [String: Repo]) {
        if isRepo(dir) {
            found[dir] = makeRepo(dir)
            return
        }
        guard depthLeft > 0 else { return }
        guard let entries = try? fileManager.contentsOfDirectory(atPath: dir) else { return }
        for entry in entries where !entry.hasPrefix(".") {
            let child = dir + "/" + entry
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: child, isDirectory: &isDir), isDir.boolValue else { continue }
            walk(dir: child, depthLeft: depthLeft - 1, into: &found)
        }
    }

    private func isRepo(_ dir: String) -> Bool {
        fileManager.fileExists(atPath: dir + "/.git")
    }

    private func makeRepo(_ path: String) -> Repo {
        let name = (path as NSString).lastPathComponent
        let group = ((path as NSString).deletingLastPathComponent as NSString).lastPathComponent
        return Repo(path: path, name: name, group: group)
    }
}
```

- [ ] **Step 5: Test çalıştır — geçtiğini doğrula**

Run: `swift test --filter RepoScannerTests`
Expected: PASS (3 test).

- [ ] **Step 6: Commit**

```bash
git add Sources/WorktreeCore/Models/Repo.swift Sources/WorktreeCore/Scan Tests/WorktreeCoreTests/RepoScannerTests.swift
git commit -m "feat: repo model and filesystem scanner

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: GitService

**Files:**
- Create: `Sources/WorktreeCore/Git/GitService.swift`
- Test: `Tests/WorktreeCoreTests/GitServiceTests.swift`

**Interfaces:**
- Consumes: `ProcessRunner`, `ProcessResult` (Task 1); `Worktree` (Task 4).
- Produces:
  - `enum GitError: Error, Equatable { case command(args: [String], exitCode: Int32, stderr: String) }`
  - `struct GitService { init(runner: ProcessRunner) }`
  - `func branches(repoPath: String) throws -> [String]`
  - `func worktrees(repoPath: String) throws -> [Worktree]`
  - `func addWorktree(repoPath: String, worktreePath: String, branch: String, newBranchBase: String?) throws`
  - `func removeWorktree(repoPath: String, worktreePath: String) throws`
  - `func deleteBranch(repoPath: String, branch: String) throws`
  - Sıfırdan farklı çıkış kodu `GitError.command` fırlatır. `worktrees`, `git worktree list --porcelain` çıktısını ayrıştırır (detached için branch = `(detached)`).

- [ ] **Step 1: Testleri yaz**

`Tests/WorktreeCoreTests/GitServiceTests.swift`:

```swift
import XCTest
@testable import WorktreeCore

final class GitServiceTests: XCTestCase {
    func testAddExistingBranchBuildsArgs() throws {
        let fake = FakeProcessRunner()
        try GitService(runner: fake).addWorktree(
            repoPath: "/repo", worktreePath: "/wt/x", branch: "feature", newBranchBase: nil)
        XCTAssertEqual(fake.calls.first?.executable, "git")
        XCTAssertEqual(fake.calls.first?.args,
                       ["-C", "/repo", "worktree", "add", "/wt/x", "feature"])
    }

    func testAddNewBranchBuildsArgs() throws {
        let fake = FakeProcessRunner()
        try GitService(runner: fake).addWorktree(
            repoPath: "/repo", worktreePath: "/wt/x", branch: "feature", newBranchBase: "develop")
        XCTAssertEqual(fake.calls.first?.args,
                       ["-C", "/repo", "worktree", "add", "-b", "feature", "/wt/x", "develop"])
    }

    func testNonZeroExitThrows() {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 128, stdout: "", stderr: "fatal: boom")]
        XCTAssertThrowsError(try GitService(runner: fake).removeWorktree(
            repoPath: "/repo", worktreePath: "/wt/x")) { error in
            XCTAssertEqual(error as? GitError,
                           .command(args: ["-C", "/repo", "worktree", "remove", "/wt/x"],
                                    exitCode: 128, stderr: "fatal: boom"))
        }
    }

    func testParsesWorktreeListPorcelain() throws {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 0, stdout: """
        worktree /repo
        HEAD abc123
        branch refs/heads/main

        worktree /wt/randevu
        HEAD def456
        branch refs/heads/randevu

        worktree /wt/detached
        HEAD ff0011
        detached

        """, stderr: "")]
        let result = try GitService(runner: fake).worktrees(repoPath: "/repo")
        XCTAssertEqual(result, [
            Worktree(path: "/repo", branch: "main"),
            Worktree(path: "/wt/randevu", branch: "randevu"),
            Worktree(path: "/wt/detached", branch: "(detached)"),
        ])
    }

    func testParsesBranches() throws {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 0, stdout: "main\ndevelop\nfeature\n", stderr: "")]
        XCTAssertEqual(try GitService(runner: fake).branches(repoPath: "/repo"),
                       ["main", "develop", "feature"])
    }
}
```

- [ ] **Step 2: Test çalıştır — başarısız olduğunu doğrula**

Run: `swift test --filter GitServiceTests`
Expected: FAIL — `GitService` bulunamıyor.

- [ ] **Step 3: `GitService.swift`'i oluştur**

`Sources/WorktreeCore/Git/GitService.swift`:

```swift
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

    public func removeWorktree(repoPath: String, worktreePath: String) throws {
        try git(["-C", repoPath, "worktree", "remove", worktreePath])
    }

    public func deleteBranch(repoPath: String, branch: String) throws {
        try git(["-C", repoPath, "branch", "-D", branch])
    }
}
```

- [ ] **Step 4: Test çalıştır — geçtiğini doğrula**

Run: `swift test --filter GitServiceTests`
Expected: PASS (5 test).

- [ ] **Step 5: Commit**

```bash
git add Sources/WorktreeCore/Git Tests/WorktreeCoreTests/GitServiceTests.swift
git commit -m "feat: git worktree service

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: SetupRunner

**Files:**
- Create: `Sources/WorktreeCore/Setup/SetupRunner.swift`
- Test: `Tests/WorktreeCoreTests/SetupRunnerTests.swift`

**Interfaces:**
- Consumes: `ProcessRunner`, `ProcessResult` (Task 1); `EnvRule` (Task 2); `PlaceholderResolver`, `PlaceholderError` (Task 3).
- Produces:
  - `enum SetupError: Error, Equatable { case command(command: String, exitCode: Int32, stderr: String) }`
  - `struct SetupRunner { init(runner: ProcessRunner, fileManager: FileManager = .default) }`
  - `static func updateEnvLine(content: String, key: String, value: String) -> String` — `key=` ile başlayan satırı `key=value` yapar; yoksa sona ekler; diğer satırlar korunur.
  - `func applyEnvRules(_ rules: [EnvRule], baseRepoPath: String, worktreePath: String, resolver: PlaceholderResolver) throws` — her kural için base'deki dosyayı (varsa) oku, yoksa boş başla; `value`'yu resolver'dan geçir; `updateEnvLine` uygula; worktree'deki dosyaya yaz.
  - `func runCommands(_ commands: [String], worktreePath: String, resolver: PlaceholderResolver, progress: (String) -> Void) throws` — her komutu resolver'dan geçir, `sh -c` ile `worktreePath`'te çalıştır; sıfırdan farklı çıkış `SetupError.command` fırlatır.

- [ ] **Step 1: Testleri yaz**

`Tests/WorktreeCoreTests/SetupRunnerTests.swift`:

```swift
import XCTest
@testable import WorktreeCore

final class SetupRunnerTests: XCTestCase {
    func testUpdateEnvLineReplacesOnlyTargetKey() {
        let content = "APP_ENV=development\nVITE_API_URL=https://old.example.com/api\nFOO=bar\n"
        let updated = SetupRunner.updateEnvLine(
            content: content, key: "VITE_API_URL", value: "https://student-randevu.dev.example.com/api")
        XCTAssertEqual(updated, """
        APP_ENV=development
        VITE_API_URL=https://student-randevu.dev.example.com/api
        FOO=bar

        """)
    }

    func testUpdateEnvLineAppendsWhenMissing() {
        let updated = SetupRunner.updateEnvLine(content: "FOO=bar\n", key: "VITE_API_URL", value: "x")
        XCTAssertEqual(updated, "FOO=bar\nVITE_API_URL=x\n")
    }

    func testApplyEnvRulesWritesResolvedFile() throws {
        let base = NSTemporaryDirectory() + "base-\(UUID().uuidString)"
        let wt = NSTemporaryDirectory() + "wt-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: base, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: wt, withIntermediateDirectories: true)
        try "VITE_API_URL=https://old/api\n".write(toFile: base + "/.env.development", atomically: true, encoding: .utf8)

        let runner = SetupRunner(runner: FakeProcessRunner())
        let resolver = PlaceholderResolver(values: ["taskName": "randevu"])
        try runner.applyEnvRules(
            [EnvRule(file: ".env.development", key: "VITE_API_URL",
                     value: "https://student-{taskName}.dev.example.com/api")],
            baseRepoPath: base, worktreePath: wt, resolver: resolver)

        let written = try String(contentsOfFile: wt + "/.env.development", encoding: .utf8)
        XCTAssertEqual(written, "VITE_API_URL=https://student-randevu.dev.example.com/api\n")
    }

    func testRunCommandsExecutesInWorktreeViaShell() throws {
        let fake = FakeProcessRunner()
        let runner = SetupRunner(runner: fake)
        try runner.runCommands(["npm install"], worktreePath: "/wt/x",
                               resolver: PlaceholderResolver(values: [:]), progress: { _ in })
        XCTAssertEqual(fake.calls.first?.executable, "sh")
        XCTAssertEqual(fake.calls.first?.args, ["-c", "npm install"])
        XCTAssertEqual(fake.calls.first?.cwd, "/wt/x")
    }

    func testRunCommandsThrowsOnFailure() {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 1, stdout: "", stderr: "boom")]
        let runner = SetupRunner(runner: fake)
        XCTAssertThrowsError(try runner.runCommands(["bad"], worktreePath: "/wt/x",
            resolver: PlaceholderResolver(values: [:]), progress: { _ in })) { error in
            XCTAssertEqual(error as? SetupError, .command(command: "bad", exitCode: 1, stderr: "boom"))
        }
    }
}
```

- [ ] **Step 2: Test çalıştır — başarısız olduğunu doğrula**

Run: `swift test --filter SetupRunnerTests`
Expected: FAIL — `SetupRunner` bulunamıyor.

- [ ] **Step 3: `SetupRunner.swift`'i oluştur**

`Sources/WorktreeCore/Setup/SetupRunner.swift`:

```swift
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
```

- [ ] **Step 4: Test çalıştır — geçtiğini doğrula**

Run: `swift test --filter SetupRunnerTests`
Expected: PASS (5 test).

- [ ] **Step 5: Commit**

```bash
git add Sources/WorktreeCore/Setup Tests/WorktreeCoreTests/SetupRunnerTests.swift
git commit -m "feat: setup runner for env templating and commands

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Launcher

**Files:**
- Create: `Sources/WorktreeCore/Launch/Launcher.swift`
- Test: `Tests/WorktreeCoreTests/LauncherTests.swift`

**Interfaces:**
- Consumes: `ProcessRunner` (Task 1).
- Produces:
  - `struct Launcher { init(runner: ProcessRunner) }`
  - `func openInEditor(_ editorApp: String, path: String) throws` → `open -a <editorApp> <path>`
  - `func openInTerminal(_ terminalApp: String, path: String) throws` → `open -a <terminalApp> <path>`
  - `func openInFinder(path: String) throws` → `open <path>`
  - Her biri `open`'ın sıfırdan farklı çıkışında `GitError`'a benzer şekilde değil; basitçe `LaunchError.failed(stderr:)` fırlatır.

- [ ] **Step 1: Testleri yaz**

`Tests/WorktreeCoreTests/LauncherTests.swift`:

```swift
import XCTest
@testable import WorktreeCore

final class LauncherTests: XCTestCase {
    func testOpenInEditor() throws {
        let fake = FakeProcessRunner()
        try Launcher(runner: fake).openInEditor("Cursor", path: "/wt/x")
        XCTAssertEqual(fake.calls.first?.executable, "open")
        XCTAssertEqual(fake.calls.first?.args, ["-a", "Cursor", "/wt/x"])
    }

    func testOpenInTerminal() throws {
        let fake = FakeProcessRunner()
        try Launcher(runner: fake).openInTerminal("iTerm", path: "/wt/x")
        XCTAssertEqual(fake.calls.first?.args, ["-a", "iTerm", "/wt/x"])
    }

    func testOpenInFinder() throws {
        let fake = FakeProcessRunner()
        try Launcher(runner: fake).openInFinder(path: "/wt/x")
        XCTAssertEqual(fake.calls.first?.args, ["/wt/x"])
    }

    func testFailureThrows() {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 1, stdout: "", stderr: "no app")]
        XCTAssertThrowsError(try Launcher(runner: fake).openInFinder(path: "/x")) { error in
            XCTAssertEqual(error as? LaunchError, .failed(stderr: "no app"))
        }
    }
}
```

- [ ] **Step 2: Test çalıştır — başarısız olduğunu doğrula**

Run: `swift test --filter LauncherTests`
Expected: FAIL — `Launcher` bulunamıyor.

- [ ] **Step 3: `Launcher.swift`'i oluştur**

`Sources/WorktreeCore/Launch/Launcher.swift`:

```swift
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
```

- [ ] **Step 4: Test çalıştır — geçtiğini doğrula**

Run: `swift test --filter LauncherTests`
Expected: PASS (4 test).

- [ ] **Step 5: Commit**

```bash
git add Sources/WorktreeCore/Launch Tests/WorktreeCoreTests/LauncherTests.swift
git commit -m "feat: launcher for editor/terminal/finder

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: WorktreeCreator (orkestrasyon)

**Files:**
- Create: `Sources/WorktreeCore/Create/WorktreeCreator.swift`
- Test: `Tests/WorktreeCoreTests/WorktreeCreatorTests.swift`

**Interfaces:**
- Consumes: `Config`, `RepoSettings`, `Defaults` (Task 2); `PlaceholderResolver` (Task 3); `Repo`, `Worktree`, `WorktreeRequest` (Task 4); `GitService` (Task 5); `SetupRunner` (Task 6).
- Produces:
  - `struct WorktreeCreator { init(config: Config, git: GitService, setup: SetupRunner) }`
  - `func placeholderValues(for req: WorktreeRequest) -> [String: String]` — `group`, `repo`, `type`, `taskName`, `branch` üretir. `type`: repo ayarındaki `type` ?? repo adından türetilir (`deriveType`: ad `-` içeriyorsa ilk `-`'den sonrası, yoksa adın kendisi — ör. `example-admin`→`admin`).
  - `func settings(for repo: Repo) -> RepoSettings?` — `config.repos["<group>/<repo>"]`.
  - `func resolvedPath(for req: WorktreeRequest) throws -> String` — base dizin = repo'nun iki üst dizini (`<root>`); şablon = repoSettings.worktreePath ?? config.defaults.worktreePath; sonuç = `<root>/<çözülmüş-şablon>`.
  - `func create(_ req: WorktreeRequest, progress: @escaping (String) -> Void) throws -> Worktree` — sırayla: path çöz → `git.addWorktree` → `setup.applyEnvRules` (varsa) → `setup.runCommands` (varsa); herhangi biri fırlatırsa durur. `Worktree(path:branch:)` döner.

- [ ] **Step 1: Testleri yaz**

`Tests/WorktreeCoreTests/WorktreeCreatorTests.swift`:

```swift
import XCTest
@testable import WorktreeCore

final class WorktreeCreatorTests: XCTestCase {
    private func makeConfig() -> Config {
        var c = Config.default
        c.repos["example_repos/example-student"] = RepoSettings(
            type: "student",
            worktreePath: nil,
            defaultBase: "develop",
            envRules: [EnvRule(file: ".env.development", key: "VITE_API_URL",
                               value: "https://student-{taskName}.dev.example.com/api")],
            setupCommands: ["npm install"]
        )
        return c
    }

    private func studentRequest() -> WorktreeRequest {
        let repo = Repo(path: "/Users/example/Dev/example_repos/example-student",
                        name: "example-student", group: "example_repos")
        return WorktreeRequest(repo: repo, branch: "randevu", taskName: "randevu", newBranchBase: nil)
    }

    func testResolvedPathUsesRootGroupTypeTaskName() throws {
        let creator = WorktreeCreator(config: makeConfig(),
                                      git: GitService(runner: FakeProcessRunner()),
                                      setup: SetupRunner(runner: FakeProcessRunner()))
        let path = try creator.resolvedPath(for: studentRequest())
        XCTAssertEqual(path, "/Users/example/Dev/example_repos/task/student/randevu")
    }

    func testDerivesTypeWhenNotConfigured() throws {
        var config = Config.default   // repos boş -> defaults + türetilmiş type
        config.defaults.worktreePath = "{group}/task/{type}/{taskName}"
        let creator = WorktreeCreator(config: config,
                                      git: GitService(runner: FakeProcessRunner()),
                                      setup: SetupRunner(runner: FakeProcessRunner()))
        let repo = Repo(path: "/Users/example/Dev/example_repos/example-admin", name: "example-admin", group: "example_repos")
        let req = WorktreeRequest(repo: repo, branch: "x", taskName: "x", newBranchBase: nil)
        XCTAssertEqual(try creator.resolvedPath(for: req),
                       "/Users/example/Dev/example_repos/task/admin/x")
    }

    func testCreateCallsGitThenSetupInOrder() throws {
        let gitFake = FakeProcessRunner()
        let setupFake = FakeProcessRunner()
        let creator = WorktreeCreator(config: makeConfig(),
                                      git: GitService(runner: gitFake),
                                      setup: SetupRunner(runner: setupFake))
        let wt = try creator.create(studentRequest(), progress: { _ in })

        XCTAssertEqual(wt, Worktree(path: "/Users/example/Dev/example_repos/task/student/randevu", branch: "randevu"))
        // git worktree add çağrıldı
        XCTAssertEqual(gitFake.calls.first?.args,
                       ["-C", "/Users/example/Dev/example_repos/example-student", "worktree", "add",
                        "/Users/example/Dev/example_repos/task/student/randevu", "randevu"])
        // setupCommands sh ile çalıştı
        XCTAssertEqual(setupFake.calls.first?.executable, "sh")
        XCTAssertEqual(setupFake.calls.first?.args, ["-c", "npm install"])
    }

    func testCreateHaltsWhenGitFails() {
        let gitFake = FakeProcessRunner()
        gitFake.results = [ProcessResult(exitCode: 128, stdout: "", stderr: "fatal")]
        let setupFake = FakeProcessRunner()
        let creator = WorktreeCreator(config: makeConfig(),
                                      git: GitService(runner: gitFake),
                                      setup: SetupRunner(runner: setupFake))
        XCTAssertThrowsError(try creator.create(studentRequest(), progress: { _ in }))
        XCTAssertTrue(setupFake.calls.isEmpty)   // git başarısız -> setup hiç çalışmadı
    }
}
```

- [ ] **Step 2: Test çalıştır — başarısız olduğunu doğrula**

Run: `swift test --filter WorktreeCreatorTests`
Expected: FAIL — `WorktreeCreator` bulunamıyor.

- [ ] **Step 3: `WorktreeCreator.swift`'i oluştur**

`Sources/WorktreeCore/Create/WorktreeCreator.swift`:

```swift
import Foundation

public struct WorktreeCreator {
    private let config: Config
    private let git: GitService
    private let setup: SetupRunner

    public init(config: Config, git: GitService, setup: SetupRunner) {
        self.config = config; self.git = git; self.setup = setup
    }

    public func settings(for repo: Repo) -> RepoSettings? {
        config.repos["\(repo.group)/\(repo.name)"]
    }

    private func deriveType(_ name: String) -> String {
        if let dash = name.firstIndex(of: "-") {
            return String(name[name.index(after: dash)...])
        }
        return name
    }

    public func placeholderValues(for req: WorktreeRequest) -> [String: String] {
        let type = settings(for: req.repo)?.type ?? deriveType(req.repo.name)
        return [
            "group": req.repo.group,
            "repo": req.repo.name,
            "type": type,
            "taskName": req.taskName,
            "branch": req.branch,
        ]
    }

    public func resolvedPath(for req: WorktreeRequest) throws -> String {
        // base = <root>: repo'nun iki üst dizini (<root>/<group>/<repo>)
        let groupDir = (req.repo.path as NSString).deletingLastPathComponent
        let root = (groupDir as NSString).deletingLastPathComponent
        let template = settings(for: req.repo)?.worktreePath ?? config.defaults.worktreePath
        let resolver = PlaceholderResolver(values: placeholderValues(for: req))
        let relative = try resolver.resolve(template)
        return root + "/" + relative
    }

    @discardableResult
    public func create(_ req: WorktreeRequest, progress: @escaping (String) -> Void) throws -> Worktree {
        let path = try resolvedPath(for: req)
        let resolver = PlaceholderResolver(values: placeholderValues(for: req))

        progress("git worktree add \(path)")
        try git.addWorktree(repoPath: req.repo.path, worktreePath: path,
                            branch: req.branch, newBranchBase: req.newBranchBase)

        let repoSettings = settings(for: req.repo)
        if let rules = repoSettings?.envRules, !rules.isEmpty {
            progress("applying env rules")
            try setup.applyEnvRules(rules, baseRepoPath: req.repo.path,
                                    worktreePath: path, resolver: resolver)
        }
        if let commands = repoSettings?.setupCommands, !commands.isEmpty {
            try setup.runCommands(commands, worktreePath: path, resolver: resolver, progress: progress)
        }
        return Worktree(path: path, branch: req.branch)
    }
}
```

- [ ] **Step 4: Test çalıştır — geçtiğini doğrula**

Run: `swift test --filter WorktreeCreatorTests`
Expected: PASS (4 test).

- [ ] **Step 5: Tüm test paketini çalıştır**

Run: `swift test`
Expected: PASS — tüm task'ların testleri (30 test) yeşil.

- [ ] **Step 6: Commit**

```bash
git add Sources/WorktreeCore/Create Tests/WorktreeCoreTests/WorktreeCreatorTests.swift
git commit -m "feat: worktree creation orchestration

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: SwiftUI MenuBarExtra UI (wiring + manuel doğrulama)

**Files:**
- Modify: `Sources/WorktreeGUI/WorktreeGUIApp.swift`
- Create: `Sources/WorktreeGUI/AppState.swift`
- Create: `Sources/WorktreeGUI/Views/MenuContentView.swift`
- Create: `Sources/WorktreeGUI/Views/NewWorktreeView.swift`
- Create: `Sources/WorktreeGUI/Views/SettingsView.swift`

**Interfaces:**
- Consumes: tüm `WorktreeCore` public API'si.
- Produces: çalışan menubar uygulaması. (UI birim testi yok; manuel doğrulama.)

> Not: UI katmanı birim test edilmez (SwiftUI/menubar etkileşimi). Mantık zaten Task 1-8'de test edildi. Bu task wiring + manuel doğrulamadır.

- [ ] **Step 1: `AppState.swift`'i oluştur**

`Sources/WorktreeGUI/AppState.swift`:

```swift
import Foundation
import SwiftUI
import WorktreeCore

@MainActor
final class AppState: ObservableObject {
    @Published var config: Config
    @Published var repos: [Repo] = []
    @Published var worktreesByRepo: [String: [Worktree]] = [:]
    @Published var log: [String] = []
    @Published var lastError: String?

    private let store: ConfigStore
    private let runner: ProcessRunner = SystemProcessRunner()
    private var git: GitService { GitService(runner: runner) }
    private var launcher: Launcher { Launcher(runner: runner) }

    init() {
        let store = ConfigStore(path: ConfigStore.defaultPath)
        self.store = store
        self.config = (try? store.load()) ?? .default
    }

    func refresh() {
        repos = RepoScanner().scan(roots: config.scanRoots,
                                   depth: config.scanDepth,
                                   manual: config.manualRepos)
        for repo in repos {
            worktreesByRepo[repo.path] = (try? git.worktrees(repoPath: repo.path)) ?? []
        }
    }

    func branches(for repo: Repo) -> [String] {
        (try? git.branches(repoPath: repo.path)) ?? []
    }

    func defaultBase(for repo: Repo) -> String {
        config.repos["\(repo.group)/\(repo.name)"]?.defaultBase ?? config.defaults.defaultBase
    }

    func createWorktree(_ req: WorktreeRequest) {
        log = []
        lastError = nil
        let creator = WorktreeCreator(config: config, git: git,
                                      setup: SetupRunner(runner: runner))
        Task.detached { [weak self] in
            do {
                let wt = try creator.create(req) { line in
                    Task { @MainActor in self?.log.append(line) }
                }
                await MainActor.run {
                    self?.log.append("✓ \(wt.path)")
                    self?.refresh()
                }
            } catch {
                await MainActor.run { self?.lastError = "\(error)" }
            }
        }
    }

    func removeWorktree(repo: Repo, worktree: Worktree, deleteBranch: Bool) {
        do {
            try git.removeWorktree(repoPath: repo.path, worktreePath: worktree.path)
            if deleteBranch { try? git.deleteBranch(repoPath: repo.path, branch: worktree.branch) }
            refresh()
        } catch { lastError = "\(error)" }
    }

    func openEditor(_ path: String) { try? launcher.openInEditor(config.editorApp, path: path) }
    func openTerminal(_ path: String) { try? launcher.openInTerminal(config.terminalApp, path: path) }
    func openFinder(_ path: String) { try? launcher.openInFinder(path: path) }

    func saveConfig() { try? store.save(config); refresh() }
}
```

- [ ] **Step 2: `MenuContentView.swift`'i oluştur**

`Sources/WorktreeGUI/Views/MenuContentView.swift`:

```swift
import SwiftUI
import WorktreeCore

struct MenuContentView: View {
    @EnvironmentObject var state: AppState
    @State private var newWorktreeRepo: Repo?
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Worktrees").font(.headline)
                Spacer()
                Button("Yenile") { state.refresh() }
                Button("Ayarlar") { showSettings = true }
            }

            if let err = state.lastError {
                Text(err).font(.caption).foregroundStyle(.red).lineLimit(3)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(state.repos) { repo in
                        repoSection(repo)
                    }
                }
            }
            .frame(maxHeight: 360)

            Divider()
            Button("Çıkış") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 360)
        .onAppear { state.refresh() }
        .sheet(item: $newWorktreeRepo) { repo in
            NewWorktreeView(repo: repo).environmentObject(state)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(state)
        }
    }

    @ViewBuilder
    private func repoSection(_ repo: Repo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(repo.group)/\(repo.name)").font(.subheadline).bold()
                Spacer()
                Button("+ Yeni") { newWorktreeRepo = repo }
            }
            ForEach(state.worktreesByRepo[repo.path] ?? []) { wt in
                HStack {
                    Text(wt.branch).font(.caption)
                    Spacer()
                    Button("Cursor") { state.openEditor(wt.path) }
                    Button("Terminal") { state.openTerminal(wt.path) }
                    Button("Finder") { state.openFinder(wt.path) }
                    Button(role: .destructive) {
                        state.removeWorktree(repo: repo, worktree: wt, deleteBranch: false)
                    } label: { Image(systemName: "trash") }
                }
                .padding(.leading, 8)
            }
        }
    }
}
```

- [ ] **Step 3: `NewWorktreeView.swift`'i oluştur**

`Sources/WorktreeGUI/Views/NewWorktreeView.swift`:

```swift
import SwiftUI
import WorktreeCore

struct NewWorktreeView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    let repo: Repo

    @State private var mode = 0            // 0 = var olan branch, 1 = yeni branch
    @State private var existingBranch = ""
    @State private var newBranch = ""
    @State private var base = ""
    @State private var taskName = ""
    @State private var branches: [String] = []

    private var effectiveBranch: String { mode == 0 ? existingBranch : newBranch }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Yeni Worktree — \(repo.name)").font(.headline)

            Picker("", selection: $mode) {
                Text("Var olan branch").tag(0)
                Text("Yeni branch").tag(1)
            }.pickerStyle(.segmented)

            if mode == 0 {
                Picker("Branch", selection: $existingBranch) {
                    ForEach(branches, id: \.self) { Text($0).tag($0) }
                }
                .onChange(of: existingBranch) { _, new in if taskName.isEmpty { taskName = new } }
            } else {
                TextField("Yeni branch adı", text: $newBranch)
                    .onChange(of: newBranch) { _, new in taskName = new }
                TextField("Base branch", text: $base)
            }

            TextField("Task adı (klasör)", text: $taskName)

            if !state.log.isEmpty {
                ScrollView { Text(state.log.joined(separator: "\n")).font(.system(.caption, design: .monospaced)) }
                    .frame(height: 80)
            }

            HStack {
                Spacer()
                Button("İptal") { dismiss() }
                Button("Oluştur") {
                    let req = WorktreeRequest(
                        repo: repo, branch: effectiveBranch, taskName: taskName,
                        newBranchBase: mode == 1 ? base : nil)
                    state.createWorktree(req)
                    dismiss()
                }
                .disabled(effectiveBranch.isEmpty || taskName.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 380)
        .onAppear {
            branches = state.branches(for: repo)
            existingBranch = branches.first ?? ""
            base = state.defaultBase(for: repo)
            if mode == 0 { taskName = existingBranch }
        }
    }
}
```

- [ ] **Step 4: `SettingsView.swift`'i oluştur**

`Sources/WorktreeGUI/Views/SettingsView.swift`:

```swift
import SwiftUI
import WorktreeCore

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    @State private var scanRoots = ""
    @State private var manualRepos = ""
    @State private var scanDepth = "3"
    @State private var terminalApp = ""
    @State private var editorApp = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ayarlar").font(.headline)
            Text("Repo bazlı env/komut kuralları için config.json'ı elle düzenle:")
                .font(.caption).foregroundStyle(.secondary)
            Text(ConfigStore.defaultPath).font(.system(.caption, design: .monospaced))

            Form {
                TextField("Tarama kökleri (virgülle)", text: $scanRoots)
                TextField("Tarama derinliği", text: $scanDepth)
                TextField("Manuel repolar (virgülle)", text: $manualRepos)
                TextField("Terminal uygulaması", text: $terminalApp)
                TextField("Editör uygulaması", text: $editorApp)
            }

            HStack {
                Spacer()
                Button("İptal") { dismiss() }
                Button("Kaydet") { save(); dismiss() }
            }
        }
        .padding(16)
        .frame(width: 420)
        .onAppear {
            scanRoots = state.config.scanRoots.joined(separator: ", ")
            manualRepos = state.config.manualRepos.joined(separator: ", ")
            scanDepth = String(state.config.scanDepth)
            terminalApp = state.config.terminalApp
            editorApp = state.config.editorApp
        }
    }

    private func parseList(_ s: String) -> [String] {
        s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func save() {
        state.config.scanRoots = parseList(scanRoots)
        state.config.manualRepos = parseList(manualRepos)
        state.config.scanDepth = Int(scanDepth) ?? 3
        state.config.terminalApp = terminalApp
        state.config.editorApp = editorApp
        state.saveConfig()
    }
}
```

- [ ] **Step 5: `WorktreeGUIApp.swift`'i güncelle**

`Sources/WorktreeGUI/WorktreeGUIApp.swift` (tam içerik):

```swift
import SwiftUI

@main
struct WorktreeGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra("Worktrees", systemImage: "arrow.triangle.branch") {
            MenuContentView().environmentObject(state)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // dock ikonu yok, sadece menubar
    }
}
```

- [ ] **Step 6: Derle**

Run: `swift build`
Expected: `Build complete!` (hata yok).

- [ ] **Step 7: Manuel doğrulama — uygulamayı çalıştır**

Run: `swift run WorktreeGUI`
Beklenen davranış (manuel kontrol listesi):
1. Menubar'da dal (branch) ikonu belirir.
2. İkona tıkla → repolar `~/Dev` altından listelenir.
3. Bir repoda **+ Yeni** → form açılır; var olan branch listesi dolu gelir, task adı otomatik dolar.
4. **Oluştur** → worktree hedef yolda (`<root>/<group>/task/<type>/<taskName>`) oluşur; log görünür; liste yenilenir.
5. Worktree satırında **Cursor / Terminal / Finder** butonları ilgili uygulamayı o klasörde açar.
6. **Çöp kutusu** → worktree kaldırılır, liste güncellenir.
7. **Ayarlar** → kökler/derinlik/uygulamalar düzenlenip kaydedilir; `config.json`'a yazılır.

Bir hata olursa düzelt ve tekrar çalıştır (systematic-debugging skill'ini kullan).

- [ ] **Step 8: Commit**

```bash
git add Sources/WorktreeGUI
git commit -m "feat: SwiftUI menubar UI

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Manuel Test Notu

`SystemProcessRunner` testi (`testSystemRunnerRunsEcho`) gerçek `echo` çalıştırır; sandbox'lı CI'da süreç başlatma kısıtlıysa bu tek test başarısız olabilir. Yerel makinede sorun olmaz. Geri kalan tüm testler `FakeProcessRunner` kullanır ve süreç başlatmaz.
