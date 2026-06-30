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
                    Text(state.t(.settingsTitle))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }

                section(state.t(.languageTitle), state.t(.languageCaption)) {
                    Picker("", selection: Binding(
                        get: { state.language },
                        set: { state.setLanguage($0) }
                    )) {
                        ForEach(Language.allCases, id: \.self) { lang in
                            Text(lang.label).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }

                section(state.t(.repoSourcesTitle), state.t(.repoSourcesCaption)) {
                    VStack(alignment: .leading, spacing: 6) {
                        if state.config.scanRoots.isEmpty && state.config.manualRepos.isEmpty {
                            Text(state.t(.noSourcesYet)).font(.system(size: 11))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        ForEach(state.config.scanRoots, id: \.self) { sourceRow($0, kind: state.t(.kindRoot), isRepo: false) }
                        ForEach(state.config.manualRepos, id: \.self) { sourceRow($0, kind: state.t(.kindRepo), isRepo: true) }
                        Button { state.addReposViaPanel() } label: {
                            Label(state.t(.addFromFinder), systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(GhostPill(size: 11))
                        .padding(.top, 2)
                    }
                }

                section(state.t(.scanDepthTitle), state.t(.scanDepthCaption)) {
                    Picker("", selection: depthBinding) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }

                section(state.t(.terminalTitle), state.t(.terminalCaption)) {
                    Picker("", selection: appBinding(\.terminalApp)) {
                        ForEach(options(state.config.terminalApp, terminals), id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }

                section(state.t(.editorTitle), state.t(.editorCaption)) {
                    Picker("", selection: appBinding(\.editorApp)) {
                        ForEach(options(state.config.editorApp, editors), id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }

                section(state.t(.packageManagerTitle), state.t(.packageManagerCaption)) {
                    VStack(alignment: .leading, spacing: 8) {
                        if state.repos.isEmpty {
                            Text(state.t(.noReposFound)).font(.system(size: 11))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        ForEach(state.repos) { repo in packageManagerRow(repo) }
                    }
                }

                section(state.t(.startupCommandTitle), state.t(.startupCommandCaption)) {
                    TextField(state.t(.startupPlaceholder), text: Binding(
                        get: { state.config.terminalStartupCommand },
                        set: { state.config.terminalStartupCommand = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { state.saveConfig() }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(state.t(.editConfigHint))
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
    private func sourceRow(_ path: String, kind: String, isRepo: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isRepo ? "shippingbox" : "folder")
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
            .buttonStyle(.plain).help(state.t(.remove))
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
                Text(state.t(.pmNone)).tag("none")
                ForEach(PackageManager.allCases, id: \.self) { pm in
                    Text(pm.label).tag(pm.rawValue)
                }
            }
            .labelsHidden().frame(width: 110)
        }
    }
}
