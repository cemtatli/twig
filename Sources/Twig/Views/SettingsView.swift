import SwiftUI
import AppKit
import TwigCore

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

                    // MARK: — Dil (tek satırlık kart: section başlığı tekrar
                    // olurdu, satır başlığı yeter)
                    card {
                        SettingsRow(title: state.t(.languageTitle),
                                    showsHairline: false) {
                            PillTabBar(items: Language.allCases.map(\.label),
                                       selection: languageSelection,
                                       accessibilityTitle: state.t(.languageTitle))
                        }
                    }

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
                    infoRow(state.t(.repoSourcesCaption))

                    Spacer().frame(height: 8)

                    // MARK: — Tarama derinliği (Keeby "Volume" satırı: etiket +
                    // pill + slider; tek satırlık kart, section başlığı yok).
                    // Etiket lineLimit+layoutPriority, slider esnek genişlik:
                    // dar panelde (sidebar açık) metin harf harf kırılmasın.
                    card {
                        HStack(alignment: .center, spacing: 10) {
                            Text(state.t(.scanDepthTitle))
                                .font(.system(size: 14))
                                .lineLimit(1)
                                .layoutPriority(1)
                            PillBadge("\(state.config.scanDepth)")
                            Spacer(minLength: 12)
                            Slider(value: depthSlider, in: 1...5, step: 1)
                                .frame(minWidth: 90, maxWidth: 190)
                                .accessibilityLabel(state.t(.scanDepthTitle))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(minHeight: 52)
                    }
                    infoRow(state.t(.scanDepthCaption))

                    Spacer().frame(height: 8)

                    // MARK: — Terminal + Editör (tek kart)
                    Theme.sectionLabel("\(state.t(.terminalTitle)) & \(state.t(.editorTitle))")
                    card {
                        SettingsRow(title: state.t(.terminalTitle),
                                    subtitle: state.t(.terminalCaption)) {
                            Picker("", selection: appBinding(\.terminalApp)) {
                                ForEach(options(state.config.terminalApp, terminals), id: \.self) {
                                    Text($0).tag($0)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .buttonStyle(.plain)
                            .accessibilityLabel(state.t(.terminalTitle))
                        }
                        SettingsRow(title: state.t(.editorTitle),
                                    subtitle: state.t(.editorCaption),
                                    showsHairline: false) {
                            Picker("", selection: appBinding(\.editorApp)) {
                                ForEach(options(state.config.editorApp, editors), id: \.self) {
                                    Text($0).tag($0)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .buttonStyle(.plain)
                            .accessibilityLabel(state.t(.editorTitle))
                        }
                    }

                    Spacer().frame(height: 8)

                    // MARK: — Defaults (tüm repolar; per-repo ⚙ ile override)
                    Theme.sectionLabel(state.t(.defaultsTitle))
                    card {
                        VStack(alignment: .leading, spacing: 10) {
                            Theme.sectionLabel(state.t(.cfgWorktreePath))
                            WorktreePathField(text: defaultsBinding(\.worktreePath),
                                              onCommit: { state.saveConfig() })
                            Theme.sectionLabel(state.t(.cfgBase))
                            DarkTextField(placeholder: "main", text: defaultsBinding(\.defaultBase),
                                          onSubmit: { state.saveConfig() })
                        }
                        .padding(12)
                    }
                    infoRow(state.t(.packageManagerCaption))

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
                    VStack(alignment: .leading, spacing: 6) {
                        infoRow(state.t(.startupCommandCaption))
                        infoRow(state.t(.editConfigHint))
                        HStack(spacing: 8) {
                            Text(ConfigStore.defaultPath.abbreviatingHome)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                            Spacer(minLength: 8)
                            Button(action: { state.openConfigFile() }) {
                                Label(state.t(.openConfigButton),
                                      systemImage: "square.and.pencil")
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.accent)
                        }
                        .padding(.leading, 21)   // info ikonu hizası
                        .padding(.horizontal, 6)
                    }

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

    /// PillTabBar indeksle çalışır; Language enum'una çevir.
    private var languageSelection: Binding<Int> {
        Binding(get: { Language.allCases.firstIndex(of: state.language) ?? 0 },
                set: { state.setLanguage(Language.allCases[$0]) })
    }

    /// Slider Double ister; yalnız değer gerçekten değişince yaz (sürükleme
    /// boyunca her tick'te config dosyasına yazmamak için).
    private var depthSlider: Binding<Double> {
        Binding(get: { Double(state.config.scanDepth) },
                set: {
                    let v = Int($0.rounded())
                    guard v != state.config.scanDepth else { return }
                    state.config.scanDepth = v
                    state.saveConfig()
                })
    }

    private func appBinding(_ keyPath: WritableKeyPath<Config, String>) -> Binding<String> {
        Binding(get: { state.config[keyPath: keyPath] },
                set: { state.config[keyPath: keyPath] = $0; state.saveConfig() })
    }

    /// Defaults alanı — set yalnız in-memory config'i yazar (yayınlanır);
    /// dosyaya kayıt DarkTextField'ın onSubmit'inde (her tuşta değil).
    private func defaultsBinding(_ kp: WritableKeyPath<Defaults, String>) -> Binding<String> {
        Binding(get: { state.config.defaults[keyPath: kp] },
                set: { state.config.defaults[keyPath: kp] = $0 })
    }


    private func options(_ current: String, _ presets: [String]) -> [String] {
        presets.contains(current) ? presets : [current] + presets
    }

    // MARK: info row

    /// Kart altı bilgi satırı — info ikonu + mesaj (Keeby ⓘ deseni).
    @ViewBuilder
    private func infoRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: "info.circle")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 6)
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
                    .font(.system(size: 12.5))
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
}
