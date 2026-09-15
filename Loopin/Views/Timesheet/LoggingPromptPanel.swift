import SwiftUI

/// Interval Logging Prompt Panel (PRD §3.2 & DESIGN.md §3.2):
/// Native always-on-top panel with breathing glow border, autofocused text input,
/// on-device speech-to-text capture, skip action, and instant classification feedback.
public struct LoggingPromptPanel: View {
    @EnvironmentObject private var intervalEngine: IntervalLoggingEngine
    @EnvironmentObject private var timesheetStore: TimesheetStore
    @EnvironmentObject private var classificationStore: ClassificationStore
    @StateObject private var speechService = SpeechRecognitionService.shared

    @State private var rawText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showRipple: Bool = false
    @FocusState private var isInputFocused: Bool

    public var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                // Header with interval time badge
                HStack {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .foregroundColor(intervalEngine.isOverdue ? Color(hex: "#F59E0B") : AppTheme.accentTeal)
                        .font(.system(size: 15))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Interval Check-in")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("\(formattedTime(intervalEngine.currentIntervalStart)) – \(formattedTime(intervalEngine.currentIntervalEnd)) (\(intervalEngine.intervalMinutes) min)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    // Skip button (muted, non-judgmental)
                    Button(action: skipPrompt) {
                        HStack(spacing: 3) {
                            Text("Skip")
                            Image(systemName: "forward.fill")
                                .font(.system(size: 9))
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.surface)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                // Text input field with speech mic button
                HStack(spacing: 8) {
                    TextField("What did you work on?", text: $rawText)
                        .focused($isInputFocused)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                        .onSubmit {
                            submitPrompt()
                        }

                    // Mic Button (Speech-to-Text)
                    Button(action: {
                        speechService.toggleRecording()
                    }) {
                        ZStack {
                            Circle()
                                .fill(speechService.isRecording ? AppTheme.accentCoral : AppTheme.surfaceElevated)
                                .frame(width: 28, height: 28)

                            if speechService.isRecording {
                                Circle()
                                    .stroke(AppTheme.accentCoral.opacity(0.5), lineWidth: 2)
                                    .scaleEffect(1.0 + CGFloat(speechService.audioLevel) * 0.8)
                            }

                            Image(systemName: speechService.isRecording ? "waveform" : "mic.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(speechService.isRecording ? .white : AppTheme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Voice capture (on-device speech-to-text)")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(AppTheme.surface)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.borderSubtle, lineWidth: 1)
                )

                // Live Classification Prediction Preview
                let prediction = classificationStore.classify(text: rawText)
                if !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(prediction.productivity.color)
                            .frame(width: 6, height: 6)

                        Text("Auto-tagging as:")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textSecondary)

                        Text(prediction.category)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(prediction.productivity.color)

                        Text("(\(prediction.productivity.title))")
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.textSecondary)

                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .transition(.opacity)
                }

                // Submit Action Button
                Button(action: submitPrompt) {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("Save Log Entry")
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                    }
                    .foregroundColor(.black)
                    .padding(.vertical, 8)
                    .background(
                        rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? AppTheme.accentTeal.opacity(0.4)
                        : AppTheme.accentTeal
                    )
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(14)
            .background(AppTheme.background)
            .cornerRadius(12)
            .breathingGlow(
                color: AppTheme.accentTeal,
                isActive: !showRipple,
                isOverdue: intervalEngine.isOverdue
            )

            // Ripple confirm ring upon submit
            if showRipple {
                RippleConfirmRing(color: AppTheme.accentTeal) {
                    intervalEngine.dismissPrompt()
                }
            }
        }
        .frame(width: 340)
        .onAppear {
            isInputFocused = true
        }
        .onReceive(speechService.$recognizedText) { text in
            if !text.isEmpty {
                self.rawText = text
            }
        }
    }

    private func submitPrompt() {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if speechService.isRecording {
            speechService.stopRecording()
        }

        let prediction = classificationStore.classify(text: trimmed)
        let method: InputMethod = speechService.recognizedText.isEmpty ? .typed : .voice

        withAnimation {
            showRipple = true
        }

        intervalEngine.completePrompt(
            rawText: trimmed,
            inputMethod: method,
            category: prediction.category,
            productivity: prediction.productivity,
            timesheetStore: timesheetStore
        )
    }

    private func skipPrompt() {
        if speechService.isRecording {
            speechService.stopRecording()
        }

        // Muted non-judgmental dismiss without ripple (DESIGN.md §3.2)
        intervalEngine.skipPrompt(timesheetStore: timesheetStore)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
