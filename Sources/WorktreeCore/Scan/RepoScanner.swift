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
            if found[path] == nil, isBaseRepo(path) {
                found[path] = makeRepo(path)
            }
        }
        return found.values.sorted { $0.path < $1.path }
    }

    private func walk(dir: String, depthLeft: Int, into found: inout [String: Repo]) {
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: dir + "/.git", isDirectory: &isDir) {
            if isDir.boolValue {
                found[dir] = makeRepo(dir)   // base repo (.git directory)
            }
            return   // stop: base repo OR worktree (.git file) — never descend further
        }
        guard depthLeft > 0 else { return }
        guard let entries = try? fileManager.contentsOfDirectory(atPath: dir) else { return }
        for entry in entries where !entry.hasPrefix(".") {
            let child = dir + "/" + entry
            var childIsDir: ObjCBool = false
            guard fileManager.fileExists(atPath: child, isDirectory: &childIsDir), childIsDir.boolValue else { continue }
            walk(dir: child, depthLeft: depthLeft - 1, into: &found)
        }
    }

    private func isBaseRepo(_ dir: String) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: dir + "/.git", isDirectory: &isDir) && isDir.boolValue
    }

    private func makeRepo(_ path: String) -> Repo {
        let name = (path as NSString).lastPathComponent
        let group = ((path as NSString).deletingLastPathComponent as NSString).lastPathComponent
        return Repo(path: path, name: name, group: group)
    }
}
