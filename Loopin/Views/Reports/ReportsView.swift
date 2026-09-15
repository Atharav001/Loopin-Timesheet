import SwiftUI

public enum ReportPeriod: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case week = "Last 7 Days"
    case month = "This Month"
}

public struct ReportsView: View {
    @EnvironmentObject private var timesheetStore: TimesheetStore
    @State private var selectedPeriod: ReportPeriod = .today

    public init() {}

    public var body: some View {
        let entries = filteredEntries()
        let loggedEntries = entries.filter { $0.kind == .logged && !$0.isSkipped }

        let productiveSecs = loggedEntries.filter { $0.productivity == .productive }.reduce(0.0) { $0 + $1.duration }
        let neutralSecs = loggedEntries.filter { $0.productivity == .neutral }.reduce(0.0) { $0 + $1.duration }
        let wastefulSecs = loggedEntries.filter { $0.productivity == .wasteful }.reduce(0.0) { $0 + $1.duration }
        let totalSecs = productiveSecs + neutralSecs + wastefulSecs

        let categoryStats = computeCategoryStats(entries: loggedEntries)

        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                // Period Selector Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Time & Focus Reports")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Empirical breakdown of where your time actually went.")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    Picker("", selection: $selectedPeriod) {
                        ForEach(ReportPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }

                // Summary Stats Grid
                HStack(spacing: 10) {
                    summaryStatCard(
                        title: "Total Tracked",
                        value: formatDuration(totalSecs),
                        subtitle: "\(loggedEntries.count) sessions",
                        icon: "clock.fill",
                        color: AppTheme.accentTeal
                    )

                    summaryStatCard(
                        title: "Deep Work",
                        value: formatDuration(productiveSecs),
                        subtitle: "\(Int(totalSecs > 0 ? (productiveSecs / totalSecs * 100) : 0))% of time",
                        icon: "flame.fill",
                        color: ProductivityCategory.productive.color
                    )

                    summaryStatCard(
                        title: "Distractions",
                        value: formatDuration(wastefulSecs),
                        subtitle: "\(Int(totalSecs > 0 ? (wastefulSecs / totalSecs * 100) : 0))% of time",
                        icon: "clock.arrow.circlepath",
                        color: ProductivityCategory.wasteful.color
                    )
                }

                // Productive vs. Wasteful Stacked Bar
                ProductiveRatioBar(
                    productiveSeconds: productiveSecs,
                    neutralSeconds: neutralSecs,
                    wastefulSeconds: wastefulSecs
                )

                // Category Breakdown Chart
                CategoryBreakdownChart(stats: categoryStats)

                // Peak Focus Hours Heatmap
                peakFocusHoursSection(entries: loggedEntries)

                // Future AI Brief Reserved Slot (DESIGN.md §3.4: clearly separated placeholder)
                aiBriefReservedSlot
            }
            .padding(16)
        }
        .background(AppTheme.background)
    }

    // MARK: - Subviews

    private func summaryStatCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                Spacer()
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func peakFocusHoursSection(entries: [TimesheetEntry]) -> some View {
        var hourCounts = Array(repeating: 0, count: 24)
        for entry in entries where entry.productivity == .productive {
            let hour = Calendar.current.component(.hour, from: entry.startAt)
            if hour >= 0 && hour < 24 {
                hourCounts[hour] += 1
            }
        }
        let maxCount = max(1, hourCounts.max() ?? 1)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Peak Focus Hours")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(6..<24, id: \.self) { hour in
                    let count = hourCounts[hour]
                    let fraction = CGFloat(count) / CGFloat(maxCount)

                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(count > 0 ? AppTheme.accentTeal.opacity(0.3 + Double(fraction) * 0.7) : AppTheme.surfaceElevated)
                            .frame(height: max(4, 36 * fraction))

                        Text(String(format: "%02d", hour))
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            .frame(height: 54)
        }
        .padding(14)
        .background(AppTheme.surface)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var aiBriefReservedSlot: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundColor(AppTheme.accentViolet)

            VStack(alignment: .leading, spacing: 2) {
                Text("AI Daily Insights")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Text("Script-classified logs ready. Local pattern summaries & AI briefs can be enabled in future phases.")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Text("Coming Soon")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppTheme.accentViolet.opacity(0.15))
                .foregroundColor(AppTheme.accentViolet)
                .cornerRadius(4)
        }
        .padding(12)
        .background(AppTheme.surfaceElevated.opacity(0.6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(AppTheme.accentViolet.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }

    // MARK: - Helpers

    private func filteredEntries() -> [TimesheetEntry] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .today:
            return timesheetStore.entries
        case .yesterday:
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return [] }
            let start = calendar.startOfDay(for: yesterday)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
            return SQLiteManager.shared.fetchEntries(from: start, to: end)
        case .week:
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return [] }
            return SQLiteManager.shared.fetchEntries(from: weekAgo, to: now)
        case .month:
            guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else { return [] }
            return SQLiteManager.shared.fetchEntries(from: monthAgo, to: now)
        }
    }

    private func computeCategoryStats(entries: [TimesheetEntry]) -> [CategoryStat] {
        var map: [String: (prod: ProductivityCategory, secs: TimeInterval, count: Int)] = [:]
        for entry in entries {
            let cat = entry.category
            let existing = map[cat] ?? (prod: entry.productivity, secs: 0, count: 0)
            map[cat] = (prod: entry.productivity, secs: existing.secs + entry.duration, count: existing.count + 1)
        }
        return map.map { (cat, val) in
            CategoryStat(category: cat, productivity: val.prod, totalSeconds: val.secs, count: val.count)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
