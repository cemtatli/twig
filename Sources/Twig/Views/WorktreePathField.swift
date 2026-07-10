import SwiftUI
import TwigCore

/// Worktree yolu şablon alanı — text field + token insert-chip'leri (tıkla →
/// sona ekle) + canlı doğrulama (bilinmeyen token kırmızı uyarı). Hem per-repo
/// sheet'te hem Defaults'ta kullanılır.
struct WorktreePathField: View {
    @EnvironmentObject var state: AppState
    @Binding var text: String
    var placeholder: String = "{group}/task/{type}-{taskName}"
    var onCommit: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DarkTextField(placeholder: placeholder, text: $text, onSubmit: onCommit)
            HStack(spacing: 5) {
                Text(state.t(.cfgInsert))
                    .font(.system(size: 10.5)).foregroundStyle(.tertiary)
                ForEach(PlaceholderResolver.worktreeTokens, id: \.self) { tok in
                    TagBadge(text: tok, tint: .secondary,
                             onTap: { text += "{\(tok)}"; onCommit() })
                }
            }
            if let bad = PlaceholderResolver.unknownWorktreeToken(in: text) {
                Label("\(state.t(.cfgUnknownToken)): {\(bad)}",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.danger)
            }
        }
    }
}
