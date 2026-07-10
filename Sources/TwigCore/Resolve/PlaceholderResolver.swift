import Foundation

public enum PlaceholderError: Error, Equatable {
    case unresolved(String)
}

public struct PlaceholderResolver {
    let values: [String: String]

    public init(values: [String: String]) { self.values = values }

    /// Worktree yolu şablonunda kullanılabilen token'lar.
    public static let worktreeTokens = ["group", "repo", "type", "taskName", "branch"]

    /// Şablonda bilinen worktree token'ları dışında bir token varsa onu döner,
    /// yoksa nil — canlı doğrulama için.
    public static func unknownWorktreeToken(in template: String) -> String? {
        let dummy = Dictionary(uniqueKeysWithValues: worktreeTokens.map { ($0, "x") })
        do { _ = try PlaceholderResolver(values: dummy).resolve(template); return nil }
        catch let PlaceholderError.unresolved(token) { return token }
        catch { return nil }
    }

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
