import SwiftUI

/// Week & Day Calendar View (DESIGN.md §3.3):
/// Planned and logged blocks overlaid in the same lane, distinguished by fill style:
/// - Solid fill = Logged
/// - Crisp outline fill = Planned
/// Overlaps and mismatches are immediately obvious.
public struct TimesheetCalendarView: View {
    @EnvironmentObject private var timesheetStore: TimesheetStore
    @EnvironmentObject private var classificationStore: ClassificationStore

    @State private var viewMode: CalendarViewMode = .week
    @State private var hoveredEntry: TimesheetEntry?
    @State private var editingEntry: TimesheetEntry?
    @State private var isCreatingPlanned = false

    public enum CalendarViewMode: String, CaseIterable {
        case day = "Day"
        case week = "Week"
    }

    private let hours = Array(6...23)
    private let hourHeight: CGFloat = 44

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Calendar Top Bar
            calendarTopBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.surface)

            Divider()
                .background(AppTheme.borderSubtle)

            // Main Scrollable Grid
            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                HStack(alignment: .top, spacing: 0) {
                    // Time gutter
                    timeGutter
                        .frame(width: 52)

                    // Day columns
                    if viewMode == .week {
                        weekColumnsView
                    } else {
                        singleDayColumnView(date: timesheetStore.selectedDate)
                    }
                }
                .padding(.vertical, 8)
                .padding(.trailing, 16)
            }
        }
        .background(AppTheme.background)
        .sheet(item: $editingEntry) { entry in
            ClassificationEditorView(entry: entry)
                .environmentObject(timesheetStore)
                .environmentObject(classificationStore)
        }
        .sheet(isPresented: $isCreatingPlanned) {
            TimesheetQuickAddView()
                .environmentObject(timesheetStore)
                .environmentObject(classificationStore)
        }
    }

    // MARK: - Top Bar

    private var calendarTopBar: some View {
        HStack {
            // Mode Picker
            Picker("Mode", selection: $viewMode) {
                ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            Spacer()

            // Date navigation
            HStack(spacing: 8) {
                Button(action: previousPeriod) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)

                Text(periodLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Button(action: nextPeriod) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)

                Button("Today") {
                    timesheetStore.selectedDate = Date()
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.accentTeal)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppTheme.accentTeal.opacity(0.12))
                .cornerRadius(4)
                .buttonStyle(.plain)
            }

            Spacer()

            // Quick Add Planned
            Button(action: { isCreatingPlanned = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("Plan Block")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.accentTeal)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Time Gutter

    private var timeGutter: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(height: hourHeight, alignment: .top)
            }
        }
        .padding(.top, 24)
    }

    // MARK: - Week Columns

    private var weekColumnsView: some View {
        let days = currentWeekDays()
        return HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                singleDayColumnView(date: day)
                    .frame(minWidth: 120)
            }
        }
    }

    private func singleDayColumnView(date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let dayPlanned = timesheetStore.plannedEntries(for: date)
        let dayLogged = timesheetStore.loggedEntries(for: date)

        return VStack(spacing: 4) {
            // Day Header
            VStack(spacing: 2) {
                Text(dayOfWeek(date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isToday ? AppTheme.accentTeal : AppTheme.textSecondary)
                Text(dayOfMonth(date))
                    .font(.system(size: 14, weight: isToday ? .bold : .semibold))
                    .foregroundColor(isToday ? AppTheme.accentTeal : AppTheme.textPrimary)
            }
            .frame(height: 32)

            // Hour grid & overlay blocks
            ZStack(alignment: .topLeading) {
                // Background grid lines
                VStack(spacing: 0) {
                    ForEach(hours, id: \.self) { _ in
                        Divider()
                            .background(AppTheme.borderSubtle.opacity(0.5))
                            .frame(height: hourHeight)
                    }
                }

                // Planned entries (Rendered as crisp OUTLINE cards)
                ForEach(dayPlanned) { entry in
                    plannedOverlayCard(entry: entry)
                }

                // Logged entries (Rendered as SOLID vibrant cards)
                ForEach(dayLogged) { entry in
                    loggedOverlayCard(entry: entry)
                }
            }
            .frame(height: CGFloat(hours.count) * hourHeight)
            .background(AppTheme.surface.opacity(0.4))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isToday ? AppTheme.accentTeal.opacity(0.3) : AppTheme.borderSubtle, lineWidth: 1)
            )
        }
    }

    // MARK: - Cards

    private func plannedOverlayCard(entry: TimesheetEntry) -> some View {
        let (offsetY, height) = blockYAndHeight(start: entry.startAt, end: entry.endAt)

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 8))
                Text(entry.rawText)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            if height > 30 {
                Text("\(entry.category) • \(entry.durationInMinutes)m")
                    .font(.system(size: 8))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: max(20, height))
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(entry.productivity.color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(entry.productivity.color, lineWidth: 1.5)
        )
        .offset(y: offsetY)
        .padding(.horizontal, 2)
        .onTapGesture {
            editingEntry = entry
        }
    }

    private func loggedOverlayCard(entry: TimesheetEntry) -> some View {
        let (offsetY, height) = blockYAndHeight(start: entry.startAt, end: entry.endAt)
        let isSkipped = entry.isSkipped

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: isSkipped ? "forward.fill" : (entry.inputMethod == .voice ? "mic.fill" : "checkmark.circle.fill"))
                    .font(.system(size: 8))
                Text(isSkipped ? "Skipped" : entry.rawText)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
            }
            if height > 30 && !isSkipped {
                Text("\(entry.category) • \(entry.productivity.title)")
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(1)
            }
        }
        .foregroundColor(isSkipped ? AppTheme.textSecondary : .black)
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: max(20, height))
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSkipped ? Color.white.opacity(0.06) : entry.productivity.color.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(isSkipped ? AppTheme.textSecondary.opacity(0.4) : entry.productivity.color, style: isSkipped ? StrokeStyle(lineWidth: 1, dash: [2, 2]) : StrokeStyle(lineWidth: 1))
        )
        .offset(y: offsetY)
        .padding(.horizontal, 4)
        .onTapGesture {
            editingEntry = entry
        }
    }

    // MARK: - Helpers

    private func blockYAndHeight(start: Date, end: Date) -> (CGFloat, CGFloat) {
        let calendar = Calendar.current
        let startHourVal = Double(calendar.component(.hour, from: start)) + Double(calendar.component(.minute, from: start)) / 60.0
        let endHourVal = Double(calendar.component(.hour, from: end)) + Double(calendar.component(.minute, from: end)) / 60.0

        let baseHour = Double(hours.first ?? 6)
        let relativeStart = max(0, startHourVal - baseHour)
        let duration = max(0.25, endHourVal - startHourVal)

        let offsetY = CGFloat(relativeStart) * hourHeight
        let height = CGFloat(duration) * hourHeight

        return (offsetY, height)
    }

    private func currentWeekDays() -> [Date] {
        let calendar = Calendar.current
        let baseDate = timesheetStore.selectedDate
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: baseDate) else { return [baseDate] }
        var days: [Date] = []
        for i in 0..<7 {
            if let d = calendar.date(byAdding: .day, value: i, to: weekInterval.start) {
                days.append(d)
            }
        }
        return days
    }

    private var periodLabel: String {
        let formatter = DateFormatter()
        if viewMode == .day {
            formatter.dateFormat = "EEEE, MMM d, yyyy"
            return formatter.string(from: timesheetStore.selectedDate)
        } else {
            let days = currentWeekDays()
            guard let first = days.first, let last = days.last else { return "" }
            formatter.dateFormat = "MMM d"
            let startStr = formatter.string(from: first)
            let endStr = formatter.string(from: last)
            return "\(startStr) – \(endStr)"
        }
    }

    private func previousPeriod() {
        let offset = viewMode == .day ? -1 : -7
        timesheetStore.selectedDate = Calendar.current.date(byAdding: .day, value: offset, to: timesheetStore.selectedDate) ?? timesheetStore.selectedDate
    }

    private func nextPeriod() {
        let offset = viewMode == .day ? 1 : 7
        timesheetStore.selectedDate = Calendar.current.date(byAdding: .day, value: offset, to: timesheetStore.selectedDate) ?? timesheetStore.selectedDate
    }

    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func dayOfMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}
