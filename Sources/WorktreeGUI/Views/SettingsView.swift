import SwiftUI
import WorktreeCore

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    @State private var scanDepth = "3"
    @State private var terminalApp = ""
    @State private var editorApp = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ayarlar").font(.headline)

            // ---- Repo kaynakları ----
            HStack {
                Text("Repo kaynakları").font(.subheadline).bold()
                Spacer()
                Button {
                    state.addReposViaPanel()
                } label: {
                    Label("Finder'dan Ekle", systemImage: "folder.badge.plus")
                }
            }
            Text("Klasör seç: içinde .git olan klasör tek repo, diğerleri içindeki repolar için taranan kök olur.")
                .font(.caption2).foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if state.config.scanRoots.isEmpty && state.config.manualRepos.isEmpty {
                        Text("Henüz kaynak yok. “Finder'dan Ekle” ile başla.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(state.config.scanRoots, id: \.self) { root in
                        sourceRow(path: root, kind: "kök")
                    }
                    ForEach(state.config.manualRepos, id: \.self) { repo in
                        sourceRow(path: repo, kind: "repo")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 140)

            Divider()

            // ---- Diğer ayarlar ----
            Form {
                TextField("Tarama derinliği", text: $scanDepth)
                TextField("Terminal uygulaması", text: $terminalApp)
                TextField("Editör uygulaması", text: $editorApp)
            }

            Text("Repo bazlı env/komut kuralları için config.json'ı elle düzenle:")
                .font(.caption).foregroundStyle(.secondary)
            Text(ConfigStore.defaultPath).font(.system(.caption, design: .monospaced))

            HStack {
                Spacer()
                Button("Kapat") { dismiss() }
                Button("Kaydet") { save() }
            }
        }
        .padding(16)
        .frame(width: 460)
        .onAppear {
            scanDepth = String(state.config.scanDepth)
            terminalApp = state.config.terminalApp
            editorApp = state.config.editorApp
        }
    }

    @ViewBuilder
    private func sourceRow(path: String, kind: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: kind == "repo" ? "shippingbox" : "folder")
            Text(path).font(.caption).lineLimit(1).truncationMode(.middle)
            Text("(\(kind))").font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Button(role: .destructive) { state.removeSource(path) } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
        }
    }

    private func save() {
        state.config.scanDepth = Int(scanDepth) ?? 3
        state.config.terminalApp = terminalApp
        state.config.editorApp = editorApp
        state.saveConfig()
    }
}
