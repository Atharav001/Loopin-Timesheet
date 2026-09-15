import Foundation

public struct ClassificationRule: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var phrase: String
    public var category: String
    public var subcategory: String?
    public var productivity: ProductivityCategory
    public var userDefined: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        phrase: String,
        category: String,
        subcategory: String? = nil,
        productivity: ProductivityCategory,
        userDefined: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.phrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.category = category
        self.subcategory = subcategory
        self.productivity = productivity
        self.userDefined = userDefined
        self.createdAt = createdAt
    }

    public static var defaultStarterRules: [ClassificationRule] {
        var rules: [ClassificationRule] = []

        // Productive - Deep Work
        for phrase in ["deep work", "coding", "programming", "building", "swift", "xcode", "writing code", "debugging", "algorithm", "architecture", "developing", "feature dev", "refactoring"] {
            rules.append(ClassificationRule(phrase: phrase, category: "Deep Work", productivity: .productive))
        }

        // Productive - Meetings
        for phrase in ["meeting", "sync", "standup", "team call", "1:1", "interview", "discussion", "client call", "zoom", "google meet"] {
            rules.append(ClassificationRule(phrase: phrase, category: "Meetings", productivity: .productive))
        }

        // Productive - Learning
        for phrase in ["reading", "study", "studying", "course", "lecture", "tutorial", "research", "paper", "documentation", "book", "learning"] {
            rules.append(ClassificationRule(phrase: phrase, category: "Learning", productivity: .productive))
        }

        // Productive - Admin
        for phrase in ["email", "inbox", "slack", "planning", "organizing", "taxes", "bills", "scheduling", "admin work", "filing"] {
            rules.append(ClassificationRule(phrase: phrase, category: "Admin", productivity: .productive))
        }

        // Productive - Exercise
        for phrase in ["gym", "workout", "running", "walk", "walking", "yoga", "training", "exercise", "lifting", "swimming", "cycling"] {
            rules.append(ClassificationRule(phrase: phrase, category: "Exercise", productivity: .productive))
        }

        // Neutral - Meals
        for phrase in ["breakfast", "lunch", "dinner", "eating", "food", "coffee", "snack", "cooking", "meal", "brunch"] {
            rules.append(ClassificationRule(phrase: phrase, category: "Meals", productivity: .neutral))
        }

        // Neutral - Commute
        for phrase in ["commute", "driving", "transit", "subway", "train", "bus", "flight", "traffic", "traveling"] {
            rules.append(ClassificationRule(phrase: phrase, category: "Commute", productivity: .neutral))
        }

        // Neutral - Rest
        for phrase in ["nap", "sleep", "resting", "meditation", "break", "breather", "stretching", "chilling", "relaxing"] {
            rules.append(ClassificationRule(phrase: phrase, category: "Rest", productivity: .neutral))
        }

        // Wasteful - Social Scrolling
        for phrase in ["twitter", "x.com", "instagram", "reels", "tiktok", "reddit", "facebook", "scrolling", "social media", "feed", "doomscrolling"] {
            rules.append(ClassificationRule(phrase: phrase, category: "Social Scrolling", productivity: .wasteful))
        }

        // Wasteful - Binge Watching
        for phrase in ["netflix", "series", "tv show", "anime", "hulu", "streaming", "prime video", "disney+", "binging"] {
            rules.append(ClassificationRule(phrase: phrase, category: "Binge Watching", productivity: .wasteful))
        }

        // Wasteful - Movie Watching
        for phrase in ["movie", "cinema", "film", "watching movie"] {
            rules.append(ClassificationRule(phrase: phrase, category: "Movie Watching", productivity: .wasteful))
        }

        // Wasteful - YouTube Watching
        for phrase in ["youtube", "yt", "youtube video", "watching youtube", "watching videos"] {
            rules.append(ClassificationRule(phrase: phrase, category: "YouTube Watching", productivity: .wasteful))
        }

        // Wasteful - Gaming
        for phrase in ["gaming", "game", "games", "steam", "playstation", "xbox", "switch", "valorant", "dota", "league", "fortnite", "minecraft"] {
            rules.append(ClassificationRule(phrase: phrase, category: "Gaming", productivity: .wasteful))
        }

        // Wasteful - Other Unproductive
        for phrase in ["procrastinating", "zoned out", "aimless browsing", "rabbit hole", "daydreaming", "wasting time"] {
            rules.append(ClassificationRule(phrase: phrase, category: "Other Unproductive", productivity: .wasteful))
        }

        return rules
    }
}
