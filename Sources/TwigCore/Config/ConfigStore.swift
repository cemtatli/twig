import Foundation

public struct ConfigStore {
    private let path: String

    public init(path: String) { self.path = path }

    public static var defaultPath: String {
        Config.expandTilde("~/.config/twig/config.json")
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
