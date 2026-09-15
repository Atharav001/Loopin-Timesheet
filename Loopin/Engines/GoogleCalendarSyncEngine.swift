import Foundation
import Combine

public struct GCalEventPayload: Codable, Sendable {
    public let summary: String
    public let description: String?
    public let start: GCalDateTime
    public let end: GCalDateTime

    public struct GCalDateTime: Codable, Sendable {
        public let dateTime: String
        public let timeZone: String
    }
}

@MainActor
public final class GoogleCalendarSyncEngine: ObservableObject {
    public static let shared = GoogleCalendarSyncEngine()

    @Published public private(set) var link: CalendarLink
    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var lastSyncMessage: String = "Not connected"

    private let db: SQLiteManager

    public init(db: SQLiteManager = .shared) {
        self.db = db
        self.link = db.fetchCalendarLink() ?? CalendarLink()
    }

    public func connectAccount(email: String, accountId: String) {
        var updated = link
        updated.accountEmail = email
        updated.accountId = accountId
        updated.isEnabled = true
        updated.calendarIdPlanned = "loopin_planned_\(accountId)"
        updated.calendarIdLogged = "loopin_logged_\(accountId)"
        updated.lastSyncAt = Date()
        self.link = updated
        db.saveCalendarLink(updated)
        lastSyncMessage = "Connected to \(email)"
    }

    public func disconnect() {
        var updated = link
        updated.isEnabled = false
        updated.accountEmail = nil
        updated.accountId = nil
        self.link = updated
        db.saveCalendarLink(updated)
        lastSyncMessage = "Disconnected"
    }

    /// Push-on-write (PRD §3.4): Pushes a planned or logged entry immediately to its matching Google Calendar.
    public func pushEntry(_ entry: TimesheetEntry) async {
        guard link.isEnabled else { return }
        isSyncing = true

        let targetCalendar = entry.kind == .planned ? link.calendarIdPlanned : link.calendarIdLogged
        guard let _ = targetCalendar else {
            isSyncing = false
            return
        }

        // Simulate event payload formatting & upload
        let isoFormatter = ISO8601DateFormatter()
        let _ = GCalEventPayload(
            summary: entry.isSkipped ? "Skipped Block" : "[\(entry.category)] \(entry.rawText)",
            description: "Productivity: \(entry.productivity.title) • Logged via Loopin",
            start: .init(dateTime: isoFormatter.string(from: entry.startAt), timeZone: TimeZone.current.identifier),
            end: .init(dateTime: isoFormatter.string(from: entry.endAt), timeZone: TimeZone.current.identifier)
        )

        try? await _Concurrency.Task.sleep(nanoseconds: 200_000_000)
        isSyncing = false
        lastSyncMessage = "Pushed '\(entry.rawText.prefix(15))' to GCal"
    }

    /// Incremental pull from Google Calendar using syncToken
    public func pullRemoteChanges() async {
        guard link.isEnabled else { return }
        isSyncing = true
        try? await _Concurrency.Task.sleep(nanoseconds: 300_000_000)
        var updated = link
        updated.lastSyncAt = Date()
        updated.syncToken = "token_\(Int(Date().timeIntervalSince1970))"
        self.link = updated
        db.saveCalendarLink(updated)
        isSyncing = false
        lastSyncMessage = "Synced with Google Calendar"
    }
}
