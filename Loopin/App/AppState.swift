import Foundation

final class AppState: ObservableObject {
    let settingsStore: SettingsStore
    let taskStore: TaskStore
    let timerEngine: TimerEngine
    let timerSession: TimerSession
    /// Always-on repeating alarm engine (V1_IMPROVEMENTS §3), distinct from the
    /// Pomodoro timer. Reused by the alarms window and the attention system.
    let alarmEngine: FocusIntervalAlarmEngine
    let timesheetStore: TimesheetStore
    let classificationStore: ClassificationStore
    let intervalLoggingEngine: IntervalLoggingEngine
    let syncStore: SyncStore
    let gcalEngine: GoogleCalendarSyncEngine

    init(
        settingsStore: SettingsStore,
        taskStore: TaskStore,
        timerSession: TimerSession,
        timesheetStore: TimesheetStore = .shared,
        classificationStore: ClassificationStore = .shared,
        intervalLoggingEngine: IntervalLoggingEngine = .shared,
        syncStore: SyncStore = .shared,
        gcalEngine: GoogleCalendarSyncEngine = .shared
    ) {
        self.settingsStore = settingsStore
        self.taskStore = taskStore
        self.timerSession = timerSession
        self.timerEngine = TimerEngine(session: timerSession)
        self.alarmEngine = FocusIntervalAlarmEngine(settingsStore: settingsStore)
        self.timesheetStore = timesheetStore
        self.classificationStore = classificationStore
        self.intervalLoggingEngine = intervalLoggingEngine
        self.syncStore = syncStore
        self.gcalEngine = gcalEngine
        timerSession.activePreset = settingsStore.settings.presets.first
    }
}