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
}
