import Foundation
import SwiftUI
import AppKit

/// The set of independent windows the app can host (V1_IMPROVEMENTS §1).
/// Each maps to its own FloatingPanel, its own persisted frame/pin state,
/// and its own SwiftUI root view.
enum WindowKind: String, Equatable {
    case todo
    case timer
    case alarms
    case settings
    case timesheet
    case reports
}

/// Owns a single FloatingPanel instance plus its per-window pin bridge,
/// frame/pin persistence, and SwiftUI content host.
final class WindowController {
    let kind: WindowKind
    let panel: FloatingPanel
    let bridge: PanelBridge
    private let settingsStore: SettingsStore

    var isVisible: Bool { panel.isVisible }

    init(kind: WindowKind, settingsStore: SettingsStore) {
        self.kind = kind
        self.settingsStore = settingsStore
        self.bridge = PanelBridge()

        let targetPanel: FloatingPanel
        if kind == .settings {
            targetPanel = FloatingPanel(
                contentRect: NSRect(x: 0, y: 0, width: 660, height: 560),
                minSize: NSSize(width: 580, height: 480)
            )
        } else if kind == .timesheet {
            targetPanel = FloatingPanel(
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 540),
                minSize: NSSize(width: 500, height: 440)
            )
        } else if kind == .reports {
            targetPanel = FloatingPanel(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                minSize: NSSize(width: 480, height: 420)
            )
        } else {
            targetPanel = FloatingPanel()
        }
        self.panel = targetPanel

        // Per-window pin state persists independently (§1.2).
        let keys = settingsStore.settings.windowPinned
        bridge.isPinned = keys[kind.rawValue, default: false]

        // Restore this window's own saved frame (§1.1, §7).
        if let frame = settingsStore.settings.windowFrames[kind.rawValue] {
            panel.setFrame(frame, display: false)
        }

        if bridge.isPinned {
            applyPinned()
        } else {
            applyUnpinned()
        }

        bridge.onTogglePin = { [weak self] in
            self?.togglePinned()
        }
        bridge.onClose = { [weak self] in
            self?.hide()
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidMoveOrResize),
            name: NSWindow.didMoveNotification, object: panel
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidMoveOrResize),
            name: NSWindow.didResizeNotification, object: panel
        )
    }

    func installRoot<Content: View>(_ content: Content) {
        panel.contentViewController = NSHostingController(rootView: content)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NotificationCenter.default.post(name: .panelDidOpen, object: self)
    }

    func hide() { panel.orderOut(nil) }

    /// Brings an already-open window to front; if closed, opens it.
    func focus() {
        show()
    }

    func setPinned(_ pinned: Bool) {
        bridge.isPinned = pinned
        settingsStore.settings.windowPinned[kind.rawValue] = pinned
        settingsStore.saveNow()
        if pinned { applyPinned() } else { applyUnpinned() }
    }

    func togglePinned() { setPinned(!bridge.isPinned) }

    func saveFrame() {
        settingsStore.settings.windowFrames[kind.rawValue] = panel.frame
        settingsStore.saveNow()
    }

    func saveFrameIfVisible() {
        if panel.isVisible { saveFrame() }
    }

    private func applyPinned() {
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    private func applyUnpinned() {
        panel.level = .normal
        panel.collectionBehavior = [.moveToActiveSpace]
    }

    @objc private func windowDidMoveOrResize(_ notification: Notification) {
        saveFrameIfVisible()
    }
}

extension Notification.Name {
    static let panelDidOpen = Notification.Name("Loopin.panelDidOpen")
}