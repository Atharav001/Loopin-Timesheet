import SwiftUI

/// Quick-Add View for Planned Time Blocks (DESIGN.md §3.1):
/// Accepts natural language ("tomorrow 3pm gym", "today 14:00-15:30 coding")
/// Parses date/time live and auto-classifies with local dictionary.
public struct TimesheetQuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var timesheetStore: TimesheetStore
    @EnvironmentObject private var classificationStore: ClassificationStore

    @State private var rawInput: String = ""
    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(30 * 60)
    @State private var selectedCategory: String = "Deep Work"
    @State private var selectedProductivity: ProductivityCategory = .productive

    private let nlpParser = TimesheetNLPParser.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(AppTheme.accentTeal)
                    .font(.system(size: 16, weight: .bold))
                Text("Plan Time Block")
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

            // NLP Natural Language Input
            VStack(alignment: .leading, spacing: 6) {
                Text("Natural Language Quick-Add")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                HStack {
                    TextField("e.g. today 2pm-3:30pm design review, tomorrow 3pm gym", text: $rawInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textPrimary)
                        .onChange(of: rawInput) { newValue in
                            parseInput(newValue)
                        }

                    if !rawInput.isEmpty {
                        Button(action: { rawInput = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppTheme.textSecondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(AppTheme.surface)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.accentTeal.opacity(rawInput.isEmpty ? 0.3 : 0.8), lineWidth: 1)
                )
            }

            // Parsed Preview Card
            VStack(alignment: .leading, spacing: 10) {
                Text("Parsed Block Details")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                VStack(spacing: 8) {
                    HStack {
                        Text("Activity:")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        TextField("Title", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    HStack {
                        Text("Start:")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        DatePicker("", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }

                    HStack {
                        Text("End:")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        DatePicker("", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }

                    HStack {
                        Text("Category:")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)

                        Picker("", selection: $selectedCategory) {
                            Text("Deep Work").tag("Deep Work")
                            Text("Meetings").tag("Meetings")
                            Text("Learning").tag("Learning")
                            Text("Admin").tag("Admin")
                            Text("Exercise").tag("Exercise")
                            Text("Meals").tag("Meals")
                            Text("Rest").tag("Rest")
                            Text("Uncategorized").tag("Uncategorized")
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedCategory) { newCat in
                            updateProductivityForCategory(newCat)
                        }

                        Spacer()

                        // Productivity Badge
                        Text(selectedProductivity.title)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(selectedProductivity.color.opacity(0.18))
                            .foregroundColor(selectedProductivity.color)
                            .cornerRadius(4)
                    }
                }
                .padding(12)
                .background(AppTheme.surfaceElevated)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.borderSubtle, lineWidth: 1)
                )
            }

            // Quick Preset Chips
            HStack(spacing: 8) {
                presetButton(label: "+30m Coding", text: "coding for 30m")
                presetButton(label: "+1h Meeting", text: "meeting for 1h")
                presetButton(label: "+45m Gym", text: "gym for 45m")
                presetButton(label: "+15m Break", text: "break for 15m")
            }

            Spacer()

            // Save Button
            Button(action: savePlannedBlock) {
                HStack {
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add Planned Block")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                }
                .foregroundColor(.black)
                .padding(.vertical, 10)
                .background(AppTheme.accentTeal)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(20)
        .frame(width: 440, height: 420)
        .background(AppTheme.background)
        .onAppear {
            parseInput(rawInput)
        }
    }

    // MARK: - Helpers

    private func presetButton(label: String, text: String) -> some View {
        Button(action: {
            rawInput = text
            parseInput(text)
        }) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.surface)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppTheme.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func parseInput(_ text: String) {
        let parsed = nlpParser.parse(input: text, baseDate: timesheetStore.selectedDate)
        title = parsed.title
        startDate = parsed.startDate
        endDate = parsed.endDate

        // Auto classify
        let result = classificationStore.classify(text: parsed.title)
        if result.category != "Uncategorized" {
            selectedCategory = result.category
            selectedProductivity = result.productivity
        }
    }

    private func updateProductivityForCategory(_ cat: String) {
        switch cat {
        case "Deep Work", "Meetings", "Learning", "Admin", "Exercise":
            selectedProductivity = .productive
        case "Meals", "Commute", "Rest":
            selectedProductivity = .neutral
        case "Social Scrolling", "Binge Watching", "Movie Watching", "YouTube Watching", "Gaming", "Other Unproductive":
            selectedProductivity = .wasteful
        default:
            selectedProductivity = .uncategorized
        }
    }

    private func savePlannedBlock() {
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalTitle.isEmpty else { return }

        _ = timesheetStore.quickAddPlanned(
            text: finalTitle,
            start: startDate,
            end: endDate,
            category: selectedCategory,
            productivity: selectedProductivity
        )
        dismiss()
    }
}
