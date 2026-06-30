import SwiftUI
import WorktreeCore

struct MenuContentView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var confirmingRemovalPath: String?

    private func openInFront(id: String) {
        openWindow(id: id)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Worktrees").font(.headline)
                Spacer()
                Button("Yenile") { state.refresh() }
                Button("Ayarlar") { openInFront(id: "settings") }
            }

            if let err = state.lastError {
                Text(err).font(.caption).foregroundStyle(.red).lineLimit(3)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if state.repos.isEmpty {
                        HStack(spacing: 6) {
                            if state.isRefreshing {
                                ProgressView().controlSize(.small)
                                Text("Yükleniyor…").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("Repo bulunamadı. Ayarlar'dan tarama kökünü kontrol et.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    ForEach(state.repos) { repo in
                        repoSection(repo)
                    }
                }
            }
            .frame(maxHeight: 360)

            Divider()
            Button("Çıkış") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 360)
        .onAppear { state.refresh() }
    }

    @ViewBuilder
    private func repoSection(_ repo: Repo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(repo.group)/\(repo.name)").font(.subheadline).bold()
                Spacer()
                Button("+ Yeni") {
                    state.newWorktreeRepoPath = repo.path
                    openInFront(id: "new-worktree")
                }
            }
            ForEach(state.worktreesByRepo[repo.path] ?? []) { wt in
                worktreeRow(repo: repo, wt: wt)
            }
        }
    }

    @ViewBuilder
    private func worktreeRow(repo: Repo, wt: Worktree) -> some View {
        if confirmingRemovalPath == wt.path {
            HStack {
                Text("\(wt.branch) — sil?").font(.caption)
                Spacer()
                Button("Worktree") {
                    state.removeWorktree(repo: repo, worktree: wt, deleteBranch: false)
                    confirmingRemovalPath = nil
                }
                Button("+ Branch") {
                    state.removeWorktree(repo: repo, worktree: wt, deleteBranch: true)
                    confirmingRemovalPath = nil
                }
                Button("İptal") { confirmingRemovalPath = nil }
            }
            .padding(.leading, 8)
        } else {
            HStack {
                Text(wt.branch).font(.caption)
                Spacer()
                Button("Cursor") { state.openEditor(wt.path) }
                Button("Terminal") { state.openTerminal(wt.path) }
                Button("Finder") { state.openFinder(wt.path) }
                Button(role: .destructive) { confirmingRemovalPath = wt.path } label: {
                    Image(systemName: "trash")
                }
            }
            .padding(.leading, 8)
        }
    }
}
