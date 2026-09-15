import Foundation

public struct ParsedTimeBlock: Equatable, Sendable {
    public let title: String
    public let startDate: Date
    public let endDate: Date

    public init(title: String, startDate: Date, endDate: Date) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
    }
}

public final class TimesheetNLPParser {
    public static let shared = TimesheetNLPParser()

    public init() {}

    /// Parses quick-add natural language input into a title, startDate, and endDate.
    public func parse(input: String, baseDate: Date = Date()) -> ParsedTimeBlock {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return ParsedTimeBlock(
                title: "Focus Block",
                startDate: baseDate,
                endDate: baseDate.addingTimeInterval(30 * 60)
            )
        }

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) ?? []

        var detectedStart: Date?
        var detectedEnd: Date?
        var detectedRange: NSRange?

        for match in matches {
            if let date = match.date {
                detectedStart = date
                detectedRange = match.range
                if match.duration > 0 {
                    detectedEnd = date.addingTimeInterval(match.duration)
                }
                break
            }
        }

        // Clean up title by removing the detected date/time string
        var title = text
        if let range = detectedRange, let swiftRange = Range(range, in: text) {
            title = text.replacingCharacters(in: swiftRange, with: "")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Strip common leading prepositions like "at", "for", "on", "from"
        let prepositions = ["at ", "from ", "for ", "on "]
        for prep in prepositions {
            if title.lowercased().hasPrefix(prep) {
                title = String(title.dropFirst(prep.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if title.isEmpty {
            title = "Planned Session"
        }

        let start = detectedStart ?? baseDate
        let end = detectedEnd ?? start.addingTimeInterval(30 * 60)

        // Ensure start is before end
        let finalEnd = end > start ? end : start.addingTimeInterval(30 * 60)

        return ParsedTimeBlock(title: title, startDate: start, endDate: finalEnd)
    }
}
