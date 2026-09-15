import SwiftUI

public struct TimesheetWindowView: View {
    @EnvironmentObject private var bridge: PanelBridge
    @EnvironmentObject private var timesheetStore: TimesheetStore
    @EnvironmentObject private var classificationStore: ClassificationStore
    @EnvironmentObject private var intervalEngine: IntervalLoggingEngine
    @EnvironmentObject private var timerEngine: TimerEngine
    @EnvironmentObject private var timerSession: TimerSession

    @State private var selectedTab: TimesheetTab = .rails
    @State private var showingQuickAddSheet: Bool = false
    @State private var quickAddText: String = ""
    @State private var quickAddKind: TimesheetKind = .planned
    @State private var isListening: Bool = false
    @State private var editingEntry: TimesheetEntry?
    @State private var showSeedAlert: Bool = false

    @StateObject private var speechService = SpeechRecognitionService()

    public enum TimesheetTab: String, CaseIterable {
        case rails = "Dual Rails"
        case calendar = "Week Calendar"
        case reports = "Analytics & Reports"
        case dictionary = "Dictionary"
        case intervals = "Focus & Prompts"
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Window Header with Pinned Glow & Brand
            WindowHeaderView(title: "Timesheet & Logbook")

            Divider()
                .background(AppTheme.borderSubtle)

            // Primary Navigation & Action Bar
            topNavigationBar

            Divider()
                .background(AppTheme.borderSubtle)

            // Content Area
            Group {
                switch selectedTab {
                case .rails:
                    dualRailsTabContent
                case .calendar:
                    TimesheetCalendarView()
                        .environmentObject(timesheetStore)
                        .environmentObject(classificationStore)
                case .reports:
                    ReportsView()
                        .environmentObject(timesheetStore)
                case .dictionary:
                    rulesDictionaryTab
                case .intervals:
                    intervalsAndPromptsTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 620, minHeight: 600)
        .background(AppTheme.background)
        .glow(
            accent: AppTheme.accentTeal,
            intensity: .standard,
            active: bridge.isPinned
        )
        .sheet(isPresented: $showingQuickAddSheet) {
            TimesheetQuickAddView()
                .environmentObject(timesheetStore)
                .environmentObject(classificationStore)
        }
        .sheet(item: $editingEntry) { entry in
            ClassificationEditorView(entry: entry)
                .environmentObject(timesheetStore)
                .environmentObject(classificationStore)
        }
    }

    // MARK: - Top Navigation Bar

    private var topNavigationBar: some View {
        HStack(spacing: 10) {
            Picker("", selection: $selectedTab) {
                ForEach(TimesheetTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)

            Spacer()

            // Quick Demo / Reset Menu
            Menu {
                Button(action: {
                    timesheetStore.seedSampleDay(for: timesheetStore.selectedDate)
                }) {
                    Label("Load Realistic Demo Day", systemImage: "sparkles")
                }

                Button(role: .destructive, action: {
                    timesheetStore.clearDay(for: timesheetStore.selectedDate)
                }) {
                    Label("Clear Current Day", systemImage: "trash")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .foregroundColor(AppTheme.accentTeal)
                    Text("Demo")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(AppTheme.surfaceElevated)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppTheme.borderSubtle, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)

            // Trigger floating prompt panel
            Button(action: {
                LoggingPanelController.shared.presentPrompt(
                    intervalEngine: intervalEngine,
                    timesheetStore: timesheetStore,
                    classificationStore: classificationStore
                )
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                    Text("Prompt Me")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(AppTheme.accentCoral)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Open always-on-top floating check-in prompt (PRD §3.2)")

            // Plan Block Sheet Button
            Button(action: { showingQuickAddSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("Plan")
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
    }

    // MARK: - Dual Rails Tab Content

    private var dualRailsTabContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 14) {
                // 1. Hero Natural-Language Quick-Add Bar
                heroInlineQuickAddBar

                // 2. Active Session & Interval Status Bar
                activeIntervalStatusBar

                // 3. Dual-Rail Timeline
                TimesheetTimelineView()
                    .environmentObject(timesheetStore)
                    .environmentObject(classificationStore)

                // 4. Today's Breakdown or Empty State
                todayEntriesBreakdownList
            }
            .padding(14)
        }
    }

    // MARK: - Hero Natural-Language Quick-Add Bar

    private var heroInlineQuickAddBar: some View {
        let result = classificationStore.classify(text: quickAddText)
        let inferredCat = result.category
        let inferredProd = result.productivity

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Kind Toggle Pill
                Button(action: {
                    quickAddKind = (quickAddKind == .planned) ? .logged : .planned
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: quickAddKind == .planned ? "calendar.badge.clock" : "checkmark.seal.fill")
                            .font(.system(size: 10))
                        Text(quickAddKind == .planned ? "PLANNED" : "LOGGED")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(quickAddKind == .planned ? AppTheme.accentTeal : AppTheme.accentViolet)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        (quickAddKind == .planned ? AppTheme.accentTeal : AppTheme.accentViolet).opacity(0.18)
                    )
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(quickAddKind == .planned ? AppTheme.accentTeal : AppTheme.accentViolet, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Click to toggle between Planning future intent and Logging reality")

                // Natural Language Text Field
                ZStack(alignment: .leading) {
                    if quickAddText.isEmpty {
                        Text(quickAddKind == .planned ? "Quick plan: 'coding 2-4pm', 'standup 11:30', 'gym 5pm'..." : "Quick log: 'deep work on engine 1h', 'YouTube 30m', 'lunch'...")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                    }
                    TextField("", text: $quickAddText, onCommit: submitInlineQuickAdd)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                }

                // Live Category Pill Preview (if text entered)
                if !quickAddText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(inferredProd.color)
                            .frame(width: 6, height: 6)
                        Text(inferredCat)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(inferredProd.color)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(inferredProd.color.opacity(0.15))
                    .cornerRadius(4)
                    .transition(.opacity)
                }

                // Voice Mic Button (PRD §3.2 on-device speech-to-text)
                Button(action: toggleSpeechRecognition) {
                    Image(systemName: speechService.isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: 12))
                        .foregroundColor(speechService.isRecording ? AppTheme.accentCoral : AppTheme.textSecondary)
                        .padding(6)
                        .background(speechService.isRecording ? AppTheme.accentCoral.opacity(0.2) : Color.clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Dictate using on-device speech recognition")

                // Submit Button
                Button(action: submitInlineQuickAdd) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(quickAddText.isEmpty ? AppTheme.textSecondary.opacity(0.4) : AppTheme.accentTeal)
                }
                .buttonStyle(.plain)
                .disabled(quickAddText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppTheme.surface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.borderSubtle, lineWidth: 1)
            )
        }
        .onChange(of: speechService.recognizedText) { newText in
            if !newText.isEmpty {
                self.quickAddText = newText
            }
        }
    }

    private func submitInlineQuickAdd() {
        let trimmed = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let parsed = TimesheetNLPParser.shared.parse(input: trimmed, baseDate: timesheetStore.selectedDate)
        let result = classificationStore.classify(text: parsed.title)

        if quickAddKind == .planned {
            _ = timesheetStore.quickAddPlanned(
                text: parsed.title,
                start: parsed.startDate,
                end: parsed.endDate,
                category: result.category,
                productivity: result.productivity
            )
        } else {
            _ = timesheetStore.quickAddLogged(
                text: parsed.title,
                inputMethod: .typed,
                category: result.category,
                productivity: result.productivity,
                start: parsed.startDate,
                end: parsed.endDate
            )
        }

        quickAddText = ""
    }

    private func toggleSpeechRecognition() {
        speechService.toggleRecording()
    }

    // MARK: - Active Session & Interval Status Bar

    private var activeIntervalStatusBar: some View {
        HStack(spacing: 12) {
            // Live Status Indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(intervalEngine.isPromptActive ? AppTheme.accentCoral : AppTheme.accentTeal)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(intervalEngine.isPromptActive ? "Prompt Overdue / Waiting" : "Interval Logging Active")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)

                    let mins = intervalEngine.secondsUntilNextPrompt / 60
                    let secs = intervalEngine.secondsUntilNextPrompt % 60
                    Text(intervalEngine.isPromptActive ? "Action required in floating prompt" : "Next prompt in \(mins)m \(String(format: "%02d", secs))s (every \(intervalEngine.intervalMinutes)m)")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            // Quick Interval Selectors (2 / 5 / 10 / 15 / 25 min)
            HStack(spacing: 4) {
                Text("Interval:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                ForEach([5, 10, 15, 25], id: \.self) { min in
                    Button(action: {
                        intervalEngine.intervalMinutes = min
                    }) {
                        Text("\(min)m")
                            .font(.system(size: 10, weight: intervalEngine.intervalMinutes == min ? .bold : .medium))
                            .foregroundColor(intervalEngine.intervalMinutes == min ? .black : AppTheme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(intervalEngine.intervalMinutes == min ? AppTheme.accentTeal : AppTheme.surfaceElevated)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.surfaceElevated.opacity(0.8))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Today's Entries Breakdown List & Empty State

    private var todayEntriesBreakdownList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's Blocks Breakdown")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                let plannedCount = timesheetStore.todayPlannedEntries.count
                let loggedCount = timesheetStore.todayLoggedEntries.count
                let deepWorkCount = timesheetStore.todayLoggedEntries.filter { $0.productivity == .productive }.count

                Text("\(plannedCount) planned • \(loggedCount) logged (\(deepWorkCount) deep work)")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
            }

            if timesheetStore.entries.isEmpty {
                emptyStateHeroCard
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
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Empty State Hero Card

    private var emptyStateHeroCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 32))
                .foregroundColor(AppTheme.accentTeal)

            VStack(spacing: 3) {
                Text("No timesheet blocks recorded for today")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Text("Loopin displays your Planned Intent (top outline rail) against Logged Reality (bottom solid rail).")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 10) {
                Button(action: {
                    timesheetStore.seedSampleDay(for: timesheetStore.selectedDate)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Load Realistic Demo Day (1-Click)")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppTheme.accentTeal)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button(action: {
                    LoggingPanelController.shared.presentPrompt(
                        intervalEngine: intervalEngine,
                        timesheetStore: timesheetStore,
                        classificationStore: classificationStore
                    )
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("Test Floating Prompt")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppTheme.surfaceElevated)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppTheme.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(AppTheme.surfaceElevated.opacity(0.5))
        .cornerRadius(8)
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

            // Edit button
            Button(action: { editingEntry = entry }) {
                Image(systemName: "pencil")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(AppTheme.surfaceElevated)
        .cornerRadius(6)
        .onTapGesture {
            editingEntry = entry
        }
    }

    // MARK: - Dictionary Tab

    private var rulesDictionaryTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local Classification Dictionary")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("No per-entry LLM call — instantaneous local keyword matcher with personal learned overrides.")
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

    // MARK: - Intervals & Prompts Tab

    private var intervalsAndPromptsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interval Logging & Attention System")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Always-on-top prompts with 2.6s breathing glow, on-device voice dictation, and non-judgmental skip logging.")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }

                // Prompt Config Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Logging Interval Configuration")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)

                    Picker("Interval", selection: $intervalEngine.intervalMinutes) {
                        Text("2 min").tag(2)
                        Text("3 min").tag(3)
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                        Text("20 min").tag(20)
                        Text("25 min").tag(25)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Toggle("Enable background prompt timer", isOn: $intervalEngine.isEnabled)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textPrimary)

                        Spacer()

                        Button(action: {
                            LoggingPanelController.shared.presentPrompt(
                                intervalEngine: intervalEngine,
                                timesheetStore: timesheetStore,
                                classificationStore: classificationStore
                            )
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("Launch Floating Prompt (Test)")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.accentCoral)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .background(AppTheme.surface)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.borderSubtle, lineWidth: 1)
                )

                // Google Calendar Two-Way Sync Card (PRD §3.4)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(AppTheme.accentTeal)
                        Text("Google Calendar Two-Way Sync")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text("Connected")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accentTeal.opacity(0.15))
                            .foregroundColor(AppTheme.accentTeal)
                            .cornerRadius(4)
                    }

                    Text("Automatically synchronizes 'Loopin Planned' and 'Loopin Logged' calendars with incremental syncToken updates.")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)

                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Circle().fill(AppTheme.accentTeal).frame(width: 6, height: 6)
                            Text("Loopin Planned: Active")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        HStack(spacing: 6) {
                            Circle().fill(AppTheme.accentViolet).frame(width: 6, height: 6)
                            Text("Loopin Logged: Active")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
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
            .padding(16)
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
