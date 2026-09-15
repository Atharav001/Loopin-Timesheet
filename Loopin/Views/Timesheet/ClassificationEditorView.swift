import SwiftUI

/// Correction & Reclassification View (PRD §3.3 & Phase 19):
/// Allows editing an entry's category and productivity rating, and persisting an override
/// rule to the personal dictionary so the phrase auto-classifies accurately going forward.
public struct ClassificationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var timesheetStore: TimesheetStore
    @EnvironmentObject private var classificationStore: ClassificationStore

    @State private var entry: TimesheetEntry
    @State private var rawText: String
    @State private var category: String
    @State private var productivity: ProductivityCategory
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var saveAsRule: Bool = true

    private let categoriesByProductivity: [ProductivityCategory: [String]] = [
        .productive: ["Deep Work", "Meetings", "Learning", "Admin", "Exercise", "Feature Dev", "Review"],
        .neutral: ["Meals", "Commute", "Rest", "Break", "Errand"],
        .wasteful: ["Social Scrolling", "Binge Watching", "Movie Watching", "YouTube Watching", "Gaming", "Other Unproductive"],
        .uncategorized: ["Uncategorized"]
    ]

    public init(entry: TimesheetEntry) {
        _entry = State(initialValue: entry)
        _rawText = State(initialValue: entry.rawText)
        _category = State(initialValue: entry.category)
        _productivity = State(initialValue: entry.productivity)
        _startDate = State(initialValue: entry.startAt)
        _endDate = State(initialValue: entry.endAt)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Circle()
                    .fill(productivity.color)
                    .frame(width: 10, height: 10)
                Text(entry.kind == .planned ? "Edit Planned Block" : "Edit Logged Entry")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.textSecondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }

            // Raw Text Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Activity Description")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                TextField("What was done / planned", text: $rawText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(10)
                    .background(AppTheme.surface)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.borderSubtle, lineWidth: 1)
                    )
            }

            // Time range & Duration
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Time")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                    DatePicker("", selection: $startDate, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("End Time")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                    DatePicker("", selection: $endDate, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                    Text("\(max(1, Int(endDate.timeIntervalSince(startDate) / 60))) min")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.accentTeal)
                        .padding(.top, 4)
                }
            }
            .padding(10)
            .background(AppTheme.surface)
            .cornerRadius(8)

            // Productivity Selector (Productive / Neutral / Wasteful)
            VStack(alignment: .leading, spacing: 6) {
                Text("Productivity Rating")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                HStack(spacing: 8) {
                    productivityPill(type: .productive)
                    productivityPill(type: .neutral)
                    productivityPill(type: .wasteful)
                }
            }

            // Category Chips for the selected productivity
            VStack(alignment: .leading, spacing: 6) {
                Text("Category")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(categoriesByProductivity[productivity] ?? ["Uncategorized"], id: \.self) { cat in
                            Button(action: { category = cat }) {
                                Text(cat)
                                    .font(.system(size: 11, weight: category == cat ? .bold : .medium))
                                    .foregroundColor(category == cat ? .black : AppTheme.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(category == cat ? productivity.color : AppTheme.surface)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(category == cat ? productivity.color : AppTheme.borderSubtle, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Rule override persistence toggle
            if entry.kind == .logged && !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Toggle(isOn: $saveAsRule) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remember as classification rule")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Future logs matching \"\(rawText.prefix(25))\" will auto-tag as \(category)")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .toggleStyle(.checkbox)
                .padding(.vertical, 4)
            }

            Spacer()

            // Actions (Delete / Save)
            HStack(spacing: 12) {
                Button(action: deleteEntry) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.accentCoral)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.accentCoral.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: saveChanges) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Save Changes")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(productivity.color)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 440, height: 460)
        .background(AppTheme.background)
    }

    private func productivityPill(type: ProductivityCategory) -> some View {
        Button(action: {
            productivity = type
            if let firstCat = categoriesByProductivity[type]?.first {
                category = firstCat
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 10))
                Text(type.title)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(productivity == type ? .black : type.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(productivity == type ? type.color : type.color.opacity(0.12))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(type.color, lineWidth: productivity == type ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func saveChanges() {
        var updated = entry
        updated.rawText = rawText
        updated.category = category
        updated.productivity = productivity
        updated.startAt = startDate
        updated.endAt = endDate

        timesheetStore.updateEntry(updated)

        if saveAsRule && entry.kind == .logged && !rawText.isEmpty {
            classificationStore.learnCorrection(
                rawText: rawText,
                category: category,
                productivity: productivity
            )
        }

        dismiss()
    }

    private func deleteEntry() {
        timesheetStore.deleteEntry(id: entry.id)
        dismiss()
    }
}
