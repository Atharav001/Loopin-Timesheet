import Foundation
import Combine
import SwiftUI

@MainActor
public final class IntervalLoggingEngine: ObservableObject {
    public static let shared = IntervalLoggingEngine()

    @Published public var isEnabled: Bool = true {
        didSet {
            if isEnabled {
                restartTimer()
            } else {
                stopTimer()
            }
        }
    }
    @Published public var intervalMinutes: Int = 15 {
        didSet {
            restartTimer()
        }
    }
    @Published public private(set) var isPromptActive: Bool = false
    @Published public private(set) var isOverdue: Bool = false
    @Published public private(set) var currentIntervalStart: Date = Date()
    @Published public private(set) var currentIntervalEnd: Date = Date()
    @Published public private(set) var secondsUntilNextPrompt: Int = 0

    public var onPromptRequired: ((Date, Date) -> Void)?

    private var timerCancellable: AnyCancellable?
    private var overdueCancellable: AnyCancellable?
    private var lastPromptTime: Date = Date()

    public init(intervalMinutes: Int = 15) {
        self.intervalMinutes = intervalMinutes
        self.currentIntervalStart = Date().addingTimeInterval(-Double(intervalMinutes * 60))
        self.currentIntervalEnd = Date()
        self.secondsUntilNextPrompt = intervalMinutes * 60
        if isEnabled {
            restartTimer()
        }
    }

    public func restartTimer() {
        stopTimer()
        lastPromptTime = Date()
        secondsUntilNextPrompt = intervalMinutes * 60

        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.tick(now: now)
            }
    }

    public func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        overdueCancellable?.cancel()
        overdueCancellable = nil
    }

    private func tick(now: Date) {
        if !isPromptActive {
            secondsUntilNextPrompt = max(0, secondsUntilNextPrompt - 1)
            if secondsUntilNextPrompt <= 0 {
                triggerPrompt(at: now)
            }
        } else {
            // If prompt is active and open for > 60 seconds without response, mark as overdue
            let elapsedSincePrompt = now.timeIntervalSince(lastPromptTime)
            if elapsedSincePrompt > 60 && !isOverdue {
                isOverdue = true
            }
        }
    }

    public func triggerPrompt(at date: Date = Date()) {
        isPromptActive = true
        isOverdue = false
        lastPromptTime = date

        let intervalSeconds = Double(intervalMinutes * 60)
        currentIntervalStart = date.addingTimeInterval(-intervalSeconds)
        currentIntervalEnd = date

        onPromptRequired?(currentIntervalStart, currentIntervalEnd)
    }

    public func completePrompt(
        rawText: String,
        inputMethod: InputMethod,
        category: String,
        productivity: ProductivityCategory,
        timesheetStore: TimesheetStore
    ) {
        _ = timesheetStore.quickAddLogged(
            text: rawText,
            inputMethod: inputMethod,
            category: category,
            productivity: productivity,
            start: currentIntervalStart,
            end: currentIntervalEnd
        )

        dismissPrompt()
    }

    public func skipPrompt(timesheetStore: TimesheetStore) {
        _ = timesheetStore.logSkipped(
            start: currentIntervalStart,
            end: currentIntervalEnd
        )

        dismissPrompt()
    }

    public func dismissPrompt() {
        isPromptActive = false
        isOverdue = false
        restartTimer()
    }
}
