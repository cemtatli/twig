import SwiftUI
import TwigCore

/// Worktree yolu şablonu — hazır preset menüsü + "Özel" text alanı. Preset
/// seçmek en yaygın hatasız yol; özel değerde canlı token doğrulaması var.
/// Hem per-repo sheet'te hem Defaults'ta kullanılır.
struct WorktreePathField: View {
    @EnvironmentObject var state: AppState
    @Binding var text: String
    var placeholder: String = "{group}/task/{type}-{taskName}"
    var onCommit: () -> Void = {}

    @State private var customExpanded = false

    private let presets = [
        "{group}/task/{type}-{taskName}",
        "{group}/worktrees/{taskName}",
        "{repo}-{taskName}",
        "worktrees/{branch}",
    ]

    private var isCustom: Bool { !presets.contains(text) && !text.isEmpty }
    private var showCustomField: Bool { customExpanded || isCustom }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                ForEach(presets, id: \.self) { p in
                    Button(p) { text = p; customExpanded = false; onCommit() }
                }
                Divider()
                Button(state.t(.cfgCustom)) { customExpanded = true }
            } label: {
                HStack(spacing: 8) {
                    Text(text.isEmpty ? placeholder : text)
                        .font(Theme.mono(12))
                        .foregroundStyle(text.isEmpty ? .tertiary : .primary)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.white.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showCustomField {
                DarkTextField(placeholder: placeholder, text: $text, onSubmit: onCommit)
                if let bad = PlaceholderResolver.unknownWorktreeToken(in: text) {
                    Label("\(state.t(.cfgUnknownToken)): {\(bad)}",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.danger)
                }
            }
        }
    }
}
