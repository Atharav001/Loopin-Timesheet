import SwiftUI

/// Breathing Glow Modifier (DESIGN.md §2.1 & §5):
/// Soft outer glow (blur radius 12–20pt, opacity 0.25–0.55) on a 2.6s ease-in-out loop.
/// Scales opacity not size. Respects Reduce Motion accessibility setting.
public struct BreathingGlowModifier: ViewModifier {
    let color: Color
    let isActive: Bool
    let isOverdue: Bool

    @State private var isBreathingHigh: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(color: Color, isActive: Bool = true, isOverdue: Bool = false) {
        self.color = color
        self.isActive = isActive
        self.isOverdue = isOverdue
    }

    private var activeColor: Color {
        isOverdue ? Color(hex: "#F59E0B") : color // Warm amber when overdue
    }

    public func body(content: Content) -> some View {
        if !isActive || reduceMotion {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(activeColor.opacity(isActive ? 0.6 : 0.0), lineWidth: 1.5)
                )
        } else {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(activeColor.opacity(isBreathingHigh ? 0.8 : 0.35), lineWidth: 1.5)
                )
                .shadow(
                    color: activeColor.opacity(isBreathingHigh ? 0.55 : 0.25),
                    radius: isBreathingHigh ? 18 : 12,
                    x: 0,
                    y: 0
                )
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 2.6)
                        .repeatForever(autoreverses: true)
                    ) {
                        isBreathingHigh = true
                    }
                }
        }
    }
}

public extension View {
    func breathingGlow(color: Color = AppTheme.accentTeal, isActive: Bool = true, isOverdue: Bool = false) -> some View {
        self.modifier(BreathingGlowModifier(color: color, isActive: isActive, isOverdue: isOverdue))
    }
}
