import SwiftUI
import AppKit
import TwigCore

struct MenuContentView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Pane: Equatable { case repo, settings, shortcuts, newWorktree, repoConfig }
    @State private var pane: Pane = .repo
    @State private var selectedRepoPath: String?
    @State private var confirmingRemovalPath: String?
    @State private var showCleanMergedConfirm = false
    @State private var hoveredSection: String?
    @State private var appeared = false
    @State private var hoveredPath: String?
    @State private var hoveredRepoPath: String?
    @FocusState private var navFocused: Bool

    private let repoRowHeight: CGFloat = 38

    private var selectedRepo: Repo? {
        state.repos.first { $0.path == selectedRepoPath } ?? state.repos.first
    }

    private var selectAnim: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.22)
    }

    var body: some View {
        HStack(spacing: 10) {
            if !state.sidebarCollapsed {
                sidebar
                    .frame(width: 230)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            FloatingPanel { detail.id(pane).transition(paneTransition) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(10)
        .frame(width: 780, height: 560)
        .background(Theme.canvas)
        .overlay { if !state.config.onboardingCompleted { OnboardingView() } }
        .overlay(ToastOverlay())
        // Menubar popover açılışı: üstten hafif düşerek + solarak gelir.
        .scaleEffect(reduceMotion ? 1 : (appeared ? 1 : 0.96), anchor: .top)
        .opacity(reduceMotion ? 1 : (appeared ? 1 : 0))
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .focusable()
        .focused($navFocused)
        .focusEffectDisabled()
        .onKeyPress(action: handleKey)
        .onAppear {
            state.refresh(); navFocused = true
            appeared = false
            withAnimation(.snappy(duration: 0.24)) { appeared = true }
        }
        .onDisappear { appeared = false }
        .onChange(of: pane) { _, new in if new != .newWorktree { navFocused = true } }
        .onChange(of: state.repos.count) { _, _ in
            if selectedRepoPath == nil { selectedRepoPath = state.repos.first?.path }
        }
        // Ağır per-worktree durumu yalnız seçili repo için lazy yükle.
        .onChange(of: selectedRepoPath) { _, _ in if let r = selectedRepo { state.loadStatus(for: r) } }
        .onChange(of: state.isRefreshing) { _, refreshing in
            if !refreshing, let r = selectedRepo { state.loadStatus(for: r) }
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
        // Repo/worktree gezinme kısayolları (1-9, ok/tab) yalnız repo listesi
        // pane'inde. Ayarlar/Kısayollar/Yeni/Config pane'lerinde çalışsalar
        // kullanıcıyı o ekrandan istemeden çıkarıyorlardı.
        guard pane == .repo else { return .ignored }
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

    // MARK: Sidebar — two stacked floating cards

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
        VStack(spacing: 10) {
            FloatingPanel {
                VStack(spacing: 0) {
                    TwigWordmark(size: 15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 6)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            // Favoriler — en üstte sabit. Repolar grubunda da kalır.
                            let favorites = state.favoriteRepos
                            if !favorites.isEmpty {
                                let favKey = AppState.favoritesSectionKey
                                sectionHeader(state.t(.favoritesSection), key: favKey)
                                if !state.isSectionCollapsed(favKey) {
                                    ForEach(favorites) { repo in
                                        repoRowView(repo: repo, globalIndex: repoIndex(repo),
                                                    group: repo.group, posInGroup: 0,
                                                    groupCount: 1, inFavorites: true)
                                    }
                                }
                            }
                            ForEach(groupedRepos, id: \.group) { section in
                                sectionHeader(section.group, key: section.group)
                                if !state.isSectionCollapsed(section.group) {
                                    ForEach(Array(section.repos.enumerated()), id: \.element.repo.id) { pos, entry in
                                        repoRowView(repo: entry.repo, globalIndex: entry.index,
                                                    group: section.group, posInGroup: pos,
                                                    groupCount: section.repos.count)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8).padding(.bottom, 8)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingPanel {
                VStack(spacing: 0) {
                    utilityRow(symbol: "folder.badge.plus", tile: Color(red: 0.28, green: 0.64, blue: 0.97),
                               label: state.t(.addRepo)) { state.addReposViaPanel() }
                    Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 52)
                    utilityRow(symbol: "keyboard.fill", tile: Color(red: 0.55, green: 0.42, blue: 0.9),
                               label: state.t(.shortcutsTitle), active: pane == .shortcuts) {
                        withAnimation(selectAnim) { pane = .shortcuts }
                    }
                    Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 52)
                    utilityRow(symbol: "gearshape.fill", tile: Color(white: 0.45),
                               label: state.t(.settings), active: pane == .settings, shortcut: ",") {
                        withAnimation(selectAnim) { pane = .settings }
                    }
                    Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 52)
                    utilityRow(symbol: "power", tile: Color(red: 0.94, green: 0.31, blue: 0.36),
                               label: state.t(.quit), shortcut: "q") {
                        NSApplication.shared.terminate(nil)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func utilityRow(symbol: String, tile: Color, label: String,
                            active: Bool = false, shortcut: KeyEquivalent? = nil,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                IconTile(systemName: symbol, color: tile, side: 26)
                Text(label).font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(active ? Theme.rowSelected : .clear,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .help(label)
        .accessibilityLabel(label)
        .modifier(OptionalShortcut(key: shortcut))
    }

    /// One repo row. Sıralama yalnız context menüden (Yukarı/Aşağı Taşı) —
    /// grip'li drag-to-reorder popover içinde güvenilir çalışmadığı için
    /// kaldırıldı.
    /// Section başlığı — tıkla katla/aç. Chevron en sağda; hover'da satır
    /// hafif arka plan alır. Grup ve Favoriler için ortak stil.
    private func sectionHeader(_ title: String, key: String) -> some View {
        let collapsed = state.isSectionCollapsed(key)
        let hovered = hoveredSection == key
        return Button {
            withAnimation(selectAnim) { state.toggleSection(key) }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(collapsed ? 0 : 90))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(hovered ? Theme.rowHover : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .onHover { hovering in hoveredSection = hovering ? key : (hovered ? nil : hoveredSection) }
    }

    private func repoRowView(repo: Repo, globalIndex: Int, group: String,
                             posInGroup: Int, groupCount: Int,
                             inFavorites: Bool = false) -> some View {
        let isSelected = pane == .repo && selectedRepo?.path == repo.path
        let isHovered = hoveredRepoPath == repo.path
        let favorite = state.isFavorite(repo)
        return HStack(spacing: 8) {
            IconTile(systemName: "folder.fill",
                     color: TilePalette.color(at: globalIndex), side: 26)
            Text(repo.name).font(.system(size: 13, weight: .medium))
            Spacer(minLength: 0)
            if favorite && inFavorites {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.accent)
                    .opacity(isHovered ? 1 : 0.55)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, 10)
        .frame(height: repoRowHeight)
        .foregroundStyle(.primary)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Theme.rowSelected
                      : isHovered ? Theme.rowHover
                      : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(selectAnim) { selectedRepoPath = repo.path; pane = .repo } }
        .onHover { hovering in hoveredRepoPath = hovering ? repo.path : (isHovered ? nil : hoveredRepoPath) }
        .help("\(group)/\(repo.name)  ·  \(globalIndex + 1)")
        .contextMenu {
            Button(favorite ? state.t(.removeFavorite) : state.t(.addFavorite),
                   systemImage: favorite ? "star.slash" : "star") {
                state.toggleFavorite(repo)
            }
            if !inFavorites {
                Divider()
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
            }
            Divider()
            Button(state.t(.pruneStale), systemImage: "sparkles") { state.pruneStale(repo: repo) }
            Button(state.t(.finder)) { state.openFinder(repo.path) }
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        switch pane {
        case .settings:
            SettingsView()
        case .shortcuts:
            ShortcutsView()
        case .newWorktree:
            if let repo = selectedRepo { NewWorktreeForm(repo: repo, onClose: { withAnimation(selectAnim) { pane = .repo } }) }
            else { emptyState }
        case .repoConfig:
            if let repo = selectedRepo { RepoConfigSheet(repo: repo, onClose: { withAnimation(selectAnim) { pane = .repo } }) }
            else { emptyState }
        case .repo:
            if let repo = selectedRepo { repoDetail(repo) } else { emptyState }
        }
    }

    /// Reponun `state.repos` içindeki sırası — karo rengi sidebar'la aynı kalsın.
    private func repoIndex(_ repo: Repo) -> Int {
        state.repos.firstIndex { $0.path == repo.path } ?? 0
    }

    private func repoDetail(_ repo: Repo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                SidebarToggle()
                IconTile(systemName: "folder.fill",
                         color: TilePalette.color(at: repoIndex(repo)), side: 30)
                Text(repo.name)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                // Repo ayarları (env/setup/tip/base/path/PM) — detail pane.
                Button { withAnimation(selectAnim) { pane = .repoConfig } } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 16, height: 16)
                        .padding(.horizontal, 11).padding(.vertical, 7)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .help(state.t(.repoConfigTitle)).accessibilityLabel(state.t(.repoConfigTitle))
                // Yenile — New kapsülüyle aynı boy/krom. Yenileme sırasında ok
                // yerine AYNI çerçevede spinner: başlık yanına ayrı spinner
                // koymak header'ı sıkıştırıp taşırıyordu.
                Button { state.refresh() } label: {
                    Group {
                        if state.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .frame(width: 16, height: 16)
                    .padding(.horizontal, 11).padding(.vertical, 7)
                    .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(state.isRefreshing)
                .help(state.t(.refresh)).accessibilityLabel(state.t(.refresh))
                .keyboardShortcut("r")
                // Merged temizle — yalnız silinebilir (merged+temiz) worktree varsa.
                let cleanCount = state.mergedCleanCount(for: repo)
                if cleanCount > 0 {
                    Button { showCleanMergedConfirm = true } label: {
                        Label("\(state.t(.cleanMerged)) (\(cleanCount))", systemImage: "trash.slash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(state.t(.cleanMerged))
                }
                Button { withAnimation(selectAnim) { pane = .newWorktree } } label: {
                    Label(state.t(.new), systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .help(state.t(.newWorktreeHelp))
                .keyboardShortcut("n")
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)
            .confirmationDialog(cleanMergedTitle(repo),
                                isPresented: $showCleanMergedConfirm, titleVisibility: .visible) {
                Button("\(state.t(.cleanMerged)) (\(state.mergedCleanCount(for: repo)))", role: .destructive) {
                    state.cleanMergedWorktrees(repo: repo)
                }
                Button(state.t(.cancel), role: .cancel) {}
            }

            Rectangle().fill(Theme.hairline).frame(height: 1)

            let worktrees = state.worktreesByRepo[repo.path] ?? []
            ScrollView {
                LazyVStack(spacing: 0) {
                    if worktrees.isEmpty {
                        emptyWorktrees
                    }
                    ForEach(Array(worktrees.enumerated()), id: \.element.id) { idx, wt in
                        worktreeRow(repo: repo, wt: wt)
                        if idx < worktrees.count - 1 {
                            Rectangle().fill(Theme.hairline).frame(height: 1)
                                .padding(.leading, 16)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Rectangle().fill(Theme.hairline).frame(height: 1)
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
                .foregroundStyle(Theme.accent)
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
            syncBadge(wt.sync)
            if state.devPort(for: repo) != nil, wt.devRunning {
                TagBadge(text: state.t(.devRunning), systemImage: "circle.fill",
                         tint: Theme.dotClean, filled: true)
            }
            Spacer(minLength: 8)

            if confirmingRemovalPath == wt.path {
                if wt.isDirty {
                    // Dirty worktree: normal remove patlar → uyarı + zorla sil.
                    Label(state.t(.dirtyDeleteWarning), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(Theme.danger).labelStyle(.titleAndIcon)
                    pillButton(state.t(.forceDelete), danger: true) {
                        state.removeWorktree(repo: repo, worktree: wt, deleteBranch: true, force: true)
                        confirmingRemovalPath = nil
                    }
                } else {
                    Text(state.t(.deletePrompt)).font(.caption).foregroundStyle(.secondary)
                    pillButton(state.t(.worktreeWord)) {
                        state.removeWorktree(repo: repo, worktree: wt, deleteBranch: false); confirmingRemovalPath = nil
                    }
                    pillButton(state.t(.branchPlus), danger: true) {
                        state.removeWorktree(repo: repo, worktree: wt, deleteBranch: true); confirmingRemovalPath = nil
                    }
                }
                rowAction("xmark", help: state.t(.cancel)) { confirmingRemovalPath = nil }
            } else {
                HStack(spacing: 5) {
                    if state.devPort(for: repo) != nil {
                        rowAction("globe", help: state.t(.devOpenBrowser)) {
                            state.openDevServer(repo: repo, worktree: wt)
                        }
                        if wt.devRunning {
                            rowAction("stop.circle", help: state.t(.devStop), danger: true) {
                                state.stopDevServer(repo: repo, worktree: wt)
                            }
                        }
                    }
                    rowAction("chevron.left.forwardslash.chevron.right",
                              help: state.config.editorApp) { state.openEditor(wt.path) }
                    rowAction("terminal",
                              help: state.config.terminalApp) { state.openTerminal(wt.path) }
                    rowAction("folder", help: state.t(.finder)) { state.openFinder(wt.path) }
                    rowAction("trash", help: state.t(.delete), danger: true) { confirmingRemovalPath = wt.path }
                }
                // Kayarak + solarak gelir; reduce-motion'da yalnız opaklık.
                .opacity(hovered ? 1 : 0)
                .offset(x: hovered || reduceMotion ? 0 : 8)
                .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: hovered)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(hovered ? Theme.rowHover : .clear)
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

    // MARK: Row controls — Keeby krom ikon butonlar

    private func rowAction(_ symbol: String, help: String, danger: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(danger ? AnyShapeStyle(Theme.danger) : AnyShapeStyle(.primary))
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(danger ? Theme.danger.opacity(0.16)
                                         : Color.white.opacity(0.08))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
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

    /// Merged temizle onay başlığı — silinecek sayı + dirty atlanan not.
    private func cleanMergedTitle(_ repo: Repo) -> String {
        let clean = state.mergedCleanCount(for: repo)
        let dirty = state.mergedDirtyCount(for: repo)
        var s = "\(clean) merged worktree + branch silinecek."
        if dirty > 0 { s += " \(dirty) tanesi kaydedilmemiş değişiklik nedeniyle atlanacak." }
        return s
    }

    /// Base'e göre senkron rozeti. merged → yeşil; ahead/behind → gri sayaç.
    /// even/unknown → rozet yok.
    @ViewBuilder
    private func syncBadge(_ status: SyncStatus) -> some View {
        switch status {
        case .merged:
            TagBadge(text: state.t(.syncMerged), systemImage: "checkmark", tint: Theme.dotClean, filled: true)
        case .ahead(let n):
            TagBadge(text: "\(n)", systemImage: "arrow.up", tint: Theme.dotClean, filled: true)   // yeşil: önde
        case .behind(let m):
            TagBadge(text: "\(m)", systemImage: "arrow.down", tint: Theme.danger, filled: true)   // kırmızı: geride
        case .diverged(let a, let b):
            HStack(spacing: 3) {
                TagBadge(text: "\(a)", systemImage: "arrow.up", tint: Theme.dotClean, filled: true)
                TagBadge(text: "\(b)", systemImage: "arrow.down", tint: Theme.danger, filled: true)
            }
        case .even, .unknown:
            EmptyView()
        }
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
/// utilityRow'un opsiyonel kısayol parametresi için.
private struct OptionalShortcut: ViewModifier {
    let key: KeyEquivalent?
    func body(content: Content) -> some View {
        if let key { content.keyboardShortcut(key) } else { content }
    }
}

extension String {
    /// `/Users/you/foo` → `~/foo` for compact display.
    var abbreviatingHome: String {
        (self as NSString).abbreviatingWithTildeInPath
    }
}
