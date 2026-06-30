import SwiftUI
import WorktreeCore

/// Inline settings pane (shown inside the popover's detail area, not a window).
/// Picker-based on purpose: free-text fields don't get reliable keyboard focus
/// in a MenuBarExtra popover, so everything is choosable without typing.
struct SettingsView: View {
    @EnvironmentObject var state: AppState

    private let terminals = ["Terminal", "iTerm", "Warp", "Ghostty", "kitty", "Alacritty", "cmux"]
    private let editors = ["Cursor", "Visual Studio Code", "Zed", "Sublime Text", "Nova", "Xcode"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Ayarlar")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                section("Repo Kaynakları",
                        "Klasör seç: içinde .git olan tek repo, diğerleri taranan kök olur.") {
                    VStack(alignment: .leading, spacing: 5) {
                        if state.config.scanRoots.isEmpty && state.config.manualRepos.isEmpty {
                            Text("Henüz kaynak yok").font(Theme.mono(10))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        ForEach(state.config.scanRoots, id: \.self) { sourceRow($0, kind: "kök") }
                        ForEach(state.config.manualRepos, id: \.self) { sourceRow($0, kind: "repo") }
                        Button { state.addReposViaPanel() } label: {
                            Label("Finder'dan Ekle", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(GhostPill(size: 11))
                        .padding(.top, 4)
                    }
                }

                section("Tarama Derinliği", "Kök altında kaç seviye derine bakılsın") {
                    Picker("", selection: depthBinding) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }

                section("Terminal", "Worktree hangi terminalde açılsın") {
                    Picker("", selection: appBinding(\.terminalApp)) {
                        ForEach(options(state.config.terminalApp, terminals), id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }

                section("Editör", "Worktree hangi editörde açılsın") {
                    Picker("", selection: appBinding(\.editorApp)) {
                        ForEach(options(state.config.editorApp, editors), id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }

                section("Terminal Başlangıç Komutu", "Terminal açılınca worktree'de çalışır (opsiyonel). Enter ile kaydet.") {
                    TextField("ör. npm run dev", text: Binding(
                        get: { state.config.terminalStartupCommand },
                        set: { state.config.terminalStartupCommand = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { state.saveConfig() }
                }

                Rectangle().fill(Theme.hairline).frame(height: 1).padding(.vertical, 2)
                Text("Env/komut kuralları için config.json'ı elle düzenle:")
                    .font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                Text(ConfigStore.defaultPath.abbreviatingHome)
                    .font(Theme.mono(9.5)).foregroundStyle(Theme.textTertiary)
                    .textSelection(.enabled)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: bindings (apply + persist immediately)

    private var depthBinding: Binding<Int> {
        Binding(get: { state.config.scanDepth },
                set: { state.config.scanDepth = $0; state.saveConfig() })
    }

    private func appBinding(_ keyPath: WritableKeyPath<Config, String>) -> Binding<String> {
        Binding(get: { state.config[keyPath: keyPath] },
                set: { state.config[keyPath: keyPath] = $0; state.saveConfig() })
    }

    private func options(_ current: String, _ presets: [String]) -> [String] {
        presets.contains(current) ? presets : [current] + presets
    }

    // MARK: pieces

    @ViewBuilder
    private func section<C: View>(_ title: String, _ subtitle: String,
                                  @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(Theme.mono(9, .medium)).tracking(0.5)
                .foregroundStyle(Theme.textSecondary)
            Text(subtitle).font(.system(size: 10.5)).foregroundStyle(Theme.textTertiary)
            content().padding(.top, 1)
        }
    }

    @ViewBuilder
    private func sourceRow(_ path: String, kind: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: kind == "repo" ? "shippingbox" : "folder")
                .font(.system(size: 11)).foregroundStyle(Theme.textSecondary).frame(width: 14)
            Text(path.abbreviatingHome).font(Theme.mono(10.5))
                .foregroundStyle(Theme.textPrimary).lineLimit(1).truncationMode(.middle)
            Text(kind).font(Theme.mono(8.5)).foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(Capsule().fill(Theme.hover))
            Spacer()
            Button { state.removeSource(path) } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 12)).foregroundStyle(Theme.danger.opacity(0.85))
            }
            .buttonStyle(.plain).help("Kaldır")
        }
    }
}
