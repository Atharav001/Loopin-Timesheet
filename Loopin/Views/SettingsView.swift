import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case timers = "Focus Timers"
        case timesheet = "Timesheet & Logbook"
        case reminders = "Reminders & Alerts"
        case sync = "Sync & Calendar"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "gearshape.fill"
            case .timers: return "timer"
            case .timesheet: return "clock.badge.checkmark.fill"
            case .reminders: return "bell.badge.fill"
            case .sync: return "arrow.triangle.2.circlepath.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .general: return AppTheme.accentViolet
            case .timers: return AppTheme.accentTeal
            case .timesheet: return AppTheme.accentTeal
            case .reminders: return AppTheme.accentCoral
            case .sync: return AppTheme.accentBlue
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar Navigation
            VStack(alignment: .leading, spacing: 8) {
                Text("PREFERENCES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(selectedTab == tab ? tab.color : AppTheme.textSecondary)
                                .frame(width: 18)

                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: selectedTab == tab ? .bold : .medium))
                                .foregroundStyle(selectedTab == tab ? AppTheme.textPrimary : AppTheme.textSecondary)

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? tab.color.opacity(0.16) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(selectedTab == tab ? tab.color.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // App version & branding footer
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.accentTeal)
                        .frame(width: 6, height: 6)
                    Text("Loopin Focus & Timesheet")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(12)
            }
            .frame(width: 180)
            .background(AppTheme.surface.opacity(0.85))

            Divider()
                .overlay(AppTheme.borderSubtle)

            // Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .general:
                        generalSection
                    case .timers:
                        timersSection
                    case .timesheet:
                        timesheetSection
                    case .reminders:
                        remindersSection
                    case .sync:
                        syncSection
                    }
                }
                .padding(24)
            }
        }
        .background(AppTheme.background)
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            header(title: "General Preferences", subtitle: "Customize window pinning, daily load balancing, and sensory stimulation intensity.")

            VStack(spacing: 12) {
                settingToggleCard(
                    title: "Pin panels by default",
                    subtitle: "Windows stay floating on top across all Spaces and full-screen apps.",
                    icon: "pin.fill",
                    color: AppTheme.accentViolet,
                    isOn: $settingsStore.settings.pinnedByDefault
                )

                settingToggleCard(
                    title: "Daily scope cap (1-3-5 rule)",
                    subtitle: "Prevents executive overload by limiting today's focus to 1 big, 3 medium, and 5 small tasks.",
                    icon: "shield.checkered",
                    color: AppTheme.accentTeal,
                    isOn: $settingsStore.settings.dailyCapEnabled
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("STIMULATION INTENSITY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Controls the duration, brightness, and audio volume of focus and alarm notifications.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)

                    Picker("", selection: $settingsStore.settings.stimulationIntensity) {
                        ForEach(StimulationIntensity.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.borderSubtle, lineWidth: 1))
                )
            }
        }
    }

    // MARK: - Timer Presets Section

    private var timersSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            header(title: "Focus Timer Presets", subtitle: "Configure interval durations for your deep work sessions and restorative breaks.")

            ForEach($settingsStore.settings.presets) { $preset in
                presetEditor($preset)
            }
        }
    }

    private func presetEditor(_ preset: Binding<TimerPreset>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle()
                    .fill(AppTheme.accentTeal)
                    .frame(width: 8, height: 8)
                TextField("Preset name", text: preset.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            HStack(spacing: 16) {
                durationField(label: "Focus Time", value: preset.focusMinutes, range: 5...120, color: AppTheme.accentTeal)
                durationField(label: "Short Break", value: preset.breakMinutes, range: 1...30, color: AppTheme.accentCoral)
                durationField(label: "Long Break", value: preset.longBreakMinutes, range: 5...60, color: AppTheme.accentViolet)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.borderSubtle, lineWidth: 1))
        )
    }

    private func durationField(label: String, value: Binding<Int>, range: ClosedRange<Int>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)

            HStack {
                Text("\(value.wrappedValue) min")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .monospacedDigit()

                Spacer()

                Stepper("", value: value, in: range)
                    .labelsHidden()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.surface)
            )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Reminders Section

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            header(title: "Reminders & Alerts", subtitle: "Configure two-stage escalation and anti-procrastination snooze timings.")

            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: "hourglass.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.accentCoral)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Escalation delay")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Time before an unacknowledged session-end reminder escalates.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    Stepper(value: $settingsStore.settings.reminderEscalationDelaySeconds, in: 5...300, step: 5) {
                        Text("\(Int(settingsStore.settings.reminderEscalationDelaySeconds))s")
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.accentCoral)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.borderSubtle, lineWidth: 1))
                )

                HStack(spacing: 14) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.accentAmber)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Snooze duration")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Length of grace period when snoozing a timer alert.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    Stepper(value: $settingsStore.settings.snoozeLengthMinutes, in: 1...30) {
                        Text("\(settingsStore.settings.snoozeLengthMinutes) min")
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.accentAmber)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.borderSubtle, lineWidth: 1))
                )
            }
        }
    }

    // MARK: - Timesheet Section

    @ObservedObject private var intervalEngine = IntervalLoggingEngine.shared
    @ObservedObject private var classificationStore = ClassificationStore.shared
    @ObservedObject private var speechService = SpeechRecognitionService.shared
    @ObservedObject private var gcalEngine = GoogleCalendarSyncEngine.shared
    @ObservedObject private var syncStore = SyncStore.shared

    private var timesheetSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            header(title: "Timesheet & Interval Logging", subtitle: "Configure periodic check-in prompts, interval durations, and on-device speech capture.")

            VStack(spacing: 12) {
                // Enable Interval Prompts toggle
                settingToggleCard(
                    title: "Interval Check-in Prompts",
                    subtitle: "Periodically display an always-on-top prompt to log where time actually went.",
                    icon: "clock.badge.checkmark.fill",
                    color: AppTheme.accentTeal,
                    isOn: $intervalEngine.isEnabled
                )

                // Interval Duration Selector
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "timer")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.accentTeal)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Logging Interval")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Choose frequency of logging check-in panels.")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer()

                        Text("\(intervalEngine.intervalMinutes) min")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.accentTeal)
                    }

                    // Interval chips (2, 3, 5, 10, 15, 20, 25 min)
                    HStack(spacing: 6) {
                        ForEach([2, 3, 5, 10, 15, 20, 25], id: \.self) { mins in
                            Button(action: { intervalEngine.intervalMinutes = mins }) {
                                Text("\(mins)m")
                                    .font(.system(size: 11, weight: intervalEngine.intervalMinutes == mins ? .bold : .medium))
                                    .foregroundStyle(intervalEngine.intervalMinutes == mins ? .black : AppTheme.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(intervalEngine.intervalMinutes == mins ? AppTheme.accentTeal : AppTheme.surface)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(intervalEngine.intervalMinutes == mins ? AppTheme.accentTeal : AppTheme.borderSubtle, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.borderSubtle, lineWidth: 1))
                )

                // Speech recognition status
                HStack(spacing: 14) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.accentCoral)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("On-Device Speech Dictation")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(speechService.isAuthorized ? "Microphone authorized & ready for offline speech-to-text." : "Click to grant speech recognition permission.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    if !speechService.isAuthorized {
                        Button("Authorize") {
                            speechService.checkAuthorization()
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.accentCoral)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.accentCoral.opacity(0.15))
                        .cornerRadius(6)
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.accentGreen)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.borderSubtle, lineWidth: 1))
                )

                // Dictionary Stats & Management
                HStack(spacing: 14) {
                    Image(systemName: "text.book.closed.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.accentViolet)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Personal Classification Dictionary")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("\(classificationStore.rules.count) active classification rules stored locally.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    Text("Offline Active")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.accentViolet)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.accentViolet.opacity(0.15))
                        .cornerRadius(4)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.borderSubtle, lineWidth: 1))
                )
            }
        }
    }

    // MARK: - Sync & Calendar Section

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            header(title: "Sync & Calendar Integrations", subtitle: "Connect Google Calendar two-way sync and cross-device account syncing.")

            VStack(spacing: 12) {
                // Google Calendar Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.accentBlue)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Google Calendar Two-Way Sync")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Syncs to 'Loopin Planned' and 'Loopin Logged' calendars.")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer()

                        if gcalEngine.link.isEnabled {
                            Button("Disconnect") {
                                gcalEngine.disconnect()
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.accentCoral)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.accentCoral.opacity(0.12))
                            .cornerRadius(6)
                            .buttonStyle(.plain)
                        } else {
                            Button("Connect Account") {
                                gcalEngine.connectAccount(email: "user@gmail.com", accountId: "acc_1001")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.accentBlue)
                            .cornerRadius(6)
                            .buttonStyle(.plain)
                        }
                    }

                    if gcalEngine.link.isEnabled {
                        Divider()
                            .overlay(AppTheme.borderSubtle)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connected: \(gcalEngine.link.accountEmail ?? "")")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(gcalEngine.lastSyncMessage)
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            Spacer()

                            Button("Sync Now") {
                                _Concurrency.Task {
                                    await gcalEngine.pullRemoteChanges()
                                }
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.accentBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.accentBlue.opacity(0.15))
                            .cornerRadius(4)
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.borderSubtle, lineWidth: 1))
                )

                // Multi-Device Cloud Sync Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        Image(systemName: "icloud.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.accentTeal)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cross-Device Sync (PostgreSQL)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Offline-first sync across macOS and Android with Row-Level Security.")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer()

                        Text(syncStore.syncStatus.title)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.accentTeal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.accentTeal.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.borderSubtle, lineWidth: 1))
                )
            }
        }
    }

    // MARK: - Helpers

    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func settingToggleCard(title: String, subtitle: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.borderSubtle, lineWidth: 1))
        )
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsStore())
        .frame(width: 560, height: 550)
        .background(AppTheme.background)
}