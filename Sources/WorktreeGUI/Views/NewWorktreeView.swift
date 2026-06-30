import SwiftUI
import WorktreeCore

/// Inline "new worktree" pane shown in the popover's detail area.
struct NewWorktreeForm: View {
    @EnvironmentObject var state: AppState
    let repo: Repo
    let onClose: () -> Void

    @State private var mode = 0            // 0 = var olan branch, 1 = yeni branch
    @State private var existingBranch = ""
    @State private var newBranch = ""
    @State private var base = ""
    @State private var taskName = ""
    @State private var branches: [String] = []
    @State private var submitted = false

    private var effectiveBranch: String { mode == 0 ? existingBranch : newBranch }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Yeni Worktree")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(repo.name).font(Theme.mono(10)).foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Picker("", selection: $mode) {
                    Text("Var olan branch").tag(0)
                    Text("Yeni branch").tag(1)
                }
                .pickerStyle(.segmented).labelsHidden()
                .disabled(submitted)

                if mode == 0 {
                    labeled("Branch") {
                        Picker("", selection: $existingBranch) {
                            ForEach(branches, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        .onChange(of: existingBranch) { _, new in taskName = new }
                    }
                } else {
                    labeled("Yeni branch adı") {
                        TextField("ör. feat/randevu", text: $newBranch)
                            .textFieldStyle(.roundedBorder).font(Theme.mono(12))
                            .onChange(of: newBranch) { _, new in taskName = new }
                    }
                    labeled("Base branch (kopyalanacak)") {
                        Picker("", selection: $base) {
                            ForEach(branches, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    }
                }

                labeled("Task adı (klasör)") {
                    TextField("ör. randevu", text: $taskName)
                        .textFieldStyle(.roundedBorder).font(Theme.mono(12))
                }

                if submitted {
                    ScrollView {
                        Text(state.log.isEmpty ? "Çalışıyor…" : state.log.joined(separator: "\n"))
                            .font(Theme.mono(10)).foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 120)
                    .background(Theme.hover, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.hairline, lineWidth: 1))
                    if let err = state.lastError {
                        Text(err).font(Theme.mono(10)).foregroundStyle(Theme.danger).lineLimit(4)
                    }
                }

                HStack(spacing: 8) {
                    if submitted {
                        Button("Kapat") { onClose() }.buttonStyle(AccentPill())
                        Spacer()
                    } else {
                        Button("Vazgeç") { onClose() }.buttonStyle(GhostPill())
                        Spacer()
                        Button {
                            let req = WorktreeRequest(
                                repo: repo, branch: effectiveBranch, taskName: taskName,
                                newBranchBase: mode == 1 ? base : nil)
                            state.createWorktree(req)
                            submitted = true
                        } label: {
                            Label("Oluştur", systemImage: "plus")
                        }
                        .buttonStyle(AccentPill())
                        .disabled(effectiveBranch.isEmpty || taskName.isEmpty)
                        .opacity(effectiveBranch.isEmpty || taskName.isEmpty ? 0.4 : 1)
                    }
                }
                .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            branches = state.branches(for: repo)
            existingBranch = branches.first ?? ""
            base = preferredBase(from: branches)
            if mode == 0 { taskName = existingBranch }
        }
    }

    /// Pick a sensible base branch: the configured default if it exists,
    /// otherwise master, then main, then the first available branch.
    private func preferredBase(from branches: [String]) -> String {
        let configured = state.defaultBase(for: repo)
        for candidate in [configured, "master", "main"] where branches.contains(candidate) {
            return candidate
        }
        return branches.first ?? configured
    }

    @ViewBuilder
    private func labeled<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(Theme.mono(9, .medium)).tracking(0.5)
                .foregroundStyle(Theme.textTertiary)
            content()
        }
    }
}
