import SwiftUI
import WorktreeCore

struct MenuContentView: View {
    @EnvironmentObject var state: AppState
    @State private var newWorktreeRepo: Repo?
    @State private var showSettings = false
    @State private var pendingRemoval: (repo: Repo, worktree: Worktree)?
    @State private var showRemoveDialog = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Worktrees").font(.headline)
                Spacer()
                Button("Yenile") { state.refresh() }
                Button("Ayarlar") { showSettings = true }
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
        .sheet(item: $newWorktreeRepo) { repo in
            NewWorktreeView(repo: repo).environmentObject(state)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(state)
        }
        .confirmationDialog(
            pendingRemoval.map { "\"\($0.worktree.branch)\" worktree'sini sil" } ?? "Worktree'yi sil",
            isPresented: $showRemoveDialog, titleVisibility: .visible
        ) {
            if let pending = pendingRemoval {
                Button("Worktree'yi sil", role: .destructive) {
                    state.removeWorktree(repo: pending.repo, worktree: pending.worktree, deleteBranch: false)
                }
                Button("Worktree + branch'i sil", role: .destructive) {
                    state.removeWorktree(repo: pending.repo, worktree: pending.worktree, deleteBranch: true)
                }
                Button("İptal", role: .cancel) { }
            }
        }
    }

    @ViewBuilder
    private func repoSection(_ repo: Repo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(repo.group)/\(repo.name)").font(.subheadline).bold()
                Spacer()
                Button("+ Yeni") { newWorktreeRepo = repo }
            }
            ForEach(state.worktreesByRepo[repo.path] ?? []) { wt in
                HStack {
                    Text(wt.branch).font(.caption)
                    Spacer()
                    Button("Cursor") { state.openEditor(wt.path) }
                    Button("Terminal") { state.openTerminal(wt.path) }
                    Button("Finder") { state.openFinder(wt.path) }
                    Button(role: .destructive) {
                        pendingRemoval = (repo, wt)
                        showRemoveDialog = true
                    } label: { Image(systemName: "trash") }
                }
                .padding(.leading, 8)
            }
        }
    }
}
