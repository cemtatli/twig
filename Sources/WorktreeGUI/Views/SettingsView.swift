import SwiftUI
import AppKit
import WorktreeCore

/// Inline settings pane (shown inside the popover's detail area, not a window).
/// Picker-based on purpose: free-text fields don't get reliable keyboard focus
/// in a MenuBarExtra popover, so everything is choosable without typing.
///
/// Laid out like System Settings: a section title + caption above each grouped
/// card. App lists are discovered from what's installed, not hardcoded.
struct SettingsView: View {
    @EnvironmentObject var state: AppState

    private var terminals: [String] { InstalledApps.installed(InstalledApps.terminals) }
    private var editors: [String] { InstalledApps.installed(InstalledApps.editors) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    SidebarToggle()
                    Text("Ayarlar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }

                section("Repo Kaynakları",
                        "Klasör seç: içinde .git olan tek repo, diğerleri taranan kök olur.") {
                    VStack(alignment: .leading, spacing: 6) {
                        if state.config.scanRoots.isEmpty && state.config.manualRepos.isEmpty {
                            Text("Henüz kaynak yok").font(.system(size: 11))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        ForEach(state.config.scanRoots, id: \.self) { sourceRow($0, kind: "kök") }
                        ForEach(state.config.manualRepos, id: \.self) { sourceRow($0, kind: "repo") }
                        Button { state.addReposViaPanel() } label: {
                            Label("Finder'dan Ekle", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(GhostPill(size: 11))
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

                section("Paket Yöneticisi",
                        "Seçili repolarda worktree oluşunca install çalışır, sonra dev sunucusu terminalde açılır.") {
                    VStack(alignment: .leading, spacing: 8) {
                        if state.repos.isEmpty {
                            Text("Repo bulunamadı").font(.system(size: 11))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        ForEach(state.repos) { repo in packageManagerRow(repo) }
                    }
                }

                section("Terminal Başlangıç Komutu",
                        "Terminal açılınca worktree'de çalışır (opsiyonel). Enter ile kaydet.") {
                    TextField("ör. npm run dev", text: Binding(
                        get: { state.config.terminalStartupCommand },
                        set: { state.config.terminalStartupCommand = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { state.saveConfig() }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Env/komut kuralları için config.json'ı elle düzenle:")
                        .font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                    Text(ConfigStore.defaultPath.abbreviatingHome)
                        .font(Theme.mono(10)).foregroundStyle(Theme.textTertiary)
                        .textSelection(.enabled)
                }
                .padding(.top, 2)
            }
            .padding(20)
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

    private func pmBinding(_ repo: Repo) -> Binding<String> {
        Binding(get: { state.packageManager(for: repo)?.rawValue ?? "none" },
                set: { state.setPackageManager(PackageManager(rawValue: $0), for: repo) })
    }

    private func options(_ current: String, _ presets: [String]) -> [String] {
        presets.contains(current) ? presets : [current] + presets
    }

    // MARK: pieces

    @ViewBuilder
    private func section<C: View>(_ title: String, _ subtitle: String,
                                  @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
            }
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func sourceRow(_ path: String, kind: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: kind == "repo" ? "shippingbox" : "folder")
                .font(.system(size: 11)).foregroundStyle(Theme.textSecondary).frame(width: 14)
            Text(path.abbreviatingHome).font(Theme.mono(10.5))
                .foregroundStyle(Theme.textPrimary).lineLimit(1).truncationMode(.middle)
            Text(kind).font(.system(size: 9, weight: .medium)).foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
            Spacer()
            Button { state.removeSource(path) } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 12)).foregroundStyle(Theme.danger.opacity(0.85))
            }
            .buttonStyle(.plain).help("Kaldır")
        }
    }

    @ViewBuilder
    private func packageManagerRow(_ repo: Repo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.system(size: 11)).foregroundStyle(Theme.textSecondary).frame(width: 14)
            Text(repo.name).font(.system(size: 12))
                .foregroundStyle(Theme.textPrimary).lineLimit(1).truncationMode(.middle)
            Spacer()
            Picker("", selection: pmBinding(repo)) {
                Text("Yok").tag("none")
                ForEach(PackageManager.allCases, id: \.self) { pm in
                    Text(pm.label).tag(pm.rawValue)
                }
            }
            .labelsHidden().frame(width: 110)
        }
    }
}
