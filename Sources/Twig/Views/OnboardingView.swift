import SwiftUI
import TwigCore

/// İlk açılış sihirbazı — 3 adım: hoş geldin → scan root → editör/terminal.
/// Atlanabilir; Bitir seçilen editör/terminal'i uygular. `onboardingCompleted`
/// flag'i MenuContentView'daki overlay tetiğini kapatır.
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var step = 0
    @State private var editor: String = ""
    @State private var terminal: String = ""

    private let editors = InstalledApps.installed(InstalledApps.editors)
    private let terminals = InstalledApps.installed(InstalledApps.terminals)

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                Group {
                    switch step {
                    case 0: welcomeStep
                    case 1: rootsStep
                    default: appsStep
                    }
                }
                .frame(maxWidth: 420)
                Spacer(minLength: 0)
                navBar
            }
            .padding(28)
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .onAppear(perform: prefill)
    }

    // MARK: steps

    private var welcomeStep: some View {
        VStack(spacing: 14) {
            TwigWordmark(size: 26)
            Text(state.t(.onbWelcomeTitle)).font(.system(size: 20, weight: .bold))
            Text(state.t(.onbWelcomeBody))
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var rootsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(state.t(.onbRootsTitle), state.t(.onbRootsBody))
            BorderedPillButton(title: state.t(.addFromFinder), systemImage: "folder.badge.plus") {
                state.addReposViaPanel()
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(state.config.scanRoots + state.config.manualRepos, id: \.self) { path in
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill").font(.system(size: 11)).foregroundStyle(Theme.accent)
                        Text(path.abbreviatingHome).font(Theme.mono(11.5)).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                }
            }
        }
    }

    private var appsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader(state.t(.onbAppsTitle), "")
            appPicker(state.t(.editorTitle), options: editors, selection: $editor)
            appPicker(state.t(.terminalTitle), options: terminals, selection: $terminal)
        }
    }

    private func appPicker(_ label: String, options: [String], selection: Binding<String>) -> some View {
        HStack {
            Text(label).font(.system(size: 14))
            Spacer()
            Menu(selection.wrappedValue.isEmpty ? "—" : selection.wrappedValue) {
                ForEach(options, id: \.self) { opt in
                    Button(opt) { selection.wrappedValue = opt }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func stepHeader(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 18, weight: .bold))
            if !body.isEmpty {
                Text(body).font(.system(size: 12.5)).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: chrome

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(i == step ? Theme.accent : Color.white.opacity(0.15))
                        .frame(width: 6, height: 6)
                }
            }
            Spacer()
            Button(state.t(.onbSkip)) { state.skipOnboarding() }
                .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private var navBar: some View {
        HStack {
            if step > 0 {
                Button(state.t(.onbBack)) { withAnimation { step -= 1 } }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            Spacer()
            Button(step == 2 ? state.t(.onbFinish) : state.t(.onbNext)) {
                if step == 2 { state.completeOnboarding(editor: editor, terminal: terminal) }
                else { withAnimation { step += 1 } }
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.vertical, 9)
            .background(Theme.accent, in: Capsule())
        }
    }

    private func prefill() {
        editor = editors.contains(state.config.editorApp) ? state.config.editorApp : (editors.first ?? "")
        terminal = terminals.contains(state.config.terminalApp) ? state.config.terminalApp : (terminals.first ?? "")
    }
}
