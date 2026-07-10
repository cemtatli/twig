import SwiftUI
import AppKit

// MARK: - FloatingPanel

/// Keeby yüzen kartı: koyu dolgu, 14pt sürekli köşe, 1px iç kontur.
struct FloatingPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous)
                    .strokeBorder(Theme.panelStroke, lineWidth: 1)
            )
    }
}

// MARK: - IconTile

/// Yuvarlatılmış kare gradient ikon karosu (Keeby sidebar ikonları).
struct IconTile<Glyph: View>: View {
    let color: Color
    var side: CGFloat = 28
    @ViewBuilder var glyph: Glyph

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
                .fill(LinearGradient(colors: [color.brightened(0.18), color],
                                     startPoint: .top, endPoint: .bottom))
            glyph
                .font(.system(size: side * 0.5, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)   // dekoratif — etiket her zaman yanındaki metin
    }
}

extension IconTile where Glyph == Image {
    init(systemName: String, color: Color, side: CGFloat = 28) {
        self.init(color: color, side: side) { Image(systemName: systemName) }
    }
}

extension Color {
    /// Gradient üst durağı için hafif aydınlatma.
    func brightened(_ amount: Double) -> Color {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .white
        return Color(red: min(1, ns.redComponent + amount),
                     green: min(1, ns.greenComponent + amount),
                     blue: min(1, ns.blueComponent + amount))
    }
}

// MARK: - TilePalette

/// Repo sırasına göre karo rengi — `color(at:)` her indeksi palet boyutuna
/// sararak döngüsel erişim sağlar; yan yana repolar her zaman farklı renk alır.
enum TilePalette {
    static let colors: [Color] = [
        Color(red: 0.94, green: 0.31, blue: 0.36),   // kırmızı
        Color(red: 0.96, green: 0.53, blue: 0.19),   // turuncu
        Color(red: 0.28, green: 0.64, blue: 0.97),   // mavi
        Color(red: 0.62, green: 0.42, blue: 0.95),   // mor
        Color(red: 0.22, green: 0.72, blue: 0.51),   // yeşil
        Color(red: 0.91, green: 0.42, blue: 0.72),   // pembe
        Color(red: 0.35, green: 0.73, blue: 0.78),   // camgöbeği
    ]

    /// Sidebar sırasına göre renk — komşu repolar hep farklı karo alır.
    static func color(at index: Int) -> Color {
        colors[((index % colors.count) + colors.count) % colors.count]
    }
}

// MARK: - TwigToggle

/// Keeby kapsül toggle: 44×26, beyaz topuz, açıkken turuncu dolgu.
/// Görsel katman özel; erişilebilirlik gerçek Toggle üzerinden.
struct TwigToggle: View {
    @Binding var isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) { isOn.toggle() }
        } label: {
            Capsule()
                .fill(isOn ? Theme.accent : Color(red: 0.227, green: 0.227, blue: 0.235))
                .frame(width: 44, height: 26)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .padding(2)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle("", isOn: $isOn).labelsHidden() }
    }
}

// MARK: - PillTabBar

/// Keeby pill sekme çubuğu — native segmented picker'ın özel karşılığı
/// (HIG tab-bar deseninin koyu/kapsül yorumu). Seçili sekme turuncu kapsül
/// olarak kayarak gelir; reduce-motion'da animasyonsuz. VoiceOver'a gerçek
/// segmented picker olarak sunulur.
struct PillTabBar: View {
    let items: [String]
    @Binding var selection: Int
    var accessibilityTitle: String = ""
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items.indices, id: \.self) { i in
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                        selection = i
                    }
                } label: {
                    Text(items[i])
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selection == i ? .white : .secondary)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background {
                            if selection == i {
                                Capsule().fill(Theme.accent)
                                    .matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.06), in: Capsule())
        .accessibilityRepresentation {
            Picker(accessibilityTitle, selection: $selection) {
                ForEach(items.indices, id: \.self) { i in
                    Text(items[i]).tag(i)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - PillBadge

/// Koyu kapsül değer rozeti (Keeby "100%" / "⌘K").
struct PillBadge: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(Theme.mono(12, .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}

// MARK: - TagBadge

/// Border'lı (kontur) mini kapsül rozet: opsiyonel ikon + kısa metin, tint
/// rengiyle çerçeve/metin. Git durumu (↑ahead/↓behind/merged) gibi yerlerde
/// kullanılır. `onTap` verilirse tıklanabilir (insert-chip vb.).
struct TagBadge: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = .secondary
    /// true → dolgulu (tint arka plan), false → kontur (border).
    var filled: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        let content = HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 9, weight: .bold))
            }
            Text(text).font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7).padding(.vertical, 2)
        .background {
            if filled { Capsule().fill(tint.opacity(0.16)) }
            else { Capsule().strokeBorder(tint.opacity(0.5), lineWidth: 1) }
        }
        .contentShape(Capsule())

        if let onTap {
            Button(action: onTap) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }
}

// MARK: - BorderedPillButton

/// İkincil kapsül buton — Yenile/New ile aynı krom ailesi: nötr koyu dolgu,
/// hover'da bir ton açılır (eski kontur-only hali buton sistemine uymuyordu).
struct BorderedPillButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 11, weight: .semibold)) }
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Color.white.opacity(hovered ? 0.12 : 0.08), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - DarkTextField

/// Koyu alan kroması — plain TextField üzerine Keeby dolgusu.
struct DarkTextField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: () -> Void = {}
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.white.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onSubmit(onSubmit)
    }
}

// MARK: - SettingsRow

/// Kart içi ayar satırı: solda başlık (+ opsiyonel alt metin), sağda kontrol,
/// altta hairline (karttaki son satır hariç).
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var showsHairline: Bool = true
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 14))
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 12)
                trailing
            }
            .padding(.horizontal, 16)
            .padding(.vertical, subtitle == nil ? 15 : 11)
            .frame(minHeight: 52)
            if showsHairline {
                Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 16)
            }
        }
    }
}
