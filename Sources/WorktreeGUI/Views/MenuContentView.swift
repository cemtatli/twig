import SwiftUI
import WorktreeCore

struct MenuContentView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var selectedRepoPath: String?
    @State private var confirmingRemovalPath: String?

    private var selectedRepo: Repo? {
        state.repos.first { $0.path == selectedRepoPath } ?? state.repos.first
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(width: 420, height: 380)
        .onAppear { state.refresh() }
    }

    // MARK: Sidebar (repo tabs)

    private var sidebar: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(state.repos) { repo in
                        repoTab(repo)
                    }
                }
                .padding(.vertical, 8)
            }
            Spacer(minLength: 0)
            Divider()
            VStack(spacing: 10) {
                railButton("folder.badge.plus", help: "Repo Ekle") { state.addReposViaPanel() }
                railButton("gearshape", help: "Ayarlar") { openInFront(id: "settings") }
                railButton("power", help: "Çıkış") { NSApplication.shared.terminate(nil) }
            }
            .padding(.vertical, 10)
        }
        .frame(width: 60)
    }

    private func repoTab(_ repo: Repo) -> some View {
        let isSelected = selectedRepo?.path == repo.path
        return Button {
            selectedRepoPath = repo.path
        } label: {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? Color.accentColor : .clear)
                    .frame(width: 3, height: 28)
                Text(initials(repo.name))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
                    )
            }
        }
        .buttonStyle(.plain)
        .help("\(repo.group)/\(repo.name)")
    }

    private func railButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 28)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: Detail (selected repo's worktrees)

    @ViewBuilder
    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let repo = selectedRepo {
                detailHeader(repo)
                if let err = state.lastError {
                    Text(err).font(.caption).foregroundStyle(.red).lineLimit(2)
                        .padding(.horizontal, 14).padding(.bottom, 6)
                }
                Divider()
                worktreeList(repo)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func detailHeader(_ repo: Repo) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(repo.name).font(.headline)
                Text(repo.group).font(.caption2).foregroundStyle(.secondary)
            }
            if state.isRefreshing { ProgressView().controlSize(.small) }
            Spacer()
            Button { state.refresh() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless).help("Yenile")
            Button { newWorktree(repo) } label: {
                Label("Yeni", systemImage: "plus")
            }
            .help("Yeni worktree")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func worktreeList(_ repo: Repo) -> some View {
        let worktrees = state.worktreesByRepo[repo.path] ?? []
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if worktrees.isEmpty {
                    Text("Bu repoda worktree yok. “Yeni” ile bir tane oluştur.")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                }
                ForEach(worktrees) { wt in
                    worktreeRow(repo: repo, wt: wt)
                    Divider().padding(.leading, 14)
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func worktreeRow(repo: Repo, wt: Worktree) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.branch").font(.caption2).foregroundStyle(.secondary)
            Text(wt.branch).font(.callout).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 6)

            if confirmingRemovalPath == wt.path {
                Text("Sil?").font(.caption2).foregroundStyle(.secondary)
                Button("Worktree") {
                    state.removeWorktree(repo: repo, worktree: wt, deleteBranch: false)
                    confirmingRemovalPath = nil
                }.buttonStyle(.borderless).controlSize(.small)
                Button("+Branch") {
                    state.removeWorktree(repo: repo, worktree: wt, deleteBranch: true)
                    confirmingRemovalPath = nil
                }.buttonStyle(.borderless).controlSize(.small).foregroundStyle(.red)
                Button { confirmingRemovalPath = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless).controlSize(.small)
            } else {
                iconButton("chevron.left.forwardslash.chevron.right", help: state.config.editorApp) {
                    state.openEditor(wt.path)
                }
                iconButton("terminal", help: "Terminal") { state.openTerminal(wt.path) }
                iconButton("folder", help: "Finder") { state.openFinder(wt.path) }
                iconButton("trash", help: "Sil") { confirmingRemovalPath = wt.path }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 5)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Repo yok").font(.headline)
            if state.isRefreshing {
                HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Yükleniyor…") }
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Soldaki “Repo Ekle” ile Finder'dan bir klasör seç.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Kökler: \(state.config.scanRoots.joined(separator: ", "))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: Helpers

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help(help)
    }

    private func openInFront(id: String) {
        openWindow(id: id)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func newWorktree(_ repo: Repo) {
        state.newWorktreeRepoPath = repo.path
        openInFront(id: "new-worktree")
    }

    /// Short label for the repo tab — the distinctive part of the name, e.g.
    /// "example-admin" → "AD", "avolabs" → "AV".
    private func initials(_ name: String) -> String {
        let core = name.split(separator: "-").last.map(String.init) ?? name
        return String(core.prefix(2)).uppercased()
    }
}
