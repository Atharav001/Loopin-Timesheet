import Foundation
import SQLite3

public final class SQLiteManager: @unchecked Sendable {
    public static let shared = SQLiteManager()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.loopin.sqlitemanager", qos: .userInitiated)

    public var databaseURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Loopin", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("loopin_timesheet.sqlite")
    }

    public init(customPath: String? = nil) {
        let path = customPath ?? databaseURL.path
        openDatabase(at: path)
        createTables()
        seedDefaultRulesIfNeeded()
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    private func openDatabase(at path: String) {
        if sqlite3_open(path, &db) == SQLITE_OK {
            // Enable WAL mode for high concurrency & performance
            execute(sql: "PRAGMA journal_mode = WAL;")
            execute(sql: "PRAGMA synchronous = NORMAL;")
            execute(sql: "PRAGMA foreign_keys = ON;")
        } else {
            print("Failed to open SQLite database at \(path): \(errorMessage)")
        }
    }

    private var errorMessage: String {
        if let db = db, let msg = sqlite3_errmsg(db) {
            return String(cString: msg)
        }
        return "Unknown SQLite error"
    }

    private func execute(sql: String) {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err != nil ? String(cString: err!) : "Unknown error"
            print("SQLite execution error on [\(sql)]: \(msg)")
            sqlite3_free(err)
        }
    }

    private func createTables() {
        queue.sync {
            // Timesheet Entries Table
            execute(sql: """
            CREATE TABLE IF NOT EXISTS timesheet_entries (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                start_at REAL NOT NULL,
                end_at REAL NOT NULL,
                raw_text TEXT NOT NULL,
                input_method TEXT NOT NULL,
                category TEXT NOT NULL,
                subcategory TEXT,
                productivity TEXT NOT NULL,
                gcal_event_id TEXT,
                updated_at REAL NOT NULL,
                device_id TEXT NOT NULL,
                is_deleted INTEGER DEFAULT 0
            );
            """)

            execute(sql: "CREATE INDEX IF NOT EXISTS idx_entries_time ON timesheet_entries(start_at, kind);")
            execute(sql: "CREATE INDEX IF NOT EXISTS idx_entries_updated ON timesheet_entries(updated_at);")

            // Classification Rules Table
            execute(sql: """
            CREATE TABLE IF NOT EXISTS classification_rules (
                id TEXT PRIMARY KEY,
                phrase TEXT UNIQUE NOT NULL,
                category TEXT NOT NULL,
                subcategory TEXT,
                productivity TEXT NOT NULL,
                user_defined INTEGER NOT NULL,
                created_at REAL NOT NULL
            );
            """)

            execute(sql: "CREATE INDEX IF NOT EXISTS idx_rules_phrase ON classification_rules(phrase);")

            // Calendar Links Table
            execute(sql: """
            CREATE TABLE IF NOT EXISTS calendar_links (
                provider TEXT PRIMARY KEY,
                calendar_id_planned TEXT,
                calendar_id_logged TEXT,
                sync_token TEXT,
                account_id TEXT,
                account_email TEXT,
                last_sync_at REAL,
                is_enabled INTEGER NOT NULL
            );
            """)
        }
    }

    private func seedDefaultRulesIfNeeded() {
        queue.sync {
            var count: Int32 = 0
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM classification_rules", -1, &statement, nil) == SQLITE_OK {
                if sqlite3_step(statement) == SQLITE_ROW {
                    count = sqlite3_column_int(statement, 0)
                }
            }
            sqlite3_finalize(statement)

            if count == 0 {
                let defaultRules = ClassificationRule.defaultStarterRules
                for rule in defaultRules {
                    saveRuleInternal(rule)
                }
            }
        }
    }

    // MARK: - TimesheetEntry CRUD

    public func saveEntry(_ entry: TimesheetEntry) {
        queue.sync {
            let sql = """
            INSERT INTO timesheet_entries (
                id, kind, start_at, end_at, raw_text, input_method,
                category, subcategory, productivity, gcal_event_id,
                updated_at, device_id, is_deleted
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
            ON CONFLICT(id) DO UPDATE SET
                kind = excluded.kind,
                start_at = excluded.start_at,
                end_at = excluded.end_at,
                raw_text = excluded.raw_text,
                input_method = excluded.input_method,
                category = excluded.category,
                subcategory = excluded.subcategory,
                productivity = excluded.productivity,
                gcal_event_id = excluded.gcal_event_id,
                updated_at = excluded.updated_at,
                device_id = excluded.device_id,
                is_deleted = 0;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, entry.id.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, entry.kind.rawValue, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(stmt, 3, entry.startAt.timeIntervalSince1970)
                sqlite3_bind_double(stmt, 4, entry.endAt.timeIntervalSince1970)
                sqlite3_bind_text(stmt, 5, entry.rawText, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 6, entry.inputMethod.rawValue, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 7, entry.category, -1, SQLITE_TRANSIENT)
                if let sub = entry.subcategory {
                    sqlite3_bind_text(stmt, 8, sub, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(stmt, 8)
                }
                sqlite3_bind_text(stmt, 9, entry.productivity.rawValue, -1, SQLITE_TRANSIENT)
                if let gcal = entry.gcalEventId {
                    sqlite3_bind_text(stmt, 10, gcal, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(stmt, 10)
                }
                sqlite3_bind_double(stmt, 11, entry.updatedAt.timeIntervalSince1970)
                sqlite3_bind_text(stmt, 12, entry.deviceId, -1, SQLITE_TRANSIENT)

                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("Error saving entry: \(errorMessage)")
                }
            }
            sqlite3_finalize(stmt)
        }
    }

    public func deleteEntry(id: UUID, hardDelete: Bool = false) {
        queue.sync {
            if hardDelete {
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(db, "DELETE FROM timesheet_entries WHERE id = ?", -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
                    sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
            } else {
                var stmt: OpaquePointer?
                let sql = "UPDATE timesheet_entries SET is_deleted = 1, updated_at = ? WHERE id = ?"
                if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
                    sqlite3_bind_text(stmt, 2, id.uuidString, -1, SQLITE_TRANSIENT)
                    sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
            }
        }
    }

    public func fetchEntries(from startDate: Date? = nil, to endDate: Date? = nil, kind: TimesheetKind? = nil) -> [TimesheetEntry] {
        queue.sync {
            var conditions: [String] = ["is_deleted = 0"]
            if startDate != nil { conditions.append("start_at >= ?") }
            if endDate != nil { conditions.append("start_at <= ?") }
            if kind != nil { conditions.append("kind = ?") }

            let sql = "SELECT id, kind, start_at, end_at, raw_text, input_method, category, subcategory, productivity, gcal_event_id, updated_at, device_id FROM timesheet_entries WHERE \(conditions.joined(separator: " AND ")) ORDER BY start_at ASC;"

            var stmt: OpaquePointer?
            var results: [TimesheetEntry] = []

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                var bindIndex: Int32 = 1
                if let start = startDate {
                    sqlite3_bind_double(stmt, bindIndex, start.timeIntervalSince1970)
                    bindIndex += 1
                }
                if let end = endDate {
                    sqlite3_bind_double(stmt, bindIndex, end.timeIntervalSince1970)
                    bindIndex += 1
                }
                if let k = kind {
                    sqlite3_bind_text(stmt, bindIndex, k.rawValue, -1, SQLITE_TRANSIENT)
                    bindIndex += 1
                }

                while sqlite3_step(stmt) == SQLITE_ROW {
                    guard let idStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
                          let id = UUID(uuidString: idStr),
                          let kindStr = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }),
                          let kind = TimesheetKind(rawValue: kindStr),
                          let rawText = sqlite3_column_text(stmt, 4).map({ String(cString: $0) }),
                          let methodStr = sqlite3_column_text(stmt, 5).map({ String(cString: $0) }),
                          let method = InputMethod(rawValue: methodStr),
                          let cat = sqlite3_column_text(stmt, 6).map({ String(cString: $0) }),
                          let prodStr = sqlite3_column_text(stmt, 8).map({ String(cString: $0) }),
                          let prod = ProductivityCategory(rawValue: prodStr),
                          let devId = sqlite3_column_text(stmt, 11).map({ String(cString: $0) })
                    else { continue }

                    let start = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
                    let end = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
                    let subcat = sqlite3_column_text(stmt, 7).map({ String(cString: $0) })
                    let gcal = sqlite3_column_text(stmt, 9).map({ String(cString: $0) })
                    let updated = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 10))

                    results.append(TimesheetEntry(
                        id: id,
                        kind: kind,
                        startAt: start,
                        endAt: end,
                        rawText: rawText,
                        inputMethod: method,
                        category: cat,
                        subcategory: subcat,
                        productivity: prod,
                        gcalEventId: gcal,
                        updatedAt: updated,
                        deviceId: devId
                    ))
                }
            }
            sqlite3_finalize(stmt)
            return results
        }
    }

    // MARK: - ClassificationRule CRUD

    private func saveRuleInternal(_ rule: ClassificationRule) {
        let sql = """
        INSERT INTO classification_rules (id, phrase, category, subcategory, productivity, user_defined, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(phrase) DO UPDATE SET
            category = excluded.category,
            subcategory = excluded.subcategory,
            productivity = excluded.productivity,
            user_defined = excluded.user_defined;
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, rule.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, rule.phrase.lowercased(), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, rule.category, -1, SQLITE_TRANSIENT)
            if let sub = rule.subcategory {
                sqlite3_bind_text(stmt, 4, sub, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 4)
            }
            sqlite3_bind_text(stmt, 5, rule.productivity.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 6, rule.userDefined ? 1 : 0)
            sqlite3_bind_double(stmt, 7, rule.createdAt.timeIntervalSince1970)

            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func saveRule(_ rule: ClassificationRule) {
        queue.sync {
            saveRuleInternal(rule)
        }
    }

    public func deleteRule(id: UUID) {
        queue.sync {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "DELETE FROM classification_rules WHERE id = ?", -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    public func fetchRules() -> [ClassificationRule] {
        queue.sync {
            let sql = "SELECT id, phrase, category, subcategory, productivity, user_defined, created_at FROM classification_rules ORDER BY user_defined DESC, phrase ASC;"
            var stmt: OpaquePointer?
            var results: [ClassificationRule] = []

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    guard let idStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
                          let id = UUID(uuidString: idStr),
                          let phrase = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }),
                          let cat = sqlite3_column_text(stmt, 2).map({ String(cString: $0) }),
                          let prodStr = sqlite3_column_text(stmt, 4).map({ String(cString: $0) }),
                          let prod = ProductivityCategory(rawValue: prodStr)
                    else { continue }

                    let subcat = sqlite3_column_text(stmt, 3).map({ String(cString: $0) })
                    let userDef = sqlite3_column_int(stmt, 5) == 1
                    let created = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6))

                    results.append(ClassificationRule(
                        id: id,
                        phrase: phrase,
                        category: cat,
                        subcategory: subcat,
                        productivity: prod,
                        userDefined: userDef,
                        createdAt: created
                    ))
                }
            }
            sqlite3_finalize(stmt)
            return results
        }
    }

    // MARK: - CalendarLink CRUD

    public func saveCalendarLink(_ link: CalendarLink) {
        queue.sync {
            let sql = """
            INSERT INTO calendar_links (
                provider, calendar_id_planned, calendar_id_logged,
                sync_token, account_id, account_email, last_sync_at, is_enabled
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(provider) DO UPDATE SET
                calendar_id_planned = excluded.calendar_id_planned,
                calendar_id_logged = excluded.calendar_id_logged,
                sync_token = excluded.sync_token,
                account_id = excluded.account_id,
                account_email = excluded.account_email,
                last_sync_at = excluded.last_sync_at,
                is_enabled = excluded.is_enabled;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, link.provider, -1, SQLITE_TRANSIENT)
                if let p = link.calendarIdPlanned { sqlite3_bind_text(stmt, 2, p, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 2) }
                if let l = link.calendarIdLogged { sqlite3_bind_text(stmt, 3, l, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 3) }
                if let s = link.syncToken { sqlite3_bind_text(stmt, 4, s, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 4) }
                if let a = link.accountId { sqlite3_bind_text(stmt, 5, a, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 5) }
                if let e = link.accountEmail { sqlite3_bind_text(stmt, 6, e, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 6) }
                if let syncDate = link.lastSyncAt { sqlite3_bind_double(stmt, 7, syncDate.timeIntervalSince1970) } else { sqlite3_bind_null(stmt, 7) }
                sqlite3_bind_int(stmt, 8, link.isEnabled ? 1 : 0)

                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    public func fetchCalendarLink(provider: String = "google") -> CalendarLink? {
        queue.sync {
            let sql = "SELECT provider, calendar_id_planned, calendar_id_logged, sync_token, account_id, account_email, last_sync_at, is_enabled FROM calendar_links WHERE provider = ? LIMIT 1;"
            var stmt: OpaquePointer?
            var result: CalendarLink?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, provider, -1, SQLITE_TRANSIENT)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let prov = String(cString: sqlite3_column_text(stmt, 0))
                    let planId = sqlite3_column_text(stmt, 1).map({ String(cString: $0) })
                    let logId = sqlite3_column_text(stmt, 2).map({ String(cString: $0) })
                    let token = sqlite3_column_text(stmt, 3).map({ String(cString: $0) })
                    let accId = sqlite3_column_text(stmt, 4).map({ String(cString: $0) })
                    let email = sqlite3_column_text(stmt, 5).map({ String(cString: $0) })
                    var lastSync: Date?
                    if sqlite3_column_type(stmt, 6) != SQLITE_NULL {
                        lastSync = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6))
                    }
                    let enabled = sqlite3_column_int(stmt, 7) == 1

                    result = CalendarLink(
                        provider: prov,
                        calendarIdPlanned: planId,
                        calendarIdLogged: logId,
                        syncToken: token,
                        accountId: accId,
                        accountEmail: email,
                        lastSyncAt: lastSync,
                        isEnabled: enabled
                    )
                }
            }
            sqlite3_finalize(stmt)
            return result
        }
    }
}

// Global SQLITE_TRANSIENT constant wrapper
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
