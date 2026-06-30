import SwiftUI
import WorktreeCore

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    @State private var scanRoots = ""
    @State private var manualRepos = ""
    @State private var scanDepth = "3"
    @State private var terminalApp = ""
    @State private var editorApp = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ayarlar").font(.headline)
            Text("Repo bazlı env/komut kuralları için config.json'ı elle düzenle:")
                .font(.caption).foregroundStyle(.secondary)
            Text(ConfigStore.defaultPath).font(.system(.caption, design: .monospaced))

            Form {
                TextField("Tarama kökleri (virgülle)", text: $scanRoots)
                TextField("Tarama derinliği", text: $scanDepth)
                TextField("Manuel repolar (virgülle)", text: $manualRepos)
                TextField("Terminal uygulaması", text: $terminalApp)
                TextField("Editör uygulaması", text: $editorApp)
            }

            HStack {
                Spacer()
                Button("İptal") { dismiss() }
                Button("Kaydet") { save(); dismiss() }
            }
        }
        .padding(16)
        .frame(width: 420)
        .onAppear {
            scanRoots = state.config.scanRoots.joined(separator: ", ")
            manualRepos = state.config.manualRepos.joined(separator: ", ")
            scanDepth = String(state.config.scanDepth)
            terminalApp = state.config.terminalApp
            editorApp = state.config.editorApp
        }
    }

    private func parseList(_ s: String) -> [String] {
        s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func save() {
        state.config.scanRoots = parseList(scanRoots)
        state.config.manualRepos = parseList(manualRepos)
        state.config.scanDepth = Int(scanDepth) ?? 3
        state.config.terminalApp = terminalApp
        state.config.editorApp = editorApp
        state.saveConfig()
    }
}
