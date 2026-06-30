import SwiftUI
import AppKit
import WorktreeCore

struct MenuContentView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Pane: Equatable { case repo, settings, newWorktree }
    @State private var pane: Pane = .repo
    @State private var selectedRepoPath: String?
    @State private var confirmingRemovalPath: String?
    @State private var hoveredPath: String?
    @FocusState private var navFocused: Bool

    private var selectedRepo: Repo? {
        state.repos.first { $0.path == selectedRepoPath } ?? state.repos.first
    }

    private var selectAnim: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.22)
    }

    var body: some View {
        HStack(spacing: 0) {
            if !state.sidebarCollapsed {
                sidebar
                    .frame(width: 200)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                Divider()
            }
            ZStack {
                detail
                    .id(pane)
                    .transition(paneTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .frame(width: 600, height: 580)
        .focusable()
        .focused($navFocused)
        .focusEffectDisabled()
        .onKeyPress(action: handleKey)
        .onAppear { state.refresh(); navFocused = true }
        .onChange(of: pane) { _, new in if new != .newWorktree { navFocused = true } }
        .onChange(of: state.repos.count) { _, _ in
            if selectedRepoPath == nil { selectedRepoPath = state.repos.first?.path }
        }
    }

    private var paneTransition: AnyTransition {
        reduceMotion ? .opacity
            : .asymmetric(insertion: .opacity.combined(with: .offset(x: 14)),
                          removal: .opacity)
    }

    // MARK: Keyboard navigation (1-9, Tab / arrows)

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if pane == .newWorktree { return .ignored }
        if let n = Int(press.characters), (1...9).contains(n) { selectIndex(n - 1); return .handled }
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
        withAnimation(selectAnim) { selectedRepoPath = state.repos[i].path; pane = .repo }
    }

    private func cycle(_ delta: Int) {
        guard !state.repos.isEmpty else { return }
        let cur = state.repos.firstIndex { $0.path == selectedRepo?.path } ?? 0
        let next = (cur + delta + state.repos.count) % state.repos.count
        withAnimation(selectAnim) { selectedRepoPath = state.repos[next].path; pane = .repo }
    }

    // MARK: Sidebar — native source list

    /// List selection mirrors `selectedRepoPath`, but only while the repo pane is
    /// showing — so the highlight clears when Settings / New Worktree take over,
    /// and selecting a repo brings the repo pane back.
    private var repoSelection: Binding<String?> {
        Binding(
            get: { pane == .repo ? selectedRepoPath : nil },
            set: { newValue in
                guard let p = newValue else { return }
                withAnimation(selectAnim) { selectedRepoPath = p; pane = .repo }
            })
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            JigMark()
                .frame(width: 22, height: 22)
                .foregroundStyle(Brand.signalOrange)
                .frame(maxWidth: .infinity)
                .padding(.top, 14).padding(.bottom, 10)

            List(selection: repoSelection) {
                ForEach(Array(state.repos.enumerated()), id: \.element.id) { idx, repo in
                    repoRow(repo, index: idx).tag(repo.path)
                }
            }
            .listStyle(.sidebar)

            Divider()
            HStack(spacing: 4) {
                railButton("folder.badge.plus", label: state.t(.addRepo)) { state.addReposViaPanel() }
                railButton("gearshape", label: state.t(.settings), active: pane == .settings) {
                    withAnimation(selectAnim) { pane = .settings }
                }
                Spacer()
                railButton("power", label: state.t(.quit)) { NSApplication.shared.terminate(nil) }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
        }
    }

    private func repoRow(_ repo: Repo, index: Int) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(repo.name).font(.body)
                Text(repo.group).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "shippingbox")
        }
        .help("\(repo.group)/\(repo.name)  ·  \(index + 1)")
    }

    private func railButton(_ symbol: String, label: String, active: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(active ? Color.accentColor : Color.secondary)
        .help(label)
        .accessibilityLabel(label)
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        switch pane {
        case .settings:
            SettingsView()
        case .newWorktree:
            if let repo = selectedRepo { NewWorktreeForm(repo: repo, onClose: { withAnimation(selectAnim) { pane = .repo } }) }
            else { emptyState }
        case .repo:
            if let repo = selectedRepo { repoDetail(repo) } else { emptyState }
        }
    }

    private func repoDetail(_ repo: Repo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                SidebarToggle()
                if state.sidebarCollapsed {
                    JigMark().frame(width: 18, height: 18)
                        .foregroundStyle(Brand.signalOrange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.title3).fontWeight(.semibold)
                    Text(repo.group)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if state.isRefreshing { ProgressView().controlSize(.small).padding(.leading, 2) }
                Spacer()
                Button { state.refresh() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderless).foregroundStyle(.secondary)
                .help(state.t(.refresh)).accessibilityLabel(state.t(.refresh))
                Button { withAnimation(selectAnim) { pane = .newWorktree } } label: {
                    Label(state.t(.new), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent).help(state.t(.newWorktreeHelp))
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)

            if let err = state.lastError {
                Text(err).font(Theme.mono(11)).foregroundStyle(Theme.danger).lineLimit(2)
                    .padding(.horizontal, 20).padding(.bottom, 10)
            }
            Divider()

            let worktrees = state.worktreesByRepo[repo.path] ?? []
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if worktrees.isEmpty {
                        emptyWorktrees
                    }
                    ForEach(Array(worktrees.enumerated()), id: \.element.id) { _, wt in
                        worktreeRow(repo: repo, wt: wt)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
            HStack(spacing: 0) {
                Text(state.worktreeCountText(worktrees.count))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(repo.path.abbreviatingHome).font(Theme.mono(10.5))
                    .foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyWorktrees: some View {
        VStack(spacing: 8) {
            JigMark()
                .frame(width: 26, height: 26)
                .foregroundStyle(Brand.signalOrange)
            Text(state.t(.noWorktreesYet)).font(.headline)
                .foregroundStyle(.secondary)
            Text(state.t(.createFirstWorktree))
                .font(.subheadline).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 44)
    }

    private func worktreeRow(repo: Repo, wt: Worktree) -> some View {
        let hovered = hoveredPath == wt.path
        return HStack(spacing: 11) {
            Circle()
                .fill(wt.isDirty ? Theme.dotDirty : Theme.dotClean)
                .frame(width: 6, height: 6)
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(wt.branch).font(.body)
                    .lineLimit(1).truncationMode(.middle)
                Text(folderName(wt.path)).font(Theme.mono(10))
                    .foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)

            if confirmingRemovalPath == wt.path {
                Text(state.t(.deletePrompt)).font(.caption).foregroundStyle(.secondary)
                pillButton(state.t(.worktreeWord)) {
                    state.removeWorktree(repo: repo, worktree: wt, deleteBranch: false); confirmingRemovalPath = nil
                }
                pillButton(state.t(.branchPlus), danger: true) {
                    state.removeWorktree(repo: repo, worktree: wt, deleteBranch: true); confirmingRemovalPath = nil
                }
                rowAction("xmark", help: state.t(.cancel)) { confirmingRemovalPath = nil }
            } else {
                HStack(spacing: 4) {
                    rowAction("chevron.left.forwardslash.chevron.right",
                              help: state.config.editorApp) { state.openEditor(wt.path) }
                    rowAction("terminal",
                              help: state.config.terminalApp) { state.openTerminal(wt.path) }
                    rowAction("folder", help: state.t(.finder)) { state.openFinder(wt.path) }
                    rowAction("trash", help: state.t(.delete), danger: true) { confirmingRemovalPath = wt.path }
                }
                .opacity(hovered ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hovered)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovered ? Color.primary.opacity(0.06) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in hoveredPath = hovering ? wt.path : (hovered ? nil : hoveredPath) }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovered)
        .contextMenu {
            Button { state.openEditor(wt.path) } label: {
                Label(state.config.editorApp, systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Button { state.openTerminal(wt.path) } label: {
                Label(state.config.terminalApp, systemImage: "terminal")
            }
            Button { state.openFinder(wt.path) } label: {
                Label(state.t(.finder), systemImage: "folder")
            }
            Divider()
            Button(role: .destructive) { confirmingRemovalPath = wt.path } label: {
                Label(state.t(.delete), systemImage: "trash")
            }
        }
    }

    // MARK: Row controls — native borderless / bordered

    private func rowAction(_ symbol: String, help: String, danger: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12.5, weight: .medium))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(danger ? Theme.danger : Color.secondary)
        .help(help).accessibilityLabel(help)
    }

    private func pillButton(_ title: String, danger: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(title, role: danger ? .destructive : nil, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }

    private func folderName(_ path: String) -> String {
        (path as NSString).lastPathComponent
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            JigWordmark(size: 22)
            Text(state.t(.tagline))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Text(state.t(.noRepositories)).font(.headline)
                .foregroundStyle(.secondary)
            if state.isRefreshing {
                HStack(spacing: 6) { ProgressView().controlSize(.small); Text(state.t(.loading)) }
                    .font(.subheadline).foregroundStyle(.tertiary)
            } else {
                Text(state.t(.pickFolderHint))
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(state.config.scanRoots.joined(separator: ", "))
                    .font(Theme.mono(10)).foregroundStyle(.tertiary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension String {
    /// `/Users/example/foo` → `~/foo` for compact display.
    var abbreviatingHome: String {
        (self as NSString).abbreviatingWithTildeInPath
    }
}
