import Foundation
import Combine
import SwiftUI

@MainActor
public final class TimesheetStore: ObservableObject {
    public static let shared = TimesheetStore()

    private let db: SQLiteManager
    @Published public private(set) var entries: [TimesheetEntry] = []
    @Published public var selectedDate: Date = Date() {
        didSet {
            reloadForSelectedDate()
        }
    }
    @Published public private(set) var todayPlannedEntries: [TimesheetEntry] = []
    @Published public private(set) var todayLoggedEntries: [TimesheetEntry] = []
    @Published public private(set) var weekEntries: [TimesheetEntry] = []

    public init(db: SQLiteManager = .shared) {
        self.db = db
        reloadAll()
    }

    public func reloadAll() {
        reloadForSelectedDate()
        reloadWeekEntries()
    }

    public func reloadForSelectedDate() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) else { return }

        let dayEntries = db.fetchEntries(from: startOfDay, to: endOfDay)
        self.entries = dayEntries
        self.todayPlannedEntries = dayEntries.filter { $0.kind == .planned }
        self.todayLoggedEntries = dayEntries.filter { $0.kind == .logged }
    }

    public func reloadWeekEntries() {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return }
        self.weekEntries = db.fetchEntries(from: weekInterval.start, to: weekInterval.end)
    }

    // MARK: - Mutations

    public func addEntry(_ entry: TimesheetEntry) {
        db.saveEntry(entry)
        reloadAll()
    }

    public func updateEntry(_ entry: TimesheetEntry) {
        var updated = entry
        updated.updatedAt = Date()
        db.saveEntry(updated)
        reloadAll()
    }

    public func deleteEntry(id: UUID) {
        db.deleteEntry(id: id)
        reloadAll()
    }

    public func quickAddPlanned(
        text: String,
        start: Date,
        end: Date,
        category: String = "Deep Work",
        productivity: ProductivityCategory = .productive
    ) -> TimesheetEntry {
        let entry = TimesheetEntry(
            kind: .planned,
            startAt: start,
            endAt: end,
            rawText: text,
            inputMethod: .typed,
            category: category,
            productivity: productivity
        )
        addEntry(entry)
        return entry
    }

    public func quickAddLogged(
        text: String,
        inputMethod: InputMethod = .typed,
        category: String = "Uncategorized",
        productivity: ProductivityCategory = .uncategorized,
        start: Date,
        end: Date
    ) -> TimesheetEntry {
        let entry = TimesheetEntry(
            kind: .logged,
            startAt: start,
            endAt: end,
            rawText: text,
            inputMethod: inputMethod,
            category: category,
            productivity: productivity
        )
        addEntry(entry)
        return entry
    }

    public func logSkipped(start: Date, end: Date) -> TimesheetEntry {
        let entry = TimesheetEntry(
            kind: .logged,
            startAt: start,
            endAt: end,
            rawText: "",
            inputMethod: .skipped,
            category: "Skipped",
            productivity: .neutral
        )
        addEntry(entry)
        return entry
    }

    // MARK: - Filtering helpers

    public func plannedEntries(for date: Date) -> [TimesheetEntry] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return db.fetchEntries(from: start, to: end, kind: .planned)
    }

    public func loggedEntries(for date: Date) -> [TimesheetEntry] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return db.fetchEntries(from: start, to: end, kind: .logged)
    }

    // MARK: - Demo & Seed Helpers

    public func seedSampleDay(for date: Date = Date()) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Helper to construct a Date on the selected day
        func makeTime(hour: Int, minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: startOfDay) ?? startOfDay
        }

        // 1. Planned Intent (Top Rail: Cyan Outlines)
        let p1 = TimesheetEntry(
            kind: .planned,
            startAt: makeTime(hour: 9, minute: 0),
            endAt: makeTime(hour: 11, minute: 30),
            rawText: "Core Engine Architecture & Tests",
            inputMethod: .typed,
            category: "Deep Work",
            productivity: .productive
        )
        let p2 = TimesheetEntry(
            kind: .planned,
            startAt: makeTime(hour: 11, minute: 30),
            endAt: makeTime(hour: 12, minute: 30),
            rawText: "Team Architecture Review",
            inputMethod: .typed,
            category: "Meetings",
            productivity: .productive
        )
        let p3 = TimesheetEntry(
            kind: .planned,
            startAt: makeTime(hour: 13, minute: 0),
            endAt: makeTime(hour: 14, minute: 0),
            rawText: "Lunch & Recharge",
            inputMethod: .typed,
            category: "Meals",
            productivity: .neutral
        )
        let p4 = TimesheetEntry(
            kind: .planned,
            startAt: makeTime(hour: 14, minute: 0),
            endAt: makeTime(hour: 16, minute: 30),
            rawText: "Timesheet UI Glassmorphism Polish",
            inputMethod: .typed,
            category: "Deep Work",
            productivity: .productive
        )
        let p5 = TimesheetEntry(
            kind: .planned,
            startAt: makeTime(hour: 17, minute: 0),
            endAt: makeTime(hour: 18, minute: 0),
            rawText: "Strength Training Gym",
            inputMethod: .typed,
            category: "Exercise",
            productivity: .productive
        )
        let p6 = TimesheetEntry(
            kind: .planned,
            startAt: makeTime(hour: 20, minute: 0),
            endAt: makeTime(hour: 21, minute: 0),
            rawText: "SwiftUI Animation Architecture",
            inputMethod: .typed,
            category: "Learning",
            productivity: .productive
        )

        // 2. Logged Reality (Bottom Rail: Solid Emerald/Amber/Slate)
        let l1 = TimesheetEntry(
            kind: .logged,
            startAt: makeTime(hour: 9, minute: 0),
            endAt: makeTime(hour: 10, minute: 45),
            rawText: "Core Engine Architecture & Tests",
            inputMethod: .typed,
            category: "Deep Work",
            productivity: .productive
        )
        let l2 = TimesheetEntry(
            kind: .logged,
            startAt: makeTime(hour: 10, minute: 45),
            endAt: makeTime(hour: 11, minute: 15),
            rawText: "Social media scrolling",
            inputMethod: .voice,
            category: "Social Scrolling",
            productivity: .wasteful
        )
        let l3 = TimesheetEntry(
            kind: .logged,
            startAt: makeTime(hour: 11, minute: 15),
            endAt: makeTime(hour: 11, minute: 30),
            rawText: "",
            inputMethod: .skipped,
            category: "Skipped",
            productivity: .neutral
        )
        let l4 = TimesheetEntry(
            kind: .logged,
            startAt: makeTime(hour: 11, minute: 30),
            endAt: makeTime(hour: 12, minute: 30),
            rawText: "Team Architecture Review",
            inputMethod: .typed,
            category: "Meetings",
            productivity: .productive
        )
        let l5 = TimesheetEntry(
            kind: .logged,
            startAt: makeTime(hour: 12, minute: 30),
            endAt: makeTime(hour: 13, minute: 30),
            rawText: "Lunch & Coffee with team",
            inputMethod: .typed,
            category: "Meals",
            productivity: .neutral
        )
        let l6 = TimesheetEntry(
            kind: .logged,
            startAt: makeTime(hour: 13, minute: 30),
            endAt: makeTime(hour: 14, minute: 15),
            rawText: "YouTube video binge",
            inputMethod: .voice,
            category: "YouTube Watching",
            productivity: .wasteful
        )
        let l7 = TimesheetEntry(
            kind: .logged,
            startAt: makeTime(hour: 14, minute: 15),
            endAt: makeTime(hour: 16, minute: 45),
            rawText: "Timesheet UI Glassmorphism Polish",
            inputMethod: .typed,
            category: "Deep Work",
            productivity: .productive
        )
        let l8 = TimesheetEntry(
            kind: .logged,
            startAt: makeTime(hour: 17, minute: 0),
            endAt: makeTime(hour: 18, minute: 0),
            rawText: "Strength Training Gym",
            inputMethod: .voice,
            category: "Exercise",
            productivity: .productive
        )

        let allSample = [p1, p2, p3, p4, p5, p6, l1, l2, l3, l4, l5, l6, l7, l8]
        for entry in allSample {
            db.saveEntry(entry)
        }
        reloadAll()
    }

    public func clearDay(for date: Date = Date()) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) else { return }

        let dayEntries = db.fetchEntries(from: startOfDay, to: endOfDay)
        for entry in dayEntries {
            db.deleteEntry(id: entry.id)
        }
        reloadAll()
    }
}

