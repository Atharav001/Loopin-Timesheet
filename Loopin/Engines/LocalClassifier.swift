import Foundation

public struct ClassificationResult: Equatable, Sendable {
    public let category: String
    public let subcategory: String?
    public let productivity: ProductivityCategory
    public let matchedRule: ClassificationRule?

    public static let uncategorized = ClassificationResult(
        category: "Uncategorized",
        subcategory: nil,
        productivity: .uncategorized,
        matchedRule: nil
    )
}

public final class LocalClassifier: @unchecked Sendable {
    public static let shared = LocalClassifier()

    public init() {}

    /// Classifies raw text against the provided rules (or defaults).
    /// Matches longer multi-word phrases first, and prioritizes user-defined rules over defaults.
    public func classify(text: String, rules: [ClassificationRule]) -> ClassificationResult {
        let cleaned = normalize(text)
        if cleaned.isEmpty {
            return .uncategorized
        }

        // Sort rules: User-defined rules first, then longer phrases first
        let sortedRules = rules.sorted { (a, b) -> Bool in
            if a.userDefined != b.userDefined {
                return a.userDefined && !b.userDefined
            }
            return a.phrase.count > b.phrase.count
        }

        // 1. Direct contains / regex word boundary match
        for rule in sortedRules {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: rule.phrase.lowercased()) + "\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: cleaned.utf16.count)
                if regex.firstMatch(in: cleaned, options: [], range: range) != nil {
                    return ClassificationResult(
                        category: rule.category,
                        subcategory: rule.subcategory,
                        productivity: rule.productivity,
                        matchedRule: rule
                    )
                }
            } else if cleaned.contains(rule.phrase.lowercased()) {
                return ClassificationResult(
                    category: rule.category,
                    subcategory: rule.subcategory,
                    productivity: rule.productivity,
                    matchedRule: rule
                )
            }
        }

        return .uncategorized
    }

    private func normalize(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
