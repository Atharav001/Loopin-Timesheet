import Foundation

/// Standalone test suite verifying Timesheet & Logbook Module core business logic,
/// SQLite persistence, Local Classifier dictionary matching, NLP time parsing,
/// and interval logging prompt handling.
@MainActor
public final class TimesheetModuleTests {
    public static func runAllTests() {
        print("🚀 [Loopin Tests] Starting Timesheet Module Test Suite...")

        testSQLiteManagerCRUD()
        testLocalClassifier()
        testClassifierUserOverrides()
        testNLPParser()
        testIntervalLoggingEngine()
        testReportsCalculations()

        print("🎉 [Loopin Tests] All Timesheet & Logbook tests PASSED successfully!")
    }

    // MARK: - Test 1: SQLiteManager CRUD & Time Filters

    public static func testSQLiteManagerCRUD() {
        print("  ▶ Testing SQLiteManager CRUD...")
        let tempDbPath = NSTemporaryDirectory() + "loopin_test_\(UUID().uuidString).sqlite"
        let db = SQLiteManager(customPath: tempDbPath)

        let start = Date()
        let end = start.addingTimeInterval(1800)
        let entry = TimesheetEntry(
            kind: .planned,
            startAt: start,
            endAt: end,
            rawText: "Deep work on Loopin architecture",
            inputMethod: .typed,
            category: "Deep Work",
            productivity: .productive
        )

        // Save
        db.saveEntry(entry)

        // Fetch
        let fetched = db.fetchEntries(from: start.addingTimeInterval(-10), to: end.addingTimeInterval(10))
        assert(!fetched.isEmpty, "Entry should be fetched from SQLite")
        assert(fetched.first?.rawText == "Deep work on Loopin architecture", "Raw text must match")
        assert(fetched.first?.productivity == .productive, "Productivity must match")
        assert(fetched.first?.kind == .planned, "Kind must be planned")

        // Update
        var updated = entry
        updated.rawText = "Deep work on Swift compiler"
        updated.category = "Deep Work"
        db.saveEntry(updated)

        let refetched = db.fetchEntries(from: start.addingTimeInterval(-10), to: end.addingTimeInterval(10))
        assert(refetched.first?.rawText == "Deep work on Swift compiler", "Updated text must match")

        // Delete
        db.deleteEntry(id: entry.id)
        let empty = db.fetchEntries(from: start.addingTimeInterval(-10), to: end.addingTimeInterval(10))
        assert(empty.isEmpty, "Deleted entry should not appear in active queries")

        // Cleanup
        try? FileManager.default.removeItem(atPath: tempDbPath)
        print("    ✅ SQLiteManager CRUD passed.")
    }

    // MARK: - Test 2: LocalClassifier Taxonomy Matching

    public static func testLocalClassifier() {
        print("  ▶ Testing LocalClassifier Starter Taxonomy...")
        let classifier = LocalClassifier()
        let rules = ClassificationRule.defaultStarterRules

        // Productive tests
        let test1 = classifier.classify(text: "Spent 45 mins coding a new feature in xcode", rules: rules)
        assert(test1.productivity == .productive, "Coding should be classified as productive")
        assert(test1.category == "Deep Work", "Coding category should be Deep Work")

        let test2 = classifier.classify(text: "Weekly team standup and sync", rules: rules)
        assert(test2.productivity == .productive, "Standup should be classified as productive")
        assert(test2.category == "Meetings", "Standup category should be Meetings")

        let test3 = classifier.classify(text: "Hit the gym for a heavy lifting workout", rules: rules)
        assert(test3.productivity == .productive, "Gym should be classified as productive")
        assert(test3.category == "Exercise", "Gym category should be Exercise")

        // Neutral tests
        let test4 = classifier.classify(text: "Grabbed lunch with coworkers", rules: rules)
        assert(test4.productivity == .neutral, "Lunch should be neutral")
        assert(test4.category == "Meals", "Lunch category should be Meals")

        let test5 = classifier.classify(text: "Quick afternoon nap", rules: rules)
        assert(test5.productivity == .neutral, "Nap should be neutral")
        assert(test5.category == "Rest", "Nap category should be Rest")

        // Wasteful tests
        let test6 = classifier.classify(text: "Watched youtube videos and scrolled reddit", rules: rules)
        assert(test6.productivity == .wasteful, "YouTube/Reddit should be wasteful")

        let test7 = classifier.classify(text: "Playing dota with friends", rules: rules)
        assert(test7.productivity == .wasteful, "Gaming should be wasteful")
        assert(test7.category == "Gaming", "Gaming category should be Gaming")

        // Uncategorized test
        let test8 = classifier.classify(text: "xyz random string without matches", rules: rules)
        assert(test8.productivity == .uncategorized, "Unrecognized text should be uncategorized")

        print("    ✅ LocalClassifier taxonomy passed.")
    }

    // MARK: - Test 3: User Override Learning Loop

    public static func testClassifierUserOverrides() {
        print("  ▶ Testing User Override Learning Loop...")
        let tempDbPath = NSTemporaryDirectory() + "loopin_rules_\(UUID().uuidString).sqlite"
        let db = SQLiteManager(customPath: tempDbPath)
        let store = ClassificationStore(db: db)

        // Text that starts as uncategorized
        let customPhrase = "Figma wireframe polish"
        let initial = store.classify(text: customPhrase)
        assert(initial.productivity == .uncategorized, "Should start uncategorized")

        // User corrects and learns
        store.learnCorrection(
            rawText: customPhrase,
            category: "Design",
            productivity: .productive
        )

        // Re-classify same phrase
        let learned = store.classify(text: "Did some Figma wireframe polish this morning")
        assert(learned.category == "Design", "Learned category must match")
        assert(learned.productivity == .productive, "Learned productivity must match")

        try? FileManager.default.removeItem(atPath: tempDbPath)
        print("    ✅ User Override Learning Loop passed.")
    }

    // MARK: - Test 4: NLP Time Block Parser

    public static func testNLPParser() {
        print("  ▶ Testing TimesheetNLPParser...")
        let parser = TimesheetNLPParser()
        let now = Date()

        let parsed1 = parser.parse(input: "Gym workout", baseDate: now)
        assert(parsed1.title == "Gym workout", "Title should match")
        assert(parsed1.endDate > parsed1.startDate, "End date should be after start date")

        let parsed2 = parser.parse(input: "Team sync at 3pm", baseDate: now)
        assert(parsed2.title.contains("Team sync"), "Title should extract cleaned title")

        print("    ✅ TimesheetNLPParser passed.")
    }

    // MARK: - Test 5: Interval Logging Prompt Engine

    public static func testIntervalLoggingEngine() {
        print("  ▶ Testing IntervalLoggingEngine...")
        let engine = IntervalLoggingEngine(intervalMinutes: 10)
        let tempDbPath = NSTemporaryDirectory() + "loopin_engine_\(UUID().uuidString).sqlite"
        let db = SQLiteManager(customPath: tempDbPath)
        let store = TimesheetStore(db: db)

        var promptFired = false
        engine.onPromptRequired = { start, end in
            promptFired = true
        }

        engine.triggerPrompt()
        assert(promptFired, "onPromptRequired callback must fire")
        assert(engine.isPromptActive, "isPromptActive should be true")

        // Complete prompt
        engine.completePrompt(
            rawText: "Refactoring database indexes",
            inputMethod: .typed,
            category: "Deep Work",
            productivity: .productive,
            timesheetStore: store
        )

        assert(!engine.isPromptActive, "isPromptActive should reset after completion")
        let entries = store.entries
        assert(entries.count == 1, "Completed prompt must write entry to store")
        assert(entries.first?.kind == .logged, "Entry kind must be logged")

        // Skip prompt
        engine.triggerPrompt()
        engine.skipPrompt(timesheetStore: store)
        let updatedEntries = store.entries
        assert(updatedEntries.count == 2, "Skipped prompt must write skipped entry to store")
        assert(updatedEntries.last?.isSkipped == true, "Last entry must be marked skipped")

        try? FileManager.default.removeItem(atPath: tempDbPath)
        print("    ✅ IntervalLoggingEngine passed.")
    }

    // MARK: - Test 6: Reports Calculations

    public static func testReportsCalculations() {
        print("  ▶ Testing Reports Duration & Ratio Calculations...")
        let e1 = TimesheetEntry(kind: .logged, startAt: Date(), endAt: Date().addingTimeInterval(3600), rawText: "Code", category: "Deep Work", productivity: .productive)
        let e2 = TimesheetEntry(kind: .logged, startAt: Date(), endAt: Date().addingTimeInterval(1800), rawText: "Lunch", category: "Meals", productivity: .neutral)
        let e3 = TimesheetEntry(kind: .logged, startAt: Date(), endAt: Date().addingTimeInterval(1800), rawText: "Social", category: "Social Scrolling", productivity: .wasteful)

        let total = e1.duration + e2.duration + e3.duration
        assert(total == 7200, "Total duration must equal 2 hours")
        assert(e1.duration / total == 0.50, "Productive fraction should be 50%")
        assert(e2.duration / total == 0.25, "Neutral fraction should be 25%")
        assert(e3.duration / total == 0.25, "Wasteful fraction should be 25%")

        print("    ✅ Reports Calculations passed.")
    }
}
