import SwiftUI
import TwigCore

/// Pencerenin alt-ortasında beliren geçici bildirim. Tek toast; tıkla-kapat.
struct ToastOverlay: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            Spacer()
            if let toast = state.toasts.last {
                pill(toast)
                    .transition(reduceMotion ? .opacity
                                : .move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 22)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: state.toasts)
        .allowsHitTesting(!state.toasts.isEmpty)
    }

    private func pill(_ toast: Toast) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon(toast.kind))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color(toast.kind))
            Text(toast.message)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        .contentShape(Capsule())
        .onTapGesture { state.dismissToast(toast.id) }
    }

    private func icon(_ kind: ToastKind) -> String {
        switch kind {
        case .success: return "checkmark.circle.fill"
        case .error:   return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    private func color(_ kind: ToastKind) -> Color {
        switch kind {
        case .success: return Theme.dotClean
        case .error:   return Theme.danger
        case .info:    return Theme.accent
        }
    }
}
