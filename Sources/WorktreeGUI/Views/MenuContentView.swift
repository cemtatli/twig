import SwiftUI
import AppKit
import WorktreeCore

struct MenuContentView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    enum Pane: Equatable { case repo, settings, newWorktree }
    @State private var pane: Pane = .repo
    @State private var selectedRepoPath: String?
    @State private var confirmingRemovalPath: String?
    @State private var hoveredPath: String?
    @State private var hoveredRepoPath: String?
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
                    .background(sidebarSurface)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                Divider()
            }
            ZStack {
                detailSurface
                detail
                    .id(pane)
                    .transition(paneTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .frame(width: 560, height: 580)
        .focusable()
        .focused($navFocused)
        .focusEffectDisabled()
        .onKeyPress(action: handleKey)
        .onAppear { state.refresh(); navFocused = true }
        .onChange(of: pane) { _, new in if new != .newWorktree { navFocused = true } }
    }

    private var paneTransition: AnyTransition {
        reduceMotion ? .opacity
            : .asymmetric(insertion: .opacity.combined(with: .offset(x: 14)),
                          removal: .opacity)
    }

    // MARK: Surfaces — native vibrancy, solid fallback under Reduce Transparency

    @ViewBuilder private var sidebarSurface: some View {
        if reduceTransparency { Color(nsColor: .windowBackgroundColor) }
        else { VisualEffect(material: .sidebar) }
    }
    @ViewBuilder private var detailSurface: some View {
        if reduceTransparency { Color(nsColor: .windowBackgroundColor) }
        else { VisualEffect(material: .headerView) }
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

    // MARK: Sidebar (source list)

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                JigWordmark(size: 15)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 2)

            HStack(spacing: 6) {
                BrandBracket(size: 9)
                Text(state.t(.sidebarRepos))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(state.repos.enumerated()), id: \.element.id) { idx, repo in
                        repoRow(repo, index: idx)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

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
        let isSelected = pane == .repo && selectedRepo?.path == repo.path
        let isHovered = hoveredRepoPath == repo.path
        return Button {
            withAnimation(selectAnim) { selectedRepoPath = repo.path; pane = .repo }
        } label: {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Theme.accent : Color.primary.opacity(0.08))
                    .frame(width: 26, height: 26)
                    .overlay {
                        if index < 9 {
                            // The shortcut number IS the icon — press 1-9 to jump here.
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                        } else {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                        }
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(repo.name)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1).truncationMode(.middle)
                    Text(repo.group)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.rRow, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.16)
                          : isHovered ? Theme.hover : .clear)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    AccentSpine().padding(.vertical, 4)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredRepoPath = $0 ? repo.path : (isHovered ? nil : hoveredRepoPath) }
        .help("\(repo.group)/\(repo.name)  ·  \(index + 1)")
    }

    private func railButton(_ symbol: String, label: String, active: Bool = false,
                            action: @escaping () -> Void) -> some View {
        RailButton(symbol: symbol, active: active, action: action)
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(repo.group)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
                if state.isRefreshing { ProgressView().controlSize(.small).padding(.leading, 2) }
                Spacer()
                Button { state.refresh() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain).help(state.t(.refresh)).accessibilityLabel(state.t(.refresh))
                Button { withAnimation(selectAnim) { pane = .newWorktree } } label: {
                    Label(state.t(.new), systemImage: "plus")
                }
                .buttonStyle(AccentPill(size: 12)).help(state.t(.newWorktreeHelp))
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
                    .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                Spacer()
                Text(repo.path.abbreviatingHome).font(Theme.mono(10.5))
                    .foregroundStyle(Theme.textTertiary).lineLimit(1).truncationMode(.middle)
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyWorktrees: some View {
        VStack(spacing: 8) {
            JigMark()
                .frame(width: 26, height: 26)
                .foregroundStyle(Theme.textTertiary)
            Text(state.t(.noWorktreesYet)).font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Text(state.t(.createFirstWorktree))
                .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 44)
    }

    @ViewBuilder
    private func worktreeRow(repo: Repo, wt: Worktree) -> some View {
        let hovered = hoveredPath == wt.path
        HStack(spacing: 11) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovered ? Theme.accent : Theme.textTertiary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(wt.branch).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary).lineLimit(1).truncationMode(.middle)
                Text(folderName(wt.path)).font(Theme.mono(10))
                    .foregroundStyle(Theme.textTertiary).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)

            if confirmingRemovalPath == wt.path {
                Text(state.t(.deletePrompt)).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
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
                .offset(x: reduceMotion ? 0 : (hovered ? 0 : 8))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hovered)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Theme.rRow, style: .continuous)
                .fill(hovered ? Theme.hover : .clear)
        )
        .overlay(alignment: .leading) {
            if hovered {
                AccentSpine().padding(.vertical, 4).transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in hoveredPath = hovering ? wt.path : (hovered ? nil : hoveredPath) }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovered)
    }

    // MARK: Action buttons — one uniform, ghost, monochrome family

    private func rowAction(_ symbol: String, help: String, danger: Bool = false,
                           action: @escaping () -> Void) -> some View {
        RowActionButton(symbol: symbol, danger: danger, action: action)
            .help(help).accessibilityLabel(help)
    }

    private func pillButton(_ title: String, danger: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(title, action: action).buttonStyle(GhostPill(size: 11, danger: danger))
    }

    private func folderName(_ path: String) -> String {
        (path as NSString).lastPathComponent
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            JigWordmark(size: 22)
            Text(state.t(.tagline))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
            Text(state.t(.noRepositories)).font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            if state.isRefreshing {
                HStack(spacing: 6) { ProgressView().controlSize(.small); Text(state.t(.loading)) }
                    .font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
            } else {
                Text(state.t(.pickFolderHint))
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                Text(state.config.scanRoots.joined(separator: ", "))
                    .font(Theme.mono(10)).foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A small toolbar-style button for the sidebar footer (add / settings / quit).
private struct RailButton: View {
    let symbol: String
    var active: Bool = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 14, weight: .medium))
                .foregroundStyle(active ? Theme.accent : Theme.textSecondary)
                .frame(width: 30, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(active ? Theme.accent.opacity(0.16) : hovering ? Theme.hover : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// A row action: a uniform monochrome SF Symbol, ghost by default, brightening
/// to primary (or danger) only on hover. Every action — editor, terminal,
/// Finder, delete — shares the same symbol family so the row reads as one set,
/// not a mix of vendor logos.
private struct RowActionButton: View {
    let symbol: String
    var danger: Bool = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(hovering ? (danger ? Theme.danger : Theme.textPrimary)
                                          : Theme.textSecondary)
                .frame(width: 27, height: 27)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(hovering ? Theme.selected : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

extension String {
    /// `/Users/example/foo` → `~/foo` for compact display.
    var abbreviatingHome: String {
        (self as NSString).abbreviatingWithTildeInPath
    }
}
