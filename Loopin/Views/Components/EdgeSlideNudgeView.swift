import SwiftUI

/// Edge-Slide Nudge Notification (DESIGN.md §2.3):
/// A slim glow bar sliding in from the right screen edge with a one-line message.
public struct EdgeSlideNudgeView: View {
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color
    let onDismiss: () -> Void

    @State private var offset: CGFloat = 320
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        title: String,
        subtitle: String? = nil,
        icon: String = "bell.fill",
        color: Color = AppTheme.accentTeal,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Accent indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 36)

            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            Button(action: dismissWithAnimation) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 300)
        .background(AppTheme.surfaceElevated)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.25), radius: 12, x: 0, y: 4)
        .offset(x: offset)
        .onAppear {
            if reduceMotion {
                offset = 0
            } else {
                withAnimation(.easeOut(duration: 0.25)) {
                    offset = 0
                }
            }
            // Auto dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                dismissWithAnimation()
            }
        }
    }

    private func dismissWithAnimation() {
        if reduceMotion {
            onDismiss()
        } else {
            withAnimation(.easeIn(duration: 0.20)) {
                offset = 320
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                onDismiss()
            }
        }
    }
}
