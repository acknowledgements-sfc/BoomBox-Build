#if DEBUG
import SwiftUI

struct LTC_HostTimeView: View {
    @StateObject private var harness = LTC_HostTimeHarness()
    @State private var copied = false

    var body: some View {
        List {
            Section {
                Text("Measures render-time accuracy of play(at:) via an audio tap. This is graph timing, not acoustic output (see LT-A for output path).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Settings") {
                Stepper(
                    "Scheduled delta: \(String(format: "%.1f", harness.scheduledDeltaSeconds)) s",
                    value: $harness.scheduledDeltaSeconds,
                    in: 0.5...5.0,
                    step: 0.5
                )
                .disabled(harness.isRunning)

                Stepper("Trials: \(harness.trialCount)", value: $harness.trialCount, in: 1...10)
                    .disabled(harness.isRunning)
            }

            Section {
                Button(harness.isRunning ? "Running..." : "Run Trials") {
                    Task { await harness.runAllTrials() }
                }
                .disabled(harness.isRunning)

                Button("Reset", role: .destructive) {
                    harness.reset()
                }
                .disabled(harness.isRunning)
            }

            Section("Status") {
                Text(harness.status)
            }

            if let error = harness.lastError {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }

            if !harness.trials.isEmpty {
                Section("Results") {
                    ForEach(harness.trials) { trial in
                        HStack {
                            Text("Trial \(trial.id)")
                            Spacer()
                            Text(String(format: "%+.2f ms", trial.measuredErrorMs))
                                .monospacedDigit()
                        }
                    }
                    Button(copied ? "Copied!" : "Copy Results Table") {
                        let rows = harness.trials.map { trial in
                            "\(trial.id) | \(String(format: "%.1f", trial.scheduledDeltaSeconds)) | \(String(format: "%.2f", trial.measuredErrorMs))"
                        }
                        HarnessLogExporter.copyToPasteboard(
                            HarnessLogExporter.markdownTable(
                                rows: rows,
                                headers: ["Trial", "scheduled delta (s)", "measured error (ms)"]
                            )
                        )
                        copied = true
                    }
                }
            }
        }
        .navigationTitle("LT-C Host Time")
        .onDisappear { harness.reset() }
    }
}
#endif
