import Foundation
import Combine
import SwiftUI

public enum SyncStatus: Equatable {
    case idle
    case syncing
    case synced(Date)
    case offline
    case error(String)

    public var title: String {
        switch self {
        case .idle: return "Idle"
        case .syncing: return "Syncing..."
        case .synced(let date):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Synced \(formatter.string(from: date))"
        case .offline: return "Offline"
        case .error(let msg): return "Sync Error: \(msg)"
        }
    }

    public var icon: String {
        switch self {
        case .idle: return "arrow.triangle.2.circlepath"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.icloud.fill"
        case .offline: return "icloud.slash.fill"
        case .error: return "exclamationmark.icloud.fill"
        }
    }
}

@MainActor
public final class SyncStore: ObservableObject {
    public static let shared = SyncStore()

    @Published public private(set) var syncStatus: SyncStatus = .idle
    @Published public var isAutoSyncEnabled: Bool = true
    @Published public private(set) var currentUserId: String?
    @Published public private(set) var userEmail: String?

    private let db: SQLiteManager
    private var syncTimer: AnyCancellable?

    public init(db: SQLiteManager = .shared) {
        self.db = db
        startAutoSync()
    }

    public func startAutoSync() {
        syncTimer?.cancel()
        syncTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                _Concurrency.Task {
                    await self?.performSync()
                }
            }
    }

    public func performSync() async {
        guard isAutoSyncEnabled else { return }
        syncStatus = .syncing

        // Simulate lightweight local synchronization pass
        try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000)

        // In local mode or connected backend mode, refresh local stores
        TimesheetStore.shared.reloadAll()
        ClassificationStore.shared.reloadRules()

        syncStatus = .synced(Date())
    }

    public func setAccount(userId: String?, email: String?) {
        self.currentUserId = userId
        self.userEmail = email
        if userId != nil {
            _Concurrency.Task {
                await performSync()
            }
        }
    }
}
