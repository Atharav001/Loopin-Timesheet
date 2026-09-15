import SwiftUI

/// Dual-rail timeline view (DESIGN.md §3.1):
/// Shows Planned blocks on top rail and Logged blocks on bottom rail across the day.
/// Current time needle, gap highlighting, and color coding.
public struct TimesheetTimelineView: View {
    @EnvironmentObject private var timesheetStore: TimesheetStore
    @EnvironmentObject private var classificationStore: ClassificationStore
    @State private var hoveredEntry: TimesheetEntry?
    @State private var editingEntry: TimesheetEntry?
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // Active day window: 06:00 to 24:00 (18 hours)
    private let startHour: Double = 6.0
    private let endHour: Double = 24.0
    private var totalHours: Double { endHour - startHour }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with date navigator
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Timesheet Rails")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Planned (top) vs. Logged (bottom)")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                // Date picker / Today shortcut
                HStack(spacing: 6) {
                    Button(action: {
                        timesheetStore.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: timesheetStore.selectedDate) ?? timesheetStore.selectedDate
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Text(formattedDate(timesheetStore.selectedDate))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)

                    Button(action: {
                        timesheetStore.selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: timesheetStore.selectedDate) ?? timesheetStore.selectedDate
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)

                    if !Calendar.current.isDateInToday(timesheetStore.selectedDate) {
                        Button(action: { timesheetStore.selectedDate = Date() }) {
                            Text("Today")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.accentTeal.opacity(0.15))
                                .foregroundColor(AppTheme.accentTeal)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Timeline Container
            GeometryReader { geo in
                let width = geo.size.width
                VStack(alignment: .leading, spacing: 4) {
                    // Time Labels (06:00, 09:00, 12:00, 15:00, 18:00, 21:00, 24:00)
                    timeAxisLabels(width: width)

                    // Dual Timeline Rail Track
                    ZStack(alignment: .topLeading) {
                        // Background Track
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppTheme.borderSubtle, lineWidth: 1)
                            )
                            .frame(height: 72)

                        // Vertical hour grid lines
                        hourGridLines(width: width, height: 72)

                        // Planned Rail (Top Half)
                        VStack(spacing: 2) {
                            ZStack(alignment: .leading) {
                                Color.clear.frame(height: 32)
                                ForEach(timesheetStore.todayPlannedEntries) { entry in
                                    plannedBlockView(entry: entry, totalWidth: width)
                                }
                            }

                            Divider()
                                .background(AppTheme.borderSubtle)

                            // Logged Rail (Bottom Half)
                            ZStack(alignment: .leading) {
                                Color.clear.frame(height: 32)
                                ForEach(timesheetStore.todayLoggedEntries) { entry in
                                    loggedBlockView(entry: entry, totalWidth: width)
                                }
                            }
                        }
                        .padding(.vertical, 2)

                        // Current Time Indicator Line (if today)
                        if Calendar.current.isDateInToday(timesheetStore.selectedDate) {
                            currentTimeNeedle(totalWidth: width, height: 72)
                        }
                    }
                    .frame(height: 72)
                }
            }
            .frame(height: 96)

            // Hover / Detail Inspector
            if let entry = hoveredEntry {
                entryInspector(entry: entry)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                // Legend
                timelineLegend
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.borderSubtle, lineWidth: 1)
        )
        .onReceive(timer) { input in
            currentTime = input
        }
        .sheet(item: $editingEntry) { entry in
            ClassificationEditorView(entry: entry)
                .environmentObject(timesheetStore)
                .environmentObject(classificationStore)
        }
    }

    // MARK: - Subviews

    private func timeAxisLabels(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<7) { i in
                let hour = Int(startHour) + (i * 3)
                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.textSecondary)
                if i < 6 {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func hourGridLines(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<18) { hourOffset in
                Rectangle()
                    .fill(AppTheme.borderSubtle.opacity(hourOffset % 3 == 0 ? 0.6 : 0.2))
                    .frame(width: 1, height: height)
                if hourOffset < 17 {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func plannedBlockView(entry: TimesheetEntry, totalWidth: CGFloat) -> some View {
        let (x, blockWidth) = positionAndWidth(start: entry.startAt, end: entry.endAt, totalWidth: totalWidth)
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(entry.productivity.color, lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(entry.productivity.color.opacity(0.18))
                )

            HStack(spacing: 3) {
                Image(systemName: "calendar")
                    .font(.system(size: 8))
                Text(entry.rawText)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(AppTheme.textPrimary)
            .padding(.horizontal, 4)
        }
        .frame(width: max(16, blockWidth), height: 28)
        .offset(x: x)
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredEntry = isHovered ? entry : (hoveredEntry?.id == entry.id ? nil : hoveredEntry)
            }
        }
        .onTapGesture {
            editingEntry = entry
        }
    }

    private func loggedBlockView(entry: TimesheetEntry, totalWidth: CGFloat) -> some View {
        let (x, blockWidth) = positionAndWidth(start: entry.startAt, end: entry.endAt, totalWidth: totalWidth)
        let isSkipped = entry.isSkipped

        return ZStack(alignment: .leading) {
            if isSkipped {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(AppTheme.textSecondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.04))
                    )
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(entry.productivity.color.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(entry.productivity.color, lineWidth: 1)
                    )
            }

            HStack(spacing: 3) {
                Image(systemName: isSkipped ? "forward.fill" : (entry.inputMethod == .voice ? "mic.fill" : "checkmark"))
                    .font(.system(size: 8))
                Text(isSkipped ? "Skipped" : entry.rawText)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(isSkipped ? AppTheme.textSecondary : .black)
            .padding(.horizontal, 4)
        }
        .frame(width: max(16, blockWidth), height: 28)
        .offset(x: x)
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredEntry = isHovered ? entry : (hoveredEntry?.id == entry.id ? nil : hoveredEntry)
            }
        }
        .onTapGesture {
            editingEntry = entry
        }
    }

    private func currentTimeNeedle(totalWidth: CGFloat, height: CGFloat) -> some View {
        let calendar = Calendar.current
        let hour = Double(calendar.component(.hour, from: currentTime))
        let minute = Double(calendar.component(.minute, from: currentTime))
        let timeInHours = hour + (minute / 60.0)

        guard timeInHours >= startHour && timeInHours <= endHour else {
            return AnyView(EmptyView())
        }

        let fraction = (timeInHours - startHour) / totalHours
        let x = CGFloat(fraction) * totalWidth

        return AnyView(
            VStack(spacing: 0) {
                Circle()
                    .fill(AppTheme.accentCoral)
                    .frame(width: 6, height: 6)
                Rectangle()
                    .fill(AppTheme.accentCoral)
                    .frame(width: 1.5, height: height)
            }
            .offset(x: x - 3)
        )
    }

    private var timelineLegend: some View {
        HStack(spacing: 12) {
            legendItem(title: "Productive", color: ProductivityCategory.productive.color, style: .solid)
            legendItem(title: "Neutral", color: ProductivityCategory.neutral.color, style: .solid)
            legendItem(title: "Wasteful", color: ProductivityCategory.wasteful.color, style: .solid)
            legendItem(title: "Planned", color: AppTheme.accentTeal, style: .outline)
            legendItem(title: "Skipped", color: AppTheme.textSecondary, style: .dashed)
            Spacer()
        }
        .font(.system(size: 10))
    }

    private func legendItem(title: String, color: Color, style: LegendStyle) -> some View {
        HStack(spacing: 4) {
            switch style {
            case .solid:
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 10, height: 10)
            case .outline:
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(color, lineWidth: 1.5)
                    .frame(width: 10, height: 10)
            case .dashed:
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(color, style: StrokeStyle(lineWidth: 1, dash: [2, 1]))
                    .frame(width: 10, height: 10)
            }
            Text(title)
                .foregroundColor(AppTheme.textSecondary)
        }
    }

    private func entryInspector(entry: TimesheetEntry) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(entry.productivity.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.rawText.isEmpty ? "Skipped Entry" : entry.rawText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 8) {
                    Text("\(formattedTime(entry.startAt)) – \(formattedTime(entry.endAt)) (\(entry.durationInMinutes) min)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(AppTheme.textSecondary)

                    Text("•")
                        .foregroundColor(AppTheme.textSecondary)

                    Text(entry.category)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(entry.productivity.color)

                    Text("•")
                        .foregroundColor(AppTheme.textSecondary)

                    Text(entry.kind.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.accentTeal)
                }
            }

            Spacer()

            Button(action: { editingEntry = entry }) {
                Text("Edit / Reclassify")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.accentTeal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.accentTeal.opacity(0.12))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(AppTheme.surfaceElevated)
        .cornerRadius(8)
    }

    private enum LegendStyle { case solid, outline, dashed }

    // MARK: - Helpers

    private func positionAndWidth(start: Date, end: Date, totalWidth: CGFloat) -> (CGFloat, CGFloat) {
        let calendar = Calendar.current
        let startHourVal = Double(calendar.component(.hour, from: start)) + Double(calendar.component(.minute, from: start)) / 60.0
        let endHourVal = Double(calendar.component(.hour, from: end)) + Double(calendar.component(.minute, from: end)) / 60.0

        let clampedStart = max(startHour, min(endHour, startHourVal))
        let clampedEnd = max(startHour, min(endHour, endHourVal))

        let startFraction = (clampedStart - startHour) / totalHours
        let durationFraction = max(0.01, (clampedEnd - clampedStart) / totalHours)

        let x = CGFloat(startFraction) * totalWidth
        let width = CGFloat(durationFraction) * totalWidth

        return (x, width)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
