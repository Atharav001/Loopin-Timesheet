import Foundation
import SwiftUI

public enum TimesheetKind: String, Codable, Equatable, CaseIterable, Sendable {
    case planned
    case logged

    public var title: String {
        switch self {
        case .planned: return "Planned"
        case .logged: return "Logged"
        }
    }

    public var icon: String {
        switch self {
        case .planned: return "calendar.badge.clock"
        case .logged: return "checkmark.circle.badge.questionmark"
        }
    }
}

public enum InputMethod: String, Codable, Equatable, CaseIterable, Sendable {
    case typed
    case voice
    case skipped

    public var title: String {
        switch self {
        case .typed: return "Typed"
        case .voice: return "Voice"
        case .skipped: return "Skipped"
        }
    }

    public var icon: String {
        switch self {
        case .typed: return "keyboard"
        case .voice: return "mic.fill"
        case .skipped: return "forward.fill"
        }
    }
}

public enum ProductivityCategory: String, Codable, Equatable, CaseIterable, Sendable {
    case productive
    case neutral
    case wasteful
    case uncategorized

    public var title: String {
        switch self {
        case .productive: return "Productive"
        case .neutral: return "Neutral"
        case .wasteful: return "Wasteful"
        case .uncategorized: return "Uncategorized"
        }
    }

    public var color: Color {
        switch self {
        case .productive: return Color(hex: "#10B981") // Vivid Emerald / On-track
        case .neutral: return Color(hex: "#94A3B8")    // Slate / Muted sky
        case .wasteful: return Color(hex: "#F59E0B")   // Warm Amber / Non-shaming
        case .uncategorized: return Color(hex: "#64748B") // Cool slate
        }
    }

    public var hexColor: String {
        switch self {
        case .productive: return "#10B981"
        case .neutral: return "#94A3B8"
        case .wasteful: return "#F59E0B"
        case .uncategorized: return "#64748B"
        }
    }

    public var icon: String {
        switch self {
        case .productive: return "flame.fill"
        case .neutral: return "pause.circle.fill"
        case .wasteful: return "clock.arrow.circlepath"
        case .uncategorized: return "questionmark.circle"
        }
    }
}

public struct TimesheetEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var kind: TimesheetKind
    public var startAt: Date
    public var endAt: Date
    public var rawText: String
    public var inputMethod: InputMethod
    public var category: String
    public var subcategory: String?
    public var productivity: ProductivityCategory
    public var gcalEventId: String?
    public var updatedAt: Date
    public var deviceId: String

    public var isSkipped: Bool {
        inputMethod == .skipped || (rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && kind == .logged)
    }

    public var duration: TimeInterval {
        max(60, endAt.timeIntervalSince(startAt))
    }

    public var durationInMinutes: Int {
        Int(duration / 60)
    }

    public init(
        id: UUID = UUID(),
        kind: TimesheetKind,
        startAt: Date,
        endAt: Date,
        rawText: String,
        inputMethod: InputMethod = .typed,
        category: String = "Uncategorized",
        subcategory: String? = nil,
        productivity: ProductivityCategory = .uncategorized,
        gcalEventId: String? = nil,
        updatedAt: Date = Date(),
        deviceId: String = TimesheetEntry.currentDeviceId
    ) {
        self.id = id
        self.kind = kind
        self.startAt = startAt
        self.endAt = endAt
        self.rawText = rawText
        self.inputMethod = inputMethod
        self.category = category
        self.subcategory = subcategory
        self.productivity = productivity
        self.gcalEventId = gcalEventId
        self.updatedAt = updatedAt
        self.deviceId = deviceId
    }

    public static var currentDeviceId: String {
        #if os(macOS)
        let name = Host.current().localizedName ?? "Mac"
        return "macOS-\(name)"
        #else
        return "device-\(UUID().uuidString.prefix(6))"
        #endif
    }
}
