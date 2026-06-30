import SwiftUI
import WorktreeCore

struct NewWorktreeView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    let repo: Repo

    @State private var mode = 0            // 0 = var olan branch, 1 = yeni branch
    @State private var existingBranch = ""
    @State private var newBranch = ""
    @State private var base = ""
    @State private var taskName = ""
    @State private var branches: [String] = []

    private var effectiveBranch: String { mode == 0 ? existingBranch : newBranch }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Yeni Worktree — \(repo.name)").font(.headline)

            Picker("", selection: $mode) {
                Text("Var olan branch").tag(0)
                Text("Yeni branch").tag(1)
            }.pickerStyle(.segmented)

            if mode == 0 {
                Picker("Branch", selection: $existingBranch) {
                    ForEach(branches, id: \.self) { Text($0).tag($0) }
                }
                .onChange(of: existingBranch) { _, new in if taskName.isEmpty { taskName = new } }
            } else {
                TextField("Yeni branch adı", text: $newBranch)
                    .onChange(of: newBranch) { _, new in taskName = new }
                TextField("Base branch", text: $base)
            }

            TextField("Task adı (klasör)", text: $taskName)

            if !state.log.isEmpty {
                ScrollView { Text(state.log.joined(separator: "\n")).font(.system(.caption, design: .monospaced)) }
                    .frame(height: 80)
            }

            HStack {
                Spacer()
                Button("İptal") { dismiss() }
                Button("Oluştur") {
                    let req = WorktreeRequest(
                        repo: repo, branch: effectiveBranch, taskName: taskName,
                        newBranchBase: mode == 1 ? base : nil)
                    state.createWorktree(req)
                    dismiss()
                }
                .disabled(effectiveBranch.isEmpty || taskName.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 380)
        .onAppear {
            branches = state.branches(for: repo)
            existingBranch = branches.first ?? ""
            base = state.defaultBase(for: repo)
            if mode == 0 { taskName = existingBranch }
        }
    }
}
