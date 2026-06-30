import SwiftUI
import AppKit
import WorktreeCore

struct MenuContentView: View {
    @EnvironmentObject var state: AppState

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

    var body: some View {
        HStack(spacing: 0) {
            sidebar.background(Theme.railBG)
            Rectangle().fill(Theme.hairline).frame(width: 1)
            detail.frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.panelBG)
        }
        .frame(width: 480, height: 560)
        .focusable()
        .focused($navFocused)
        .focusEffectDisabled()
        .onKeyPress(action: handleKey)
        .onAppear { state.refresh(); navFocused = true }
        .onChange(of: pane) { _, new in if new != .newWorktree { navFocused = true } }
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
        selectedRepoPath = state.repos[i].path; pane = .repo
    }

    private func cycle(_ delta: Int) {
        guard !state.repos.isEmpty else { return }
        let cur = state.repos.firstIndex { $0.path == selectedRepo?.path } ?? 0
        let next = (cur + delta + state.repos.count) % state.repos.count
        selectedRepoPath = state.repos[next].path; pane = .repo
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(state.repos.enumerated()), id: \.element.id) { idx, repo in
                        repoTab(repo, index: idx)
                    }
                }
                .padding(.vertical, 10)
            }
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                railButton("folder.badge.plus", help: "Repo Ekle") { state.addReposViaPanel() }
                railButton("gearshape", help: "Ayarlar", active: pane == .settings) { pane = .settings }
                railButton("power", help: "Çıkış") { NSApplication.shared.terminate(nil) }
            }
            .padding(.vertical, 10)
        }
        .frame(width: 64)
    }

    private func repoTab(_ repo: Repo, index: Int) -> some View {
        let isSelected = pane == .repo && selectedRepo?.path == repo.path
        let isHovered = hoveredRepoPath == repo.path
        let fill: Color = isSelected ? Theme.accent.opacity(0.13)
                        : isHovered ? Theme.hover : .clear
        return Button {
            selectedRepoPath = repo.path; pane = .repo
        } label: {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isSelected ? Theme.accent : .clear)
                    .frame(width: 2.5, height: 20)
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(fill)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(initials(repo.name))
                                .font(Theme.mono(12.5, .semibold))
                                .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                        )
                    if index < 9 {
                        Text("\(index + 1)")
                            .font(Theme.mono(7.5, .medium))
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.top, 3).padding(.trailing, 4)
                    }
                }
            }
            .padding(.trailing, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredRepoPath = $0 ? repo.path : (isHovered ? nil : hoveredRepoPath) }
        .help("\(repo.group)/\(repo.name)  ·  \(index + 1)")
    }

    private func railButton(_ symbol: String, help: String, active: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15))
                .foregroundStyle(active ? Theme.accent : Theme.textSecondary)
                .frame(width: 40, height: 30)
                .background(RoundedRectangle(cornerRadius: 8).fill(active ? Theme.accent.opacity(0.13) : .clear))
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
            if let repo = selectedRepo { NewWorktreeForm(repo: repo, onClose: { pane = .repo }) }
            else { emptyState }
        case .repo:
            if let repo = selectedRepo { repoDetail(repo) } else { emptyState }
        }
    }

    private func repoDetail(_ repo: Repo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(repo.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(repo.group).font(Theme.mono(10)).foregroundStyle(Theme.textTertiary)
                }
                if state.isRefreshing { ProgressView().controlSize(.small) }
                Spacer()
                Button { state.refresh() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain).help("Yenile")
                Button { pane = .newWorktree } label: {
                    Label("Yeni", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.black)
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .background(Capsule().fill(Theme.accent))
                }
                .buttonStyle(.plain).help("Yeni worktree")
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 13)

            if let err = state.lastError {
                Text(err).font(Theme.mono(10.5)).foregroundStyle(Theme.danger).lineLimit(2)
                    .padding(.horizontal, 16).padding(.bottom, 8)
            }
            Rectangle().fill(Theme.hairline).frame(height: 1)

            let worktrees = state.worktreesByRepo[repo.path] ?? []
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if worktrees.isEmpty {
                        emptyWorktrees
                    }
                    ForEach(Array(worktrees.enumerated()), id: \.element.id) { _, wt in
                        worktreeRow(repo: repo, wt: wt)
                    }
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Rectangle().fill(Theme.hairline).frame(height: 1)
            HStack(spacing: 0) {
                Text("\(worktrees.count) worktree").font(Theme.mono(10))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text(repo.path.abbreviatingHome).font(Theme.mono(10))
                    .foregroundStyle(Theme.textTertiary).lineLimit(1).truncationMode(.middle)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyWorktrees: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 22)).foregroundStyle(Theme.textTertiary)
            Text("Henüz worktree yok").font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Text("\u{201C}Yeni\u{201D} ile ilk worktree'yi oluştur").font(Theme.mono(10))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 36)
    }

    @ViewBuilder
    private func worktreeRow(repo: Repo, wt: Worktree) -> some View {
        let hovered = hoveredPath == wt.path
        HStack(spacing: 11) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(hovered ? Theme.accent : Theme.textTertiary)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(wt.branch).font(Theme.mono(12.5))
                    .foregroundStyle(Theme.textPrimary).lineLimit(1).truncationMode(.middle)
                Text(folderName(wt.path)).font(Theme.mono(9.5))
                    .foregroundStyle(Theme.textTertiary).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)

            if confirmingRemovalPath == wt.path {
                Text("Sil?").font(Theme.mono(10)).foregroundStyle(Theme.textSecondary)
                pillButton("Worktree") {
                    state.removeWorktree(repo: repo, worktree: wt, deleteBranch: false); confirmingRemovalPath = nil
                }
                pillButton("+ Branch", danger: true) {
                    state.removeWorktree(repo: repo, worktree: wt, deleteBranch: true); confirmingRemovalPath = nil
                }
                rowAction("xmark", help: "Vazgeç") { confirmingRemovalPath = nil }
            } else {
                HStack(spacing: 2) {
                    rowAction("chevron.left.forwardslash.chevron.right",
                              app: state.config.editorApp,
                              help: state.config.editorApp) { state.openEditor(wt.path) }
                    rowAction("terminal", app: state.config.terminalApp,
                              help: state.config.terminalApp) { state.openTerminal(wt.path) }
                    rowAction("folder", help: "Finder") { state.openFinder(wt.path) }
                    rowAction("trash", help: "Sil", danger: true) { confirmingRemovalPath = wt.path }
                }
                .opacity(hovered ? 1 : 0)
                .animation(.easeOut(duration: 0.12), value: hovered)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
        .background(hovered ? Theme.hover : .clear)
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.accent)
                .frame(width: 2)
                .opacity(hovered ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onHover { hovering in hoveredPath = hovering ? wt.path : (hovered ? nil : hoveredPath) }
        .animation(.easeOut(duration: 0.1), value: hovered)
    }

    // MARK: Action buttons — one uniform, ghost, monochrome family

    private func rowAction(_ symbol: String, app: String? = nil, help: String, danger: Bool = false,
                           action: @escaping () -> Void) -> some View {
        RowActionButton(symbol: symbol, appName: app, danger: danger, action: action).help(help)
    }

    private func pillButton(_ title: String, danger: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Theme.mono(10, .medium))
                .foregroundStyle(danger ? Theme.danger : Theme.textSecondary)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Capsule().fill(Theme.hover))
                .overlay(Capsule().strokeBorder(
                    (danger ? Theme.danger : Theme.textSecondary).opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func folderName(_ path: String) -> String {
        (path as NSString).lastPathComponent
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 9) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 28)).foregroundStyle(Theme.textTertiary)
            Text("Repo yok").font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            if state.isRefreshing {
                HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Yükleniyor…") }
                    .font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
            } else {
                Text("Soldaki \u{201C}Repo Ekle\u{201D} ile bir klasör seç")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                Text(state.config.scanRoots.joined(separator: ", "))
                    .font(Theme.mono(9.5)).foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func initials(_ name: String) -> String {
        let core = name.split(separator: "-").last.map(String.init) ?? name
        return String(core.prefix(2)).uppercased()
    }
}

/// A row action: ghost by default, brightens to primary (or danger) only when
/// the pointer is over it. Keeps the resting row quiet — actions surface on
/// intent, not by shouting.
private struct RowActionButton: View {
    let symbol: String
    var appName: String? = nil
    var danger: Bool = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            icon
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 6)
                    .fill(hovering ? Theme.hover : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var icon: some View {
        // Show the real app logo when we have one (editor/terminal); otherwise a
        // monochrome symbol. Either way the container is identical, so the row of
        // actions reads as one uniform family.
        if let app = appName, let img = AppIconCache.icon(app) {
            Image(nsImage: img).resizable().frame(width: 15, height: 15)
                .opacity(hovering ? 1 : 0.8)
        } else {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovering ? (danger ? Theme.danger : Theme.textPrimary)
                                          : Theme.textSecondary)
        }
    }
}

/// Caches resolved macOS app icons by app name.
private enum AppIconCache {
    private static var cache: [String: NSImage] = [:]
    static func icon(_ name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        let ws = NSWorkspace.shared
        var path = ws.fullPath(forApplication: name)
        if path == nil {
            let guess = "/Applications/\(name).app"
            if FileManager.default.fileExists(atPath: guess) { path = guess }
        }
        guard let path else { return nil }
        let icon = ws.icon(forFile: path)
        cache[name] = icon
        return icon
    }
}

extension String {
    /// `/Users/example/foo` → `~/foo` for compact display.
    var abbreviatingHome: String {
        (self as NSString).abbreviatingWithTildeInPath
    }
}
