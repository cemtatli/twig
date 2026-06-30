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
