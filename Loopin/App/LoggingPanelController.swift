import AppKit
import SwiftUI

/// Dedicated floating panel controller for Interval Logging prompts (PRD §3.2 & Phase 18).
/// Configured to float over all spaces and full-screen applications.
@MainActor
public final class LoggingPanelController {
    public static let shared = LoggingPanelController()

    private var panel: NSPanel?
    private var isInstalled = false

    public init() {}

    public func setup(
        intervalEngine: IntervalLoggingEngine,
        timesheetStore: TimesheetStore,
        classificationStore: ClassificationStore
    ) {
        intervalEngine.onPromptRequired = { [weak self] start, end in
            DispatchQueue.main.async {
                self?.presentPrompt(
                    intervalEngine: intervalEngine,
                    timesheetStore: timesheetStore,
                    classificationStore: classificationStore
                )
            }
        }
    }

    public func presentPrompt(
        intervalEngine: IntervalLoggingEngine,
        timesheetStore: TimesheetStore,
        classificationStore: ClassificationStore
    ) {
        if panel == nil {
            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 200),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isFloatingPanel = true
            p.hidesOnDeactivate = false
            p.becomesKeyOnlyIfNeeded = false
            p.isReleasedWhenClosed = false
            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = true
            p.level = .floating

            // Float cleanly over full-screen spaces & auxiliary apps (Phase 18 key requirement)
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

            let rootView = LoggingPromptPanel()
                .environmentObject(intervalEngine)
                .environmentObject(timesheetStore)
                .environmentObject(classificationStore)

            p.contentViewController = NSHostingController(rootView: rootView)
            self.panel = p
        }

        guard let panel = panel else { return }

        // Position at top-right of main screen or mouse screen
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let x = visibleFrame.maxX - 360
            let y = visibleFrame.maxY - 220
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    public func dismiss() {
        panel?.orderOut(nil)
    }
}
