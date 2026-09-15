import SwiftUI

public struct TimesheetWindowView: View {
    @EnvironmentObject private var bridge: PanelBridge
    @EnvironmentObject private var timesheetStore: TimesheetStore
    @EnvironmentObject private var classificationStore: ClassificationStore

    @State private var selectedTab: TimesheetTab = .rails
    @State private var showingQuickAdd: Bool = false

    public enum TimesheetTab: String, CaseIterable {
        case rails = "Dual Rails"
        case calendar = "Week Calendar"
        case rules = "Dictionary"
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            WindowHeaderView(title: "Timesheet & Logbook")

            Divider()
                .background(AppTheme.borderSubtle)

            // Tab bar + Action
            HStack {
                Picker("", selection: $selectedTab) {
                    ForEach(TimesheetTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                Spacer()

                Button(action: { showingQuickAdd = true }) {
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
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppTheme.surface)

            Divider()
                .background(AppTheme.borderSubtle)

            // Content Area
            Group {
                switch selectedTab {
                case .rails:
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 16) {
                            TimesheetTimelineView()
                                .environmentObject(timesheetStore)
                                .environmentObject(classificationStore)

                            // Day's entries breakdown list
                            todayEntriesBreakdownList
                        }
                        .padding(14)
                    }
                case .calendar:
                    TimesheetCalendarView()
                        .environmentObject(timesheetStore)
                        .environmentObject(classificationStore)
                case .rules:
                    rulesDictionaryTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 540, minHeight: 520)
        .background(AppTheme.background)
        .glow(
            accent: AppTheme.accentTeal,
            intensity: .standard,
            active: bridge.isPinned
        )
        .sheet(isPresented: $showingQuickAdd) {
            TimesheetQuickAddView()
                .environmentObject(timesheetStore)
                .environmentObject(classificationStore)
        }
    }

    // MARK: - Today's entries breakdown list

    private var todayEntriesBreakdownList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's Blocks")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Text("\(timesheetStore.todayPlannedEntries.count) planned • \(timesheetStore.todayLoggedEntries.count) logged")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
            }

            if timesheetStore.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 28))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.6))
                    Text("No blocks recorded for today")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(AppTheme.surface.opacity(0.4))
                .cornerRadius(8)
            } else {
                VStack(spacing: 6) {
                    ForEach(timesheetStore.entries) { entry in
                        entryRowView(entry: entry)
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.surface)
        .cornerRadius(10)
    }

    private func entryRowView(entry: TimesheetEntry) -> some View {
        HStack(spacing: 10) {
            // Kind badge
            Text(entry.kind == .planned ? "PLANNED" : "LOGGED")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundColor(entry.kind == .planned ? AppTheme.accentTeal : AppTheme.accentViolet)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    (entry.kind == .planned ? AppTheme.accentTeal : AppTheme.accentViolet).opacity(0.15)
                )
                .cornerRadius(3)

            // Status icon
            Image(systemName: entry.isSkipped ? "forward.fill" : entry.productivity.icon)
                .foregroundColor(entry.isSkipped ? AppTheme.textSecondary : entry.productivity.color)
                .font(.system(size: 11))
                .frame(width: 14)

            // Title / Category
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.isSkipped ? "Skipped logging prompt" : entry.rawText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(entry.isSkipped ? AppTheme.textSecondary : AppTheme.textPrimary)
                    .lineLimit(1)
                Text("\(entry.category) • \(entry.productivity.title)")
                    .font(.system(size: 10))
                    .foregroundColor(entry.productivity.color)
            }

            Spacer()

            // Time & duration
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(formattedTime(entry.startAt)) – \(formattedTime(entry.endAt))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)
                Text("\(entry.durationInMinutes) min")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(8)
        .background(AppTheme.surfaceElevated)
        .cornerRadius(6)
    }

    // MARK: - Dictionary Tab

    private var rulesDictionaryTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Personal Classification Dictionary")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Keywords and phrases used to automatically classify logs.")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Text("\(classificationStore.rules.count) rules (\(classificationStore.rules.filter { $0.userDefined }.count) personal)")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(classificationStore.rules) { rule in
                        HStack {
                            Circle()
                                .fill(rule.productivity.color)
                                .frame(width: 8, height: 8)

                            Text(rule.phrase)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)

                            if rule.userDefined {
                                Text("Learned")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(AppTheme.accentTeal.opacity(0.2))
                                    .foregroundColor(AppTheme.accentTeal)
                                    .cornerRadius(3)
                            }

                            Spacer()

                            Text(rule.category)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(rule.productivity.color)

                            Text(rule.productivity.title)
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(8)
                        .background(AppTheme.surface)
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
