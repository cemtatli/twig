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
    @State private var hoveredRepoPath: String?
    @State private var draggingPath: String?
    @State private var dragTranslation: CGFloat = 0
    @FocusState private var navFocused: Bool

    private let repoRowHeight: CGFloat = 34

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
                    .frame(width: 190)
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
        .frame(width: 540, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
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
        if press.modifiers.contains(.command) {
            switch press.characters {
            case "q": NSApplication.shared.terminate(nil); return .handled
            case ",": withAnimation(selectAnim) { pane = .settings }; return .handled
            default: break
            }
        }
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

    /// Repos grouped by their parent folder, preserving first-appearance order.
    /// The group name becomes a source-list `Section` header (shown once) so the
    /// rows stay single-line — no per-row group repetition. `index` is the repo's
    /// position in `state.repos`, kept for the 1-9 shortcut tooltip.
    private var groupedRepos: [(group: String, repos: [(index: Int, repo: Repo)])] {
        var order: [String] = []
        var map: [String: [(Int, Repo)]] = [:]
        for (i, r) in state.repos.enumerated() {
            if map[r.group] == nil { order.append(r.group) }
            map[r.group, default: []].append((i, r))
        }
        return order.map { (group: $0, repos: map[$0]!) }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            TwigMark()
                .frame(width: 22, height: 22)
                .foregroundStyle(Brand.signalOrange)
                .frame(maxWidth: .infinity)
                .padding(.top, 14).padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(groupedRepos, id: \.group) { section in
                        Text(section.group)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 4)
                        ForEach(Array(section.repos.enumerated()), id: \.element.repo.id) { pos, entry in
                            repoRowView(repo: entry.repo, globalIndex: entry.index,
                                        group: section.group, posInGroup: pos,
                                        groupCount: section.repos.count)
                        }
                    }
                }
                .padding(.horizontal, 6).padding(.bottom, 8)
            }

            Divider()
            HStack(spacing: 4) {
                railButton("folder.badge.plus", label: state.t(.addRepo)) { state.addReposViaPanel() }
                railButton("gearshape", label: state.t(.settings), active: pane == .settings,
                           shortcut: ",") {
                    withAnimation(selectAnim) { pane = .settings }
                }
                Spacer()
                railButton("power", label: state.t(.quit), shortcut: "q") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
        }
        // Material değil düz tint: SwiftUI materyalleri pencere ARKASINI örnekler
        // (kardeş katmandaki opak zemini değil), popover'da masaüstü sızıyordu.
        .background(Color.primary.opacity(0.04))
    }

    /// One repo row. A custom row (not a `List`) so drag-to-reorder can use a
    /// plain `DragGesture` — the system drag/`onMove` machinery gets cancelled by
    /// the transient popover dismissing, but a gesture stays inside the window.
    private func repoRowView(repo: Repo, globalIndex: Int, group: String,
                             posInGroup: Int, groupCount: Int) -> some View {
        let isSelected = pane == .repo && selectedRepo?.path == repo.path
        let isHovered = hoveredRepoPath == repo.path
        let isDragging = draggingPath == repo.path
        return HStack(spacing: 6) {
            RepoDragHandle()
                .opacity(isHovered || isDragging ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12),
                           value: isHovered || isDragging)
                .highPriorityGesture(reorderGesture(repo: repo, group: group,
                                                    posInGroup: posInGroup, groupCount: groupCount))
            Label(repo.name, systemImage: "shippingbox").font(.body)
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .padding(.horizontal, 8)
        .frame(height: repoRowHeight)
        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? AnyShapeStyle(Color(nsColor: .selectedContentBackgroundColor))
                      : isHovered ? AnyShapeStyle(Color.primary.opacity(0.08))
                      : AnyShapeStyle(Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(selectAnim) { selectedRepoPath = repo.path; pane = .repo } }
        .onHover { hovering in hoveredRepoPath = hovering ? repo.path : (isHovered ? nil : hoveredRepoPath) }
        .offset(y: isDragging ? dragTranslation : 0)
        .zIndex(isDragging ? 1 : 0)
        .help("\(group)/\(repo.name)  ·  \(globalIndex + 1)")
        .contextMenu {
            Button(state.t(.moveUp)) {
                withAnimation(selectAnim) {
                    state.moveRepo(path: repo.path, inGroup: group, toGroupIndex: posInGroup - 1)
                }
            }
            .disabled(posInGroup == 0)
            Button(state.t(.moveDown)) {
                withAnimation(selectAnim) {
                    state.moveRepo(path: repo.path, inGroup: group, toGroupIndex: posInGroup + 1)
                }
            }
            .disabled(posInGroup == groupCount - 1)
            Divider()
            Button(state.t(.finder)) { state.openFinder(repo.path) }
        }
    }

    /// Manual reorder: track the vertical drag on the grip, then on release move
    /// the repo by `round(offset / rowHeight)` slots within its group.
    private func reorderGesture(repo: Repo, group: String,
                                posInGroup: Int, groupCount: Int) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                draggingPath = repo.path
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                let slots = Int((value.translation.height / repoRowHeight).rounded())
                let target = posInGroup + slots
                draggingPath = nil
                dragTranslation = 0
                withAnimation(selectAnim) {
                    state.moveRepo(path: repo.path, inGroup: group, toGroupIndex: target)
                }
            }
    }

    private func railButton(_ symbol: String, label: String, active: Bool = false,
                            shortcut: KeyEquivalent? = nil,
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
        .modifier(OptionalShortcut(key: shortcut))
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
                    TwigMark().frame(width: 18, height: 18)
                        .foregroundStyle(Brand.signalOrange)
                }
                Text(repo.name)
                    .font(.title3).fontWeight(.semibold)
                if state.isRefreshing { ProgressView().controlSize(.small).padding(.leading, 2) }
                Spacer()
                Button { state.refresh() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderless).foregroundStyle(.secondary)
                .help(state.t(.refresh)).accessibilityLabel(state.t(.refresh))
                .keyboardShortcut("r")
                Button { withAnimation(selectAnim) { pane = .newWorktree } } label: {
                    Label(state.t(.new), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent).help(state.t(.newWorktreeHelp))
                .keyboardShortcut("n")
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)

            if let err = state.lastError {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(Theme.danger).lineLimit(2)
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
            TwigMark()
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
                .accessibilityLabel(state.t(wt.isDirty ? .statusDirty : .statusClean))
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
        // Satır düzeyinde tooltip — 6pt durum noktası tek başına hover hedefi
        // olamayacak kadar küçük.
        .help(state.t(wt.isDirty ? .statusDirty : .statusClean))
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
            TwigWordmark(size: 22)
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

/// `.keyboardShortcut` kabul eden ama nil'de hiçbir şey eklemeyen sarmalayıcı —
/// railButton'ın opsiyonel kısayol parametresi için.
private struct OptionalShortcut: ViewModifier {
    let key: KeyEquivalent?
    func body(content: Content) -> some View {
        if let key { content.keyboardShortcut(key) } else { content }
    }
}

/// The 2×3 grip shown at a repo row's leading edge — the visible drag affordance
/// for reordering (mirrors the OpenUsage plugin-list handle the user referenced).
/// It is the drag source; the row is the drop target.
private struct RepoDragHandle: View {
    var body: some View {
        HStack(spacing: 2.5) {
            column
            column
        }
        .opacity(0.4)   // inherits the row's foreground (white when selected)
        .frame(width: 16, height: 22)
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
    private var column: some View { VStack(spacing: 2.5) { dot; dot; dot } }
    private var dot: some View { Circle().frame(width: 2.5, height: 2.5) }
}

extension String {
    /// `/Users/example/foo` → `~/foo` for compact display.
    var abbreviatingHome: String {
        (self as NSString).abbreviatingWithTildeInPath
    }
}
