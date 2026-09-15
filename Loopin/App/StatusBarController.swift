import AppKit
import Combine

enum MenuBarIconState {
    case idle
    case focusRunning
    case breakRunning
}

/// Menu bar item. Clicking it now opens an NSMenu picker (V1_IMPROVEMENTS §1.1)
/// that forwards to one of several independent windows, not a single panel.
@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let panelController: PanelController
    private let timerSession: TimerSession

    private let pulseAnimationKey = "reminderPulse"
    private let opacityAnimationKey = "reminderOpacity"
    private var iconState: MenuBarIconState = .idle

    init(panelController: PanelController, timerSession: TimerSession) {
        self.panelController = panelController
        self.timerSession = timerSession
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        guard let button = statusItem.button else { return }
        button.wantsLayer = true
        button.image = iconImage(for: iconState)
        button.image?.isTemplate = true

        let menu = buildMenu()
        statusItem.menu = menu
        button.action = nil  // The menu is attached to the status item directly.
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let timesheetItem = menuItem(title: "Timesheet & Logbook", kind: .timesheet)
        timesheetItem.keyEquivalent = "1"
        timesheetItem.keyEquivalentModifierMask = .command
        menu.addItem(timesheetItem)

        let logNowItem = NSMenuItem(title: "Log Current Activity Now", action: #selector(logActivityNow), keyEquivalent: "l")
        logNowItem.keyEquivalentModifierMask = .command
        logNowItem.target = self
        menu.addItem(logNowItem)

        let reportsItem = menuItem(title: "Reports & Analytics", kind: .reports)
        reportsItem.keyEquivalent = "r"
        reportsItem.keyEquivalentModifierMask = .command
        menu.addItem(reportsItem)

        menu.addItem(.separator())

        let timerItem = menuItem(title: "Pomodoro / Timer / Stopwatch", kind: .timer)
        timerItem.keyEquivalent = "2"
        timerItem.keyEquivalentModifierMask = .command
        menu.addItem(timerItem)

        let todoItem = menuItem(title: "To-Do List", kind: .todo)
        todoItem.keyEquivalent = "3"
        todoItem.keyEquivalentModifierMask = .command
        menu.addItem(todoItem)

        menu.addItem(.separator())
        let settingsItem = menuItem(title: "Settings...", kind: .settings)
        settingsItem.keyEquivalent = ","
        settingsItem.keyEquivalentModifierMask = .command
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Loopin", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private func menuItem(title: String, kind: WindowKind) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: #selector(selectWindow(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = kind
        return item
    }

    @objc private func selectWindow(_ sender: NSMenuItem) {
        guard let kind = sender.representedObject as? WindowKind else { return }
        panelController.focus(kind)
    }

    @objc private func logActivityNow() {
        IntervalLoggingEngine.shared.triggerPrompt()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    /// Brief, self-clearing pulse shown when a Focus Interval Alarm fires
    /// (§3.3 "menu bar pulse" component of the attention system). Independent of
    /// the Pomodoro reminder's `reminderPending` pulse.
    func pulseForAlarm() {
        guard let button = statusItem.button else { return }
        button.image?.isTemplate = false
        button.contentTintColor = NSColor(hex: "#9B7BFF") // Accent Violet
        startPulse(on: button, variant: .c)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self else { return }
            if !self.timerSession.reminderPending {
                self.refreshIcon()
            } else {
                self.stopPulse(on: button)
                button.image?.isTemplate = false
                button.contentTintColor = NSColor(hex: "#3DDC97")
            }
        }
    }

    func refreshIcon() {
        let pending = timerSession.reminderPending
        switch timerSession.phase {
        case .focus, .timer:
            iconState = .focusRunning
        case .breakShort, .breakLong:
            iconState = .breakRunning
        case .idle:
            iconState = .idle
        }

        guard let button = statusItem.button else { return }

        if pending {
            // Stage 1: cycle symbol tinted accent + anti-habituation pulse variant.
            button.image?.isTemplate = false
            let variant = ReminderVariant.next(after: timerSession.completedFocusCyclesToday)
            button.contentTintColor = variant.color
            startPulse(on: button, variant: variant)
        } else {
            button.image?.isTemplate = true
            button.contentTintColor = nil
            stopPulse(on: button)
        }
    }

    /// Deterministic reminder variants (DESIGN §7) to counter habituation.
    enum ReminderVariant {
        case a, b, c

        static func next(after cycles: Int) -> ReminderVariant {
            switch cycles % 3 {
            case 0: return .a
            case 1: return .b
            default: return .c
            }
        }

        var color: NSColor {
            switch self {
            case .a: return NSColor(hex: "#3DDC97")
            case .b: return NSColor(hex: "#FF7A6B")
            case .c: return NSColor(hex: "#9B7BFF")
            }
        }

        var duration: Double {
            switch self {
            case .a: return 1.2
            case .b: return 1.0
            case .c: return 1.5
            }
        }
    }

    private func startPulse(on button: NSStatusBarButton, variant: ReminderVariant) {
        let duration = variant.duration

        // Scale pulse (all variants; C combines with opacity below).
        if button.layer?.animation(forKey: pulseAnimationKey) == nil {
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue = 1.0
            pulse.toValue = 1.08
            pulse.duration = duration / 2
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            button.layer?.add(pulse, forKey: pulseAnimationKey)
        }

        // Opacity pulse: subtle for A, none for B handled here; B uses opacity below.
        switch variant {
        case .a:
            removeOpacityPulse(on: button)
        case .b:
            if button.layer?.animation(forKey: opacityAnimationKey) == nil {
                let opacity = CABasicAnimation(keyPath: "opacity")
                opacity.fromValue = 0.6
                opacity.toValue = 1.0
                opacity.duration = duration / 2
                opacity.autoreverses = true
                opacity.repeatCount = .infinity
                button.layer?.add(opacity, forKey: opacityAnimationKey)
            }
        case .c:
            if button.layer?.animation(forKey: opacityAnimationKey) == nil {
                let opacity = CABasicAnimation(keyPath: "opacity")
                opacity.fromValue = 0.7
                opacity.toValue = 1.0
                opacity.duration = duration / 2
                opacity.autoreverses = true
                opacity.repeatCount = .infinity
                button.layer?.add(opacity, forKey: opacityAnimationKey)
            }
        }
    }

    private func stopPulse(on button: NSStatusBarButton) {
        button.layer?.removeAnimation(forKey: pulseAnimationKey)
        removeOpacityPulse(on: button)
        button.layer?.transform = CATransform3DIdentity
        button.layer?.opacity = 1
    }

    private func removeOpacityPulse(on button: NSStatusBarButton) {
        button.layer?.removeAnimation(forKey: opacityAnimationKey)
        button.layer?.opacity = 1
    }

    private func iconImage(for state: MenuBarIconState) -> NSImage? {
        switch state {
        case .idle:
            return createLoopinBrandIcon()
        case .focusRunning:
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            return NSImage(systemSymbolName: "stopwatch.fill", accessibilityDescription: "Loopin Focus Running")?.withSymbolConfiguration(config)
        case .breakRunning:
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            return NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "Loopin Break")?.withSymbolConfiguration(config)
        }
    }

    /// Custom retina-crisp Loopin infinity focus emblem for the macOS menu bar.
    private func createLoopinBrandIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let path = NSBezierPath()
            // Sleek infinity loop geometry
            path.move(to: NSPoint(x: 9.0, y: 9.0))
            path.curve(to: NSPoint(x: 4.5, y: 13.0), controlPoint1: NSPoint(x: 7.2, y: 11.8), controlPoint2: NSPoint(x: 5.8, y: 13.0))
            path.curve(to: NSPoint(x: 1.5, y: 9.0), controlPoint1: NSPoint(x: 2.8, y: 13.0), controlPoint2: NSPoint(x: 1.5, y: 11.2))
            path.curve(to: NSPoint(x: 4.5, y: 5.0), controlPoint1: NSPoint(x: 1.5, y: 6.8), controlPoint2: NSPoint(x: 2.8, y: 5.0))
            path.curve(to: NSPoint(x: 9.0, y: 9.0), controlPoint1: NSPoint(x: 5.8, y: 5.0), controlPoint2: NSPoint(x: 7.2, y: 6.2))
            path.curve(to: NSPoint(x: 13.5, y: 13.0), controlPoint1: NSPoint(x: 10.8, y: 11.8), controlPoint2: NSPoint(x: 12.2, y: 13.0))
            path.curve(to: NSPoint(x: 16.5, y: 9.0), controlPoint1: NSPoint(x: 15.2, y: 13.0), controlPoint2: NSPoint(x: 16.5, y: 11.2))
            path.curve(to: NSPoint(x: 13.5, y: 5.0), controlPoint1: NSPoint(x: 16.5, y: 6.8), controlPoint2: NSPoint(x: 15.2, y: 5.0))
            path.curve(to: NSPoint(x: 9.0, y: 9.0), controlPoint1: NSPoint(x: 12.2, y: 5.0), controlPoint2: NSPoint(x: 10.8, y: 6.2))

            path.lineWidth = 1.7
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.black.setStroke()
            path.stroke()

            // Center focal node
            let centerDot = NSBezierPath(ovalIn: NSRect(x: 7.8, y: 7.8, width: 2.4, height: 2.4))
            NSColor.black.setFill()
            centerDot.fill()

            return true
        }
        image.isTemplate = true
        return image
    }
}

private extension NSColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}