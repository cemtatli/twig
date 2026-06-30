import SwiftUI
import WorktreeCore

/// Window root: resolves the repo chosen from the menu and hosts the form.
struct NewWorktreeView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        if let repo = state.repos.first(where: { $0.path == state.newWorktreeRepoPath }) {
            // .id(repo.path) gives a fresh form (reset state) when the repo changes.
            NewWorktreeForm(repo: repo).id(repo.path)
        } else {
            VStack(spacing: 8) {
                Text("Repo seçilmedi").font(.headline)
                Text("Menüden bir reponun yanındaki “+ Yeni”ye bas.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Kapat") { dismiss() }
            }
            .padding(24)
            .frame(width: 420)
        }
    }
}

struct NewWorktreeForm: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    let repo: Repo

    @State private var mode = 0            // 0 = var olan branch, 1 = yeni branch
    @State private var existingBranch = ""
    @State private var newBranch = ""
    @State private var base = ""
    @State private var taskName = ""
    @State private var branches: [String] = []
    @State private var submitted = false

    private var effectiveBranch: String { mode == 0 ? existingBranch : newBranch }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Yeni Worktree — \(repo.name)").font(.headline)

            Picker("", selection: $mode) {
                Text("Var olan branch").tag(0)
                Text("Yeni branch").tag(1)
            }
            .pickerStyle(.segmented)
            .disabled(submitted)

            if mode == 0 {
                Picker("Branch", selection: $existingBranch) {
                    ForEach(branches, id: \.self) { Text($0).tag($0) }
                }
                .onChange(of: existingBranch) { _, new in taskName = new }
            } else {
                TextField("Yeni branch adı", text: $newBranch)
                    .onChange(of: newBranch) { _, new in taskName = new }
                TextField("Base branch", text: $base)
            }

            TextField("Task adı (klasör)", text: $taskName)
                .disabled(submitted)

            if submitted {
                ScrollView {
                    Text(state.log.isEmpty ? "Çalışıyor…" : state.log.joined(separator: "\n"))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 120)
                if let err = state.lastError {
                    Text(err).font(.caption).foregroundStyle(.red).lineLimit(4)
                }
            }

            HStack {
                Spacer()
                if submitted {
                    Button("Kapat") { dismiss() }
                } else {
                    Button("İptal") { dismiss() }
                    Button("Oluştur") {
                        let req = WorktreeRequest(
                            repo: repo, branch: effectiveBranch, taskName: taskName,
                            newBranchBase: mode == 1 ? base : nil)
                        state.createWorktree(req)
                        submitted = true
                    }
                    .disabled(effectiveBranch.isEmpty || taskName.isEmpty)
                }
            }
        }
        .padding(16)
        .frame(width: 420)
        .onAppear {
            branches = state.branches(for: repo)
            existingBranch = branches.first ?? ""
            base = state.defaultBase(for: repo)
            if mode == 0 { taskName = existingBranch }
        }
    }
}
