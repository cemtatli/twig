import Foundation

public enum ToastKind: Equatable, Hashable {
    case success, error, info
}

/// Geçici bildirim — aksiyon sonrası (oluştu/silindi) ya da hata için.
public struct Toast: Identifiable, Equatable {
    public let id: UUID
    public let message: String
    public let kind: ToastKind

    public init(id: UUID = UUID(), message: String, kind: ToastKind) {
        self.id = id; self.message = message; self.kind = kind
    }
}

/// Bir hatayı kullanıcıya gösterilecek kısa tek satıra indirger.
/// GitError için stderr'in son boş-olmayan satırı; yoksa exit-code fallback.
public func friendlyMessage(_ error: Error) -> String {
    if case let GitError.command(_, exitCode, stderr) = error {
        let lastLine = stderr.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last(where: { !$0.isEmpty })
        return lastLine ?? "git error (exit \(exitCode))"
    }
    return "\(error)"
}
