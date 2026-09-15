import Foundation
import Combine
import SwiftUI

@MainActor
public final class ClassificationStore: ObservableObject {
    public static let shared = ClassificationStore()

    private let db: SQLiteManager
    private let classifier: LocalClassifier
    @Published public private(set) var rules: [ClassificationRule] = []

    public init(db: SQLiteManager = .shared, classifier: LocalClassifier = .shared) {
        self.db = db
        self.classifier = classifier
        reloadRules()
    }

    public func reloadRules() {
        self.rules = db.fetchRules()
    }

    public func classify(text: String) -> ClassificationResult {
        return classifier.classify(text: text, rules: rules)
    }

    /// User correction flow (PRD §3.3): Persists an override rule so the same phrase auto-classifies accurately next time.
    public func learnCorrection(
        rawText: String,
        category: String,
        productivity: ProductivityCategory,
        subcategory: String? = nil
    ) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }

        // Extract the most representative keywords/phrase
        let phrase = trimmed
        let rule = ClassificationRule(
            phrase: phrase,
            category: category,
            subcategory: subcategory,
            productivity: productivity,
            userDefined: true,
            createdAt: Date()
        )

        db.saveRule(rule)
        reloadRules()
    }

    public func addOrUpdateRule(_ rule: ClassificationRule) {
        db.saveRule(rule)
        reloadRules()
    }

    public func deleteRule(id: UUID) {
        db.deleteRule(id: id)
        reloadRules()
    }

    // MARK: - JSON Export / Import (Phase 24 cross-platform dictionary sharing)

    public func exportRulesJSON() -> Data? {
        return try? JSONEncoder().encode(rules)
    }

    public func importRulesJSON(_ data: Data) -> Bool {
        guard let imported = try? JSONDecoder().decode([ClassificationRule].self, from: data) else { return false }
        for rule in imported {
            db.saveRule(rule)
        }
        reloadRules()
        return true
    }
}
