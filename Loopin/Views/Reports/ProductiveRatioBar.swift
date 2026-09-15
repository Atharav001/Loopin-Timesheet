import SwiftUI

/// Stacked Productive vs. Neutral vs. Wasteful Horizontal Ratio Bar (DESIGN.md §3.4):
/// Designed as a single stacked bar rather than a pie chart for effortless day-to-day comparison.
public struct ProductiveRatioBar: View {
    let productiveSeconds: TimeInterval
    let neutralSeconds: TimeInterval
    let wastefulSeconds: TimeInterval

    private var totalSeconds: TimeInterval {
        max(1, productiveSeconds + neutralSeconds + wastefulSeconds)
    }

    private var productiveFraction: Double { productiveSeconds / totalSeconds }
    private var neutralFraction: Double { neutralSeconds / totalSeconds }
    private var wastefulFraction: Double { wastefulSeconds / totalSeconds }

    public init(
        productiveSeconds: TimeInterval,
        neutralSeconds: TimeInterval,
        wastefulSeconds: TimeInterval
    ) {
        self.productiveSeconds = productiveSeconds
        self.neutralSeconds = neutralSeconds
        self.wastefulSeconds = wastefulSeconds
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("Productivity Ratio")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Text("\(formatHours(totalSeconds)) total tracked")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppTheme.textSecondary)
            }

            // Stacked Bar
            GeometryReader { geo in
                let width = geo.size.width
                HStack(spacing: 2) {
                    if productiveFraction > 0.01 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ProductivityCategory.productive.color)
                            .frame(width: max(4, width * CGFloat(productiveFraction)))
                    }
                    if neutralFraction > 0.01 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ProductivityCategory.neutral.color)
                            .frame(width: max(4, width * CGFloat(neutralFraction)))
                    }
                    if wastefulFraction > 0.01 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ProductivityCategory.wasteful.color)
                            .frame(width: max(4, width * CGFloat(wastefulFraction)))
                    }
                }
            }
            .frame(height: 18)
            .background(AppTheme.surface)
            .cornerRadius(4)

            // Percentage Badges & Stats
            HStack(spacing: 16) {
                ratioPill(
                    title: "Productive",
                    percentage: Int(productiveFraction * 100),
                    duration: productiveSeconds,
                    color: ProductivityCategory.productive.color
                )

                ratioPill(
                    title: "Neutral",
                    percentage: Int(neutralFraction * 100),
                    duration: neutralSeconds,
                    color: ProductivityCategory.neutral.color
                )

                ratioPill(
                    title: "Wasteful",
                    percentage: Int(wastefulFraction * 100),
                    duration: wastefulSeconds,
                    color: ProductivityCategory.wasteful.color
                )
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func ratioPill(title: String, percentage: Int, duration: TimeInterval, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("\(percentage)%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(color)
                }
                Text(formatHours(duration))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }

    private func formatHours(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
