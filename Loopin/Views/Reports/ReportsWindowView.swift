import SwiftUI

public struct ReportsWindowView: View {
    @EnvironmentObject private var bridge: PanelBridge
    @EnvironmentObject private var timesheetStore: TimesheetStore

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            WindowHeaderView(title: "Reports & Analytics")

            Divider()
                .background(AppTheme.borderSubtle)

            ReportsView()
                .environmentObject(timesheetStore)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 520, minHeight: 480)
        .background(AppTheme.background)
        .glow(
            accent: AppTheme.accentTeal,
            intensity: .standard,
            active: bridge.isPinned
        )
    }
}
