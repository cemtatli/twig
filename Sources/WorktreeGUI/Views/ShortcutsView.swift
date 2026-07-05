import SwiftUI
import WorktreeCore

/// Kısayollar paneli — eskiden Ayarlar içinde bir section'dı; artık sidebar'da
/// Ayarlar'ın üstünde ayrı bir menü. Salt bilgi: uygulamanın sistem kısayolları.
///
/// Keeby dili: header + tek kart, kart içi satırlar solda eylem adı / sağda tuş
/// pill'i. Her zaman koyu.
struct ShortcutsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    card {
                        shortcutRow(state.t(.newWorktreeTitle), "⌘N")
                        shortcutRow(state.t(.refresh), "⌘R")
                        shortcutRow(state.t(.settingsTitle), "⌘,")
                        shortcutRow(state.t(.quit), "⌘Q")
                        shortcutRow(state.t(.shortcutSelectRepo), "1–9")
                        shortcutRow(state.t(.shortcutCycleRepos), "⇥ ↑ ↓")
                        shortcutRow(state.t(.shortcutCloseEsc), "esc", isLast: true)
                    }
                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: chrome

    private var header: some View {
        HStack(spacing: 8) {
            SidebarToggle()
            IconTile(systemName: "keyboard.fill",
                     color: Color(red: 0.55, green: 0.42, blue: 0.9),
                     side: 30)
            Text(state.t(.shortcutsTitle))
                .font(.system(size: 17, weight: .bold))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    // MARK: rows

    /// Kısayol satırı: solda eylem adı, sağda tuş pill'i (Keeby "⌘K" deseni).
    @ViewBuilder
    private func shortcutRow(_ title: String, _ keys: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                    .lineLimit(1)
                Spacer(minLength: 12)
                PillBadge(keys)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            if !isLast {
                Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 16)
            }
        }
    }

    // MARK: card helper

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color.white.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
