import SwiftUI
import WorktreeCore

struct MenuContentView: View {
    @EnvironmentObject var state: AppState

    enum Pane: Equatable { case repo, settings, newWorktree }
    @State private var pane: Pane = .repo
    @State private var selectedRepoPath: String?
    @State private var confirmingRemovalPath: String?
    @FocusState private var navFocused: Bool

    private var selectedRepo: Repo? {
        state.repos.first { $0.path == selectedRepoPath } ?? state.repos.first
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(width: 480, height: 560)
        .focusable()
        .focused($navFocused)
        .focusEffectDisabled()
        .onKeyPress(action: handleKey)
        .onAppear { state.refresh(); navFocused = true }
        .onChange(of: pane) { _, new in if new != .newWorktree { navFocused = true } }
    }

    // MARK: Keyboard navigation (1–9, Tab / arrows)

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if pane == .newWorktree { return .ignored }   // let text fields type
        if let n = Int(press.characters), (1...9).contains(n) {
            selectIndex(n - 1); return .handled
        }
        switch press.key {
        case .tab where press.modifiers.contains(.shift): cycle(-1); return .handled
        case .tab: cycle(1); return .handled
        case .upArrow: cycle(-1); return .handled
        case .downArrow: cycle(1); return .handled
        default: return .ignored
        }
    }

    private func selectIndex(_ i: Int) {
        guard state.repos.indices.contains(i) else { return }
        selectedRepoPath = state.repos[i].path
        pane = .repo
    }

    private func cycle(_ delta: Int) {
        guard !state.repos.isEmpty else { return }
        let cur = state.repos.firstIndex { $0.path == selectedRepo?.path } ?? 0
        let next = (cur + delta + state.repos.count) % state.repos.count
        selectedRepoPath = state.repos[next].path
        pane = .repo
    }

    // MARK: Sidebar (repo tabs)

    private var sidebar: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(state.repos.enumerated()), id: \.element.id) { idx, repo in
                        repoTab(repo, index: idx)
                    }
                }
                .padding(.vertical, 10)
            }
            Spacer(minLength: 0)
            Divider()
            VStack(spacing: 12) {
                railButton("folder.badge.plus", help: "Repo Ekle", active: false) {
                    state.addReposViaPanel()
                }
                railButton("gearshape", help: "Ayarlar", active: pane == .settings) {
                    pane = .settings
                }
                railButton("power", help: "Çıkış", active: false) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.vertical, 12)
        }
        .frame(width: 66)
    }

    private func repoTab(_ repo: Repo, index: Int) -> some View {
        let isSelected = pane == .repo && selectedRepo?.path == repo.path
        return Button {
            selectedRepoPath = repo.path
            pane = .repo
        } label: {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? Color.accentColor : .clear)
                    .frame(width: 3, height: 30)
                Text(initials(repo.name))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 11)
                            .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
                    )
                    .overlay(alignment: .topTrailing) {
                        if index < 9 {
                            Text("\(index + 1)")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(2)
                        }
                    }
            }
        }
        .buttonStyle(.plain)
        .help("\(repo.group)/\(repo.name)  (\(index + 1))")
    }

    private func railButton(_ symbol: String, help: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17))
                .foregroundStyle(active ? Color.accentColor : .secondary)
                .frame(width: 40, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(active ? Color.accentColor.opacity(0.15) : .clear)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        switch pane {
        case .settings:
            SettingsView()
        case .newWorktree:
            if let repo = selectedRepo {
                NewWorktreeForm(repo: repo, onClose: { pane = .repo })
            } else { emptyState }
        case .repo:
            if let repo = selectedRepo {
                repoDetail(repo)
            } else { emptyState }
        }
    }

    private func repoDetail(_ repo: Repo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(repo.name).font(.title3).bold()
                    Text(repo.group).font(.caption).foregroundStyle(.secondary)
                }
                if state.isRefreshing { ProgressView().controlSize(.small) }
                Spacer()
                Button { state.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.bordered).controlSize(.small).help("Yenile")
                Button { pane = .newWorktree } label: { Label("Yeni", systemImage: "plus") }
                    .buttonStyle(.borderedProminent).controlSize(.regular).help("Yeni worktree")
            }
            .padding(14)

            if let err = state.lastError {
                Text(err).font(.caption).foregroundStyle(.red).lineLimit(2)
                    .padding(.horizontal, 14).padding(.bottom, 6)
            }
            Divider()

            let worktrees = state.worktreesByRepo[repo.path] ?? []
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if worktrees.isEmpty {
                        Text("Bu repoda worktree yok. “Yeni” ile bir tane oluştur.")
                            .font(.callout).foregroundStyle(.secondary)
                            .padding(14)
                    }
                    ForEach(worktrees) { wt in
                        worktreeRow(repo: repo, wt: wt)
                        Divider().padding(.leading, 14)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func worktreeRow(repo: Repo, wt: Worktree) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch").foregroundStyle(.secondary)
            Text(wt.branch).font(.body).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 8)

            if confirmingRemovalPath == wt.path {
                Text("Sil?").font(.caption).foregroundStyle(.secondary)
                Button("Worktree") {
                    state.removeWorktree(repo: repo, worktree: wt, deleteBranch: false)
                    confirmingRemovalPath = nil
                }.controlSize(.small)
                Button("+ Branch") {
                    state.removeWorktree(repo: repo, worktree: wt, deleteBranch: true)
                    confirmingRemovalPath = nil
                }.controlSize(.small).tint(.red)
                Button { confirmingRemovalPath = nil } label: { Image(systemName: "xmark") }
                    .controlSize(.small)
            } else {
                actionButton("chevron.left.forwardslash.chevron.right", help: state.config.editorApp) {
                    state.openEditor(wt.path)
                }
                actionButton("terminal", help: "Terminal") { state.openTerminal(wt.path) }
                actionButton("folder", help: "Finder") { state.openFinder(wt.path) }
                actionButton("trash", help: "Sil", tint: .red) { confirmingRemovalPath = wt.path }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    private func actionButton(_ symbol: String, help: String, tint: Color? = nil,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(tint)
        .help(help)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Repo yok").font(.title3).bold()
            if state.isRefreshing {
                HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Yükleniyor…") }
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text("Soldaki “Repo Ekle” ile Finder'dan bir klasör seç.")
                    .font(.callout).foregroundStyle(.secondary)
                Text("Kökler: \(state.config.scanRoots.joined(separator: ", "))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: Helpers

    private func initials(_ name: String) -> String {
        let core = name.split(separator: "-").last.map(String.init) ?? name
        return String(core.prefix(2)).uppercased()
    }
}
