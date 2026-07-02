import SwiftUI
import AppKit
import WorktreeCore

/// Settings pane shown inside the popover's detail area (not a separate window).
///
/// Built as a native grouped `Form`: every setting is a `Section`, so the
/// platform supplies the card surfaces, insets, headers/footers, and Light/Dark
/// treatment for free — the single "section" pattern, the System-Settings look.
/// App lists are discovered from what's installed, not hardcoded.
struct SettingsView: View {
    @EnvironmentObject var state: AppState

    private var terminals: [String] { InstalledApps.installed(InstalledApps.terminals) }
    private var editors: [String] { InstalledApps.installed(InstalledApps.editors) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Form {
                // Language — segmented switch under a titled header.
                Section {
                    Picker(state.t(.languageTitle),
                           selection: Binding(get: { state.language },
                                              set: { state.setLanguage($0) })) {
                        ForEach(Language.allCases, id: \.self) { lang in
                            Text(lang.label).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } header: {
                    Text(state.t(.languageTitle))
                } footer: {
                    Text(state.t(.languageCaption))
                }

                // Repo sources — scan roots + manual repos, plus the add button.
                Section {
                    if state.config.scanRoots.isEmpty && state.config.manualRepos.isEmpty {
                        Text(state.t(.noSourcesYet)).foregroundStyle(.secondary)
                    }
                    ForEach(state.config.scanRoots, id: \.self) {
                        sourceRow($0, kind: state.t(.kindRoot), isRepo: false)
                    }
                    ForEach(state.config.manualRepos, id: \.self) {
                        sourceRow($0, kind: state.t(.kindRepo), isRepo: true)
                    }
                    Button {
                        state.addReposViaPanel()
                    } label: {
                        Label(state.t(.addFromFinder), systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.bordered)
                } header: {
                    Text(state.t(.repoSourcesTitle))
                } footer: {
                    Text(state.t(.repoSourcesCaption))
                }

                // Scan depth — segmented 1...5 under a titled header.
                Section {
                    Picker(state.t(.scanDepthTitle), selection: depthBinding) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } header: {
                    Text(state.t(.scanDepthTitle))
                } footer: {
                    Text(state.t(.scanDepthCaption))
                }

                // Terminal — labeled menu row (the title is the row's own label,
                // so no duplicate section header).
                Section {
                    Picker(state.t(.terminalTitle), selection: appBinding(\.terminalApp)) {
                        ForEach(options(state.config.terminalApp, terminals), id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                } footer: {
                    Text(state.t(.terminalCaption))
                }

                // Editor — labeled menu row.
                Section {
                    Picker(state.t(.editorTitle), selection: appBinding(\.editorApp)) {
                        ForEach(options(state.config.editorApp, editors), id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                } footer: {
                    Text(state.t(.editorCaption))
                }

                // Package managers — one labeled menu row per discovered repo.
                Section {
                    if state.repos.isEmpty {
                        Text(state.t(.noReposFound)).foregroundStyle(.secondary)
                    }
                    ForEach(state.repos) { repo in packageManagerRow(repo) }
                } header: {
                    Text(state.t(.packageManagerTitle))
                } footer: {
                    Text(state.t(.packageManagerCaption))
                }

                // Startup command — labeled text row.
                Section {
                    LabeledContent {
                        TextField(state.t(.startupPlaceholder), text: Binding(
                            get: { state.config.terminalStartupCommand },
                            set: { state.config.terminalStartupCommand = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { state.saveConfig() }
                    } label: {
                        Text(state.t(.startupCommandTitle))
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(state.t(.startupCommandCaption))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.t(.editConfigHint))
                            Text(ConfigStore.defaultPath.abbreviatingHome)
                                .font(Theme.mono(11))
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: chrome

    private var header: some View {
        HStack(spacing: 8) {
            SidebarToggle()
            if state.sidebarCollapsed {
                JigMark().frame(width: 18, height: 18)
                    .foregroundStyle(Brand.signalOrange)
            }
            Text(state.t(.settingsTitle))
                .font(.title3).fontWeight(.semibold)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
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

    // MARK: rows

    @ViewBuilder
    private func sourceRow(_ path: String, kind: String, isRepo: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isRepo ? "shippingbox" : "folder")
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(path.abbreviatingHome)
                .font(Theme.mono(11))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Text(kind)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(role: .destructive) {
                state.removeSource(path)
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .help(state.t(.remove))
        }
    }

    @ViewBuilder
    private func packageManagerRow(_ repo: Repo) -> some View {
        Picker(selection: pmBinding(repo)) {
            Text(state.t(.pmNone)).tag("none")
            ForEach(PackageManager.allCases, id: \.self) { pm in
                Text(pm.label).tag(pm.rawValue)
            }
        } label: {
            Label(repo.name, systemImage: "shippingbox")
        }
        .pickerStyle(.menu)
    }
}
