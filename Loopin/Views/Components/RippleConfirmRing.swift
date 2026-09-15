import SwiftUI

/// Ripple Confirm Ring (DESIGN.md §2.2):
/// A single expanding ring from interaction point, 350ms ease-out, fading opacity to 0.
public struct RippleConfirmRing: View {
    let color: Color
    let onComplete: (() -> Void)?

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(color: Color = AppTheme.accentTeal, onComplete: (() -> Void)? = nil) {
        self.color = color
        self.onComplete = onComplete
    }

    public var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                if reduceMotion {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onComplete?()
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.35)) {
                        scale = 1.8
                        opacity = 0.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onComplete?()
                    }
                }
            }
    }
}
