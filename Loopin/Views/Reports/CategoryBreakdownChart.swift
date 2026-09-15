import SwiftUI

public struct CategoryStat: Identifiable {
    public var id: String { category }
    public let category: String
    public let productivity: ProductivityCategory
    public let totalSeconds: TimeInterval
    public let count: Int
}

/// Category Breakdown Bar Chart (DESIGN.md §3.4):
/// Horizontal bars displaying time spent per category.
public struct CategoryBreakdownChart: View {
    let stats: [CategoryStat]
    private var maxSeconds: TimeInterval {
        stats.map { $0.totalSeconds }.max() ?? 1.0
    }

    public init(stats: [CategoryStat]) {
        self.stats = stats.sorted { $0.totalSeconds > $1.totalSeconds }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Breakdown")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            if stats.isEmpty {
                Text("No categorized logs for this period.")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 8) {
                    ForEach(stats) { item in
                        categoryRow(item: item)
                    }
                }
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

    private func categoryRow(item: CategoryStat) -> some View {
        VStack(spacing: 4) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.productivity.color)
                        .frame(width: 6, height: 6)

                    Text(item.category)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }

                Spacer()

                Text("\(formatHours(item.totalSeconds)) (\(item.count) blocks)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppTheme.textSecondary)
            }

            // Progress bar
            GeometryReader { geo in
                let fraction = maxSeconds > 0 ? CGFloat(item.totalSeconds / maxSeconds) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.surfaceElevated)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(item.productivity.color)
                        .frame(width: max(4, geo.size.width * fraction), height: 6)
                }
            }
            .frame(height: 6)
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
