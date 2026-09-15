import Foundation

public struct CalendarLink: Codable, Equatable, Sendable {
    public var provider: String
    public var calendarIdPlanned: String?
    public var calendarIdLogged: String?
    public var syncToken: String?
    public var accountId: String?
    public var accountEmail: String?
    public var lastSyncAt: Date?
    public var isEnabled: Bool

    public init(
        provider: String = "google",
        calendarIdPlanned: String? = nil,
        calendarIdLogged: String? = nil,
        syncToken: String? = nil,
        accountId: String? = nil,
        accountEmail: String? = nil,
        lastSyncAt: Date? = nil,
        isEnabled: Bool = false
    ) {
        self.provider = provider
        self.calendarIdPlanned = calendarIdPlanned
        self.calendarIdLogged = calendarIdLogged
        self.syncToken = syncToken
        self.accountId = accountId
        self.accountEmail = accountEmail
        self.lastSyncAt = lastSyncAt
        self.isEnabled = isEnabled
    }
}
