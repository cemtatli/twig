import SwiftUI
import WorktreeCore

/// Inline settings pane (shown inside the popover's detail area, not a window).
/// Picker-based on purpose: free-text fields don't get reliable keyboard focus
/// in a MenuBarExtra popover, so everything is choosable without typing.
struct SettingsView: View {
    @EnvironmentObject var state: AppState

    private let terminals = ["Terminal", "iTerm", "Warp", "Ghostty", "kitty", "Alacritty"]
    private let editors = ["Cursor", "Visual Studio Code", "Zed", "Sublime Text", "Nova", "Xcode"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Ayarlar").font(.title3).bold()

                section("Repo Kaynakları",
                        "Klasör seç: içinde .git olan tek repo, diğerleri taranan kök olur.") {
                    VStack(alignment: .leading, spacing: 4) {
                        if state.config.scanRoots.isEmpty && state.config.manualRepos.isEmpty {
                            Text("Henüz kaynak yok.").font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(state.config.scanRoots, id: \.self) { sourceRow($0, kind: "kök") }
                        ForEach(state.config.manualRepos, id: \.self) { sourceRow($0, kind: "repo") }
                        Button { state.addReposViaPanel() } label: {
                            Label("Finder'dan Ekle", systemImage: "folder.badge.plus")
                        }
                        .controlSize(.small)
                        .padding(.top, 2)
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

                Divider()
                Text("Env/komut kuralları için config.json'ı elle düzenle:")
                    .font(.caption).foregroundStyle(.secondary)
                Text(ConfigStore.defaultPath)
                    .font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            content()
        }
    }

    @ViewBuilder
    private func sourceRow(_ path: String, kind: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: kind == "repo" ? "shippingbox" : "folder")
            Text(path).font(.caption).lineLimit(1).truncationMode(.middle)
            Text("(\(kind))").font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Button(role: .destructive) { state.removeSource(path) } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
        }
    }
}
