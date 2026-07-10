import SwiftUI
import TwigCore

/// Per-repo config editörü — env/setup kuralları, tip, base, worktree yolu,
/// paket yöneticisi. Boş alanlar defaults'a düşer. "Bitti"de + kapanışta yazar.
struct RepoConfigSheet: View {
    @EnvironmentObject var state: AppState
    let repo: Repo
    var onClose: () -> Void = {}

    @State private var type: String = ""
    @State private var base: String = ""
    @State private var worktreePath: String = ""
    @State private var pm: String?               // nil / "npm" / "yarn"
    @State private var devPort: String = ""
    @State private var envRules: [EnvRule] = []
    @State private var setupCommands: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.hairline).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    field(state.t(.cfgType), text: $type,
                          placeholder: derivedType)
                    field(state.t(.cfgBase), text: $base,
                          placeholder: state.config.defaults.defaultBase)
                    VStack(alignment: .leading, spacing: 5) {
                        Theme.sectionLabel(state.t(.cfgWorktreePath))
                        WorktreePathField(text: $worktreePath,
                                          placeholder: state.config.defaults.worktreePath)
                    }

                    packageManagerPicker

                    field(state.t(.cfgDevPort), text: $devPort, placeholder: "3000")

                    envSection
                    setupSection

                    infoRow(state.t(.repoConfigHelp))
                }
                .padding(.horizontal, 20).padding(.vertical, 18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: load)
        .onDisappear(perform: persist)
    }

    // MARK: chrome

    private var header: some View {
        HStack(spacing: 8) {
            SidebarToggle()
            IconTile(systemName: "gearshape.fill", color: Color(white: 0.45), side: 30)
            Text("\(repo.name) · \(state.t(.repoConfigTitle))")
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            Button(state.t(.cfgDone)) { persist(); onClose() }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Theme.accent, in: Capsule())
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)
    }

    private var derivedType: String {
        guard let dash = repo.name.firstIndex(of: "-") else { return repo.name }
        return String(repo.name[repo.name.index(after: dash)...])
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Theme.sectionLabel(label)
            DarkTextField(placeholder: placeholder, text: text)
        }
    }

    private var packageManagerPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Theme.sectionLabel(state.t(.packageManagerTitle))
            HStack(spacing: 6) {
                pmPill(state.t(.pmNone), value: nil)
                pmPill("npm", value: "npm")
                pmPill("Yarn", value: "yarn")
            }
        }
    }

    private func pmPill(_ title: String, value: String?) -> some View {
        let selected = pm == value
        return Button(title) { pm = value }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .foregroundStyle(selected ? .white : .secondary)
            .background(selected ? Theme.accent : Color.white.opacity(0.06), in: Capsule())
    }

    // MARK: env rules

    private var envSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Theme.sectionLabel(state.t(.cfgEnvRules))
            ForEach(envRules.indices, id: \.self) { i in
                HStack(spacing: 6) {
                    DarkTextField(placeholder: state.t(.cfgFile), text: bindingEnv(i, \.file))
                        .frame(width: 90)
                    DarkTextField(placeholder: state.t(.cfgKey), text: bindingEnv(i, \.key))
                    DarkTextField(placeholder: state.t(.cfgValue), text: bindingEnv(i, \.value))
                    Button { envRules.remove(at: i) } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(Theme.danger)
                    }.buttonStyle(.plain)
                }
            }
            addButton(state.t(.cfgAddRule)) { envRules.append(EnvRule(file: ".env", key: "", value: "")) }
        }
    }

    private func bindingEnv(_ i: Int, _ kp: WritableKeyPath<EnvRule, String>) -> Binding<String> {
        Binding(get: { envRules.indices.contains(i) ? envRules[i][keyPath: kp] : "" },
                set: { if envRules.indices.contains(i) { envRules[i][keyPath: kp] = $0 } })
    }

    // MARK: setup commands

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Theme.sectionLabel(state.t(.cfgSetupCommands))
            ForEach(setupCommands.indices, id: \.self) { i in
                HStack(spacing: 6) {
                    DarkTextField(placeholder: "yarn build",
                                  text: Binding(get: { setupCommands.indices.contains(i) ? setupCommands[i] : "" },
                                                set: { if setupCommands.indices.contains(i) { setupCommands[i] = $0 } }))
                    Button { setupCommands.remove(at: i) } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(Theme.danger)
                    }.buttonStyle(.plain)
                }
            }
            addButton(state.t(.cfgAddCommand)) { setupCommands.append("") }
        }
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.accent)
        }.buttonStyle(.plain)
    }

    private func infoRow(_ text: String) -> some View {
        Text(text).font(.system(size: 11.5)).foregroundStyle(.tertiary)
    }

    // MARK: load / persist

    private func load() {
        let s = state.repoSettings(for: repo)
        type = s.type ?? ""
        base = s.defaultBase ?? ""
        worktreePath = s.worktreePath ?? ""
        pm = s.packageManager
        devPort = s.devPort.map(String.init) ?? ""
        envRules = s.envRules ?? []
        setupCommands = s.setupCommands ?? []
    }

    private func persist() {
        func nilIfEmpty(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespaces)
            return t.isEmpty ? nil : t
        }
        // Boş env/setup satırlarını at.
        let cleanEnv = envRules.filter { !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
        let cleanSetup = setupCommands.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let settings = RepoSettings(
            type: nilIfEmpty(type),
            worktreePath: nilIfEmpty(worktreePath),
            defaultBase: nilIfEmpty(base),
            envRules: cleanEnv.isEmpty ? nil : cleanEnv,
            setupCommands: cleanSetup.isEmpty ? nil : cleanSetup,
            packageManager: pm,
            devPort: Int(devPort.trimmingCharacters(in: .whitespaces)))
        state.saveRepoSettings(settings, for: repo)
    }
}
