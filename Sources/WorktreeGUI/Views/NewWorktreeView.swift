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
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    SidebarToggle()
                    if state.sidebarCollapsed {
                        TwigMark().frame(width: 18, height: 18)
                            .foregroundStyle(Brand.signalOrange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.t(.newWorktreeTitle))
                            .font(.title3.weight(.semibold))
                        Text(repo.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Branch-mode: native segmented control. Native disabled state
                // dims it during submit, so no manual opacity is needed.
                Picker("", selection: $mode) {
                    Text(state.t(.existingBranch)).tag(0)
                    Text(state.t(.newBranchTab)).tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(submitted)

                if mode == 0 {
                    labeled(state.t(.branch)) {
                        Picker("", selection: $existingBranch) {
                            ForEach(branches, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        .onChange(of: existingBranch) { _, new in taskName = new }
                    }
                } else {
                    labeled(state.t(.newBranchName)) {
                        TextField(state.t(.branchPlaceholder), text: $newBranch)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: newBranch) { _, new in taskName = new }
                    }
                    labeled(state.t(.baseBranch)) {
                        Picker("", selection: $base) {
                            ForEach(branches, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    }
                }

                labeled(state.t(.taskNameFolder)) {
                    TextField(state.t(.taskPlaceholder), text: $taskName)
                        .textFieldStyle(.roundedBorder)
                }

                if submitted {
                    // Terminal log output — mono stays (it is log text), but on a
                    // semantic text-area surface instead of an owned fill color.
                    ScrollView {
                        Text(state.log.isEmpty ? state.t(.working) : state.log.joined(separator: "\n"))
                            .font(Theme.mono(10))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 120)
                    .background(Color(nsColor: .textBackgroundColor),
                                in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    if let err = state.lastError {
                        Text(err)
                            .font(Theme.mono(10))
                            .foregroundStyle(Theme.danger)
                            .lineLimit(4)
                    }
                }

                HStack(spacing: 8) {
                    if submitted {
                        Button(state.t(.close)) { onClose() }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.cancelAction)
                        Spacer()
                    } else {
                        Button(state.t(.cancel)) { onClose() }
                            .buttonStyle(.bordered)
                            .keyboardShortcut(.cancelAction)
                        Spacer()
                        Button {
                            let req = WorktreeRequest(
                                repo: repo, branch: effectiveBranch, taskName: taskName,
                                newBranchBase: mode == 1 ? base : nil)
                            state.createWorktree(req)
                            submitted = true
                        } label: {
                            Label(state.t(.create), systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(effectiveBranch.isEmpty || taskName.isEmpty)
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
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
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content()
        }
    }
}
