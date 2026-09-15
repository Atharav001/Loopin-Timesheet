import AppKit
import SwiftUI

/// Manages the N independent FloatingPanel windows (V1_IMPROVEMENTS §1).
/// Each `WindowController` owns its own panel, pin bridge, and persisted
/// frame/pin state. Selection/forwarding from the menu bar routes here.
final class PanelController {
    private var windows: [WindowKind: WindowController] = [:]
    private let settingsStore: SettingsStore
    private let taskStore: TaskStore
    private let timerSession: TimerSession
    private let appState: AppState

    /// Access for AppDelegate/ReminderScheduler wiring (single source of truth).
    var timerEngine: TimerEngine { appState.timerEngine }
    /// Access for AppDelegate attention wiring (single source of truth).
    var alarmEngine: FocusIntervalAlarmEngine { appState.alarmEngine }

    init(settingsStore: SettingsStore, taskStore: TaskStore, timerSession: TimerSession) {
        self.settingsStore = settingsStore
        self.taskStore = taskStore
        self.timerSession = timerSession
        self.appState = AppState(
            settingsStore: settingsStore,
            taskStore: taskStore,
            timerSession: timerSession
        )
    }

    /// Opens (or brings to front) the window for `kind`. Lazy-builds on first use.
    func focus(_ kind: WindowKind) {
        window(for: kind).focus()
    }

    /// Saves frames of all currently-open windows.
    func saveFrames() {
        for controller in windows.values {
            controller.saveFrameIfVisible()
        }
    }

    /// Final persistence flush on app termination (DESIGN §5: debounce is not a
    /// substitute for save-on-terminate).
    func saveAllOnTerminate() {
        saveFrames()
        taskStore.saveNow()
        settingsStore.saveNow()
    }

    private func window(for kind: WindowKind) -> WindowController {
        if let existing = windows[kind] { return existing }
        let controller = WindowController(kind: kind, settingsStore: settingsStore)
        installContent(in: controller, for: kind)
        windows[kind] = controller
        return controller
    }

    private func installContent(in controller: WindowController, for kind: WindowKind) {
        let bridge = controller.bridge
        switch kind {
        case .todo:
            let root = TodoWindowView()
                .environmentObject(settingsStore)
                .environmentObject(taskStore)
                .environmentObject(bridge)
                .environmentObject(appState.timerEngine)
                .environmentObject(appState.timerSession)
            controller.installRoot(root)
        case .timer:
            let root = TimerWindowView()
                .environmentObject(settingsStore)
                .environmentObject(taskStore)
                .environmentObject(bridge)
                .environmentObject(appState.timerEngine)
                .environmentObject(appState.timerSession)
            controller.installRoot(root)
        case .alarms:
            let root = AlarmsWindowView()
                .environmentObject(settingsStore)
                .environmentObject(taskStore)
                .environmentObject(bridge)
                .environmentObject(appState.timerEngine)
                .environmentObject(appState.timerSession)
                .environmentObject(appState.alarmEngine)
            controller.installRoot(root)
        case .settings:
            let root = SettingsWindowView()
                .environmentObject(settingsStore)
                .environmentObject(bridge)
            controller.installRoot(root)
        case .timesheet:
            let root = TimesheetWindowView()
                .environmentObject(settingsStore)
                .environmentObject(appState.timesheetStore)
                .environmentObject(appState.classificationStore)
                .environmentObject(bridge)
            controller.installRoot(root)
        case .reports:
            let root = ReportsWindowView()
                .environmentObject(settingsStore)
                .environmentObject(appState.timesheetStore)
                .environmentObject(bridge)
            controller.installRoot(root)
        }
    }
}