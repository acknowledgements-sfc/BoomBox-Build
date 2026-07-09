#if DEBUG
import SwiftUI

struct LTA_OutputLatencyView: View {
    @StateObject private var model = LTA_OutputLatencyModel()
    @State private var copied = false

    var body: some View {
        List {
            Section("Phone Label") {
                TextField("e.g. iPhone-A", text: $model.phoneLabel)
            }

            Section("Current Route") {
                LabeledContent("Route", value: model.snapshot.routeDescription)
                LabeledContent("outputLatency", value: "\(formatMs(model.snapshot.outputLatencyMs)) ms")
                LabeledContent("ioBufferDuration", value: "\(formatMs(model.snapshot.ioBufferDurationMs)) ms")
            }

            if model.snapshot.isAirPlayOnly {
                Section {
                    Text("AirPlay is out of scope for LT-A. Connect a Bluetooth speaker or headphones.")
                        .foregroundStyle(.orange)
                }
            }

            if let sessionError = model.sessionError {
                Section {
                    Text(sessionError).foregroundStyle(.red)
                }
            }

            if let warning = model.routeChangeWarning {
                Section {
                    Text(warning).foregroundStyle(.orange)
                }
            }

            Section {
                Button("Log Row") {
                    model.logCurrentRow()
                }
                Button(copied ? "Copied!" : "Copy Log Table") {
                    HarnessLogExporter.copyToPasteboard(model.copyLog())
                    copied = true
                }
            }

            if !model.loggedRows.isEmpty {
                Section("Logged Rows") {
                    ForEach(Array(model.loggedRows.enumerated()), id: \.offset) { _, row in
                        Text(row).font(.caption.monospaced())
                    }
                }
            }
        }
        .navigationTitle("LT-A Latency")
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private func formatMs(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
#endif
