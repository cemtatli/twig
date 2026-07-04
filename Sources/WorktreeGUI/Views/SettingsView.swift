import SwiftUI
import AppKit
import WorktreeCore

/// Settings pane shown inside the popover's detail area (not a separate window).
///
/// Keeby dili: `ScrollView` + `VStack` içinde kart dışı gri section başlıkları,
/// `RoundedRectangle(cornerRadius: 12)` kartlar, kart içi `SettingsRow` satırlar,
/// caption'lar kart altında `.tertiary` rengiyle. Her zaman koyu.
struct SettingsView: View {
    @EnvironmentObject var state: AppState

    private var terminals: [String] { InstalledApps.installed(InstalledApps.terminals) }
    private var editors: [String] { InstalledApps.installed(InstalledApps.editors) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {

                    // MARK: — Dil
                    Theme.sectionLabel(state.t(.languageTitle))
                    card {
                        SettingsRow(title: state.t(.languageTitle), showsHairline: false) {
                            Picker("", selection: Binding(
                                get: { state.language },
                                set: { state.setLanguage($0) }
                            )) {
                                ForEach(Language.allCases, id: \.self) { lang in
                                    Text(lang.label).tag(lang)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                    Text(state.t(.languageCaption))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)

                    Spacer().frame(height: 8)

                    // MARK: — Repo kaynakları
                    Theme.sectionLabel(state.t(.repoSourcesTitle))
                    card {
                        let scanRoots = state.config.scanRoots
                        let manualRepos = state.config.manualRepos
                        if scanRoots.isEmpty && manualRepos.isEmpty {
                            HStack {
                                Text(state.t(.noSourcesYet))
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 15)
                            .frame(minHeight: 52)
                        } else {
                            ForEach(Array(scanRoots.enumerated()), id: \.element) { idx, path in
                                sourceRow(path,
                                          kind: state.t(.kindRoot),
                                          isLast: idx == scanRoots.count - 1 && manualRepos.isEmpty)
                            }
                            ForEach(Array(manualRepos.enumerated()), id: \.element) { idx, path in
                                sourceRow(path,
                                          kind: state.t(.kindRepo),
                                          isLast: idx == manualRepos.count - 1)
                            }
                        }
                    }
                    BorderedPillButton(title: state.t(.addFromFinder),
                                       systemImage: "folder.badge.plus") {
                        state.addReposViaPanel()
                    }
                    .padding(.horizontal, 6)
                    Text(state.t(.repoSourcesCaption))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)

                    Spacer().frame(height: 8)

                    // MARK: — Tarama derinliği
                    Theme.sectionLabel(state.t(.scanDepthTitle))
                    card {
                        SettingsRow(title: state.t(.scanDepthTitle), showsHairline: false) {
                            Picker("", selection: depthBinding) {
                                ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                    Text(state.t(.scanDepthCaption))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)

                    Spacer().frame(height: 8)

                    // MARK: — Terminal + Editör (tek kart)
                    Theme.sectionLabel("\(state.t(.terminalTitle)) & \(state.t(.editorTitle))")
                    card {
                        SettingsRow(title: state.t(.terminalTitle)) {
                            Picker("", selection: appBinding(\.terminalApp)) {
                                ForEach(options(state.config.terminalApp, terminals), id: \.self) {
                                    Text($0).tag($0)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .buttonStyle(.plain)
                        }
                        SettingsRow(title: state.t(.editorTitle), showsHairline: false) {
                            Picker("", selection: appBinding(\.editorApp)) {
                                ForEach(options(state.config.editorApp, editors), id: \.self) {
                                    Text($0).tag($0)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .buttonStyle(.plain)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.t(.terminalCaption))
                            .font(.system(size: 11.5))
                            .foregroundStyle(.tertiary)
                        Text(state.t(.editorCaption))
                            .font(.system(size: 11.5))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 6)

                    Spacer().frame(height: 8)

                    // MARK: — Paket yöneticisi
                    Theme.sectionLabel(state.t(.packageManagerTitle))
                    card {
                        if state.repos.isEmpty {
                            HStack {
                                Text(state.t(.noReposFound))
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 15)
                            .frame(minHeight: 52)
                        } else {
                            ForEach(Array(state.repos.enumerated()), id: \.element.id) { idx, repo in
                                packageManagerRow(repo, isLast: idx == state.repos.count - 1)
                            }
                        }
                    }
                    Text(state.t(.packageManagerCaption))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)

                    Spacer().frame(height: 8)

                    // MARK: — Terminal başlangıç komutu
                    Theme.sectionLabel(state.t(.startupCommandTitle))
                    card {
                        DarkTextField(
                            placeholder: state.t(.startupPlaceholder),
                            text: Binding(
                                get: { state.config.terminalStartupCommand },
                                set: { state.config.terminalStartupCommand = $0 }
                            ),
                            onSubmit: { state.saveConfig() }
                        )
                        .padding(12)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(state.t(.startupCommandCaption))
                            .font(.system(size: 11.5))
                            .foregroundStyle(.tertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.t(.editConfigHint))
                                .font(.system(size: 11.5))
                                .foregroundStyle(.tertiary)
                            Text(ConfigStore.defaultPath.abbreviatingHome)
                                .font(Theme.mono(11))
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, 6)

                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: chrome

    private var header: some View {
        HStack(spacing: 8) {
            SidebarToggle()
            IconTile(systemName: "gearshape.fill",
                     color: Color(white: 0.45),
                     side: 30)
            Text(state.t(.settingsTitle))
                .font(.system(size: 17, weight: .bold))
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

    // MARK: card helper

    /// İkinci seviye yüzey — panel içindeki Keeby form kartı.
    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color.white.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: rows

    @ViewBuilder
    private func sourceRow(_ path: String, kind: String, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(path.abbreviatingHome)
                    .font(Theme.mono(11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                PillBadge(kind)
                Button(role: .destructive) {
                    state.removeSource(path)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(.borderless)
                .help(state.t(.remove))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            if !isLast {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)
                    .padding(.leading, 16)
            }
        }
    }

    @ViewBuilder
    private func packageManagerRow(_ repo: Repo, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                IconTile(systemName: "shippingbox.fill",
                         color: TilePalette.color(at: state.repos.firstIndex(of: repo) ?? 0),
                         side: 24)
                Text(repo.name)
                    .font(.system(size: 14))
                Spacer(minLength: 12)
                Picker("", selection: pmBinding(repo)) {
                    Text(state.t(.pmNone)).tag("none")
                    ForEach(PackageManager.allCases, id: \.self) { pm in
                        Text(pm.label).tag(pm.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            if !isLast {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)
                    .padding(.leading, 16)
            }
        }
    }
}
