import AppKit
import Combine
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var panelController: PanelController?
    private var reminderScheduler: ReminderScheduler?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--run-tests") {
            TimesheetModuleTests.runAllTests()
            exit(0)
        }

        let settingsStore = SettingsStore()
        let taskStore = TaskStore()
        let timerSession = TimerSession()

        let panelController = PanelController(
            settingsStore: settingsStore,
            taskStore: taskStore,
            timerSession: timerSession
        )
        self.panelController = panelController

        let statusBarController = StatusBarController(
            panelController: panelController,
            timerSession: timerSession
        )
        self.statusBarController = statusBarController

        timerSession.$phase
            .sink { _ in statusBarController.refreshIcon() }
            .store(in: &cancellables)
        timerSession.$reminderPending
            .sink { _ in statusBarController.refreshIcon() }
            .store(in: &cancellables)

        // Reminder escalation (FR-7).
        let scheduler = ReminderScheduler(
            session: timerSession,
            engine: panelController.timerEngine,
            settingsStore: settingsStore,
            taskStore: taskStore
        )
        self.reminderScheduler = scheduler

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        ReminderScheduler.registerCategories()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Opening any window acknowledges any pending reminder.
        NotificationCenter.default.publisher(for: .panelDidOpen)
            .sink { [weak self] _ in self?.reminderScheduler?.acknowledge() }
            .store(in: &cancellables)

        // Focus Interval Alarm (§3.3 & §6.1/6.4): triggers full-screen attention overlay
        // with Accent Violet glow and "Interval check-in" card message.
        panelController.alarmEngine.onAlarm = { [weak settingsStore] in
            let intensity = settingsStore?.settings.stimulationIntensity ?? .standard
            AttentionOverlayManager.shared.trigger(event: .alarmFired, stimulationIntensity: intensity)
            statusBarController.pulseForAlarm()
        }

        // Interval Logging Panel Setup (Phases 17-18)
        LoggingPanelController.shared.setup(
            intervalEngine: IntervalLoggingEngine.shared,
            timesheetStore: TimesheetStore.shared,
            classificationStore: ClassificationStore.shared
        )

        // Present Timesheet & Logbook window on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            panelController.focus(.timesheet)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController?.saveAllOnTerminate()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        reminderScheduler?.handleAction(identifier: response.actionIdentifier)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}