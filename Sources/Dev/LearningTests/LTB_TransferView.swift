#if DEBUG
import SwiftUI

struct LTB_TransferView: View {
    @StateObject private var harness = LTB_TransferHarness()
    @State private var copied = false

    var body: some View {
        List {
            Section {
                Text("Two phones on peer Wi-Fi, no internet. Phone A = Advertiser sends; Phone B = Browser receives. Accept the system invite dialog if shown.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Role") {
                Picker("Role", selection: $harness.role) {
                    ForEach(LTB_Role.allCases) { role in
                        Text(role.rawValue).tag(role)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(harness.connectedPeerName != nil)
            }

            Section("Status") {
                Text(harness.status)
                if let peer = harness.connectedPeerName {
                    LabeledContent("Peer", value: peer)
                }
            }

            if let error = harness.lastError {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section {
                Button("Start") { harness.start() }
                Button("Stop", role: .destructive) { harness.stop() }
                if harness.role == .advertiser {
                    Button("Send 5 MB mp3") { harness.sendTestFile() }
                        .disabled(harness.connectedPeerName == nil)
                }
            }

            if let result = harness.lastResult {
                Section("Result (\(result.role))") {
                    LabeledContent("Elapsed", value: String(format: "%.2f s", result.elapsedSeconds))
                    LabeledContent("File size", value: "\(result.fileSizeBytes) bytes")
                    LabeledContent("Throughput", value: String(format: "%.2f MB/s", result.throughputMBps))
                    Button(copied ? "Copied!" : "Copy Result Line") {
                        let line = String(
                            format: "- elapsed: %.2fs, throughput: %.2f MB/s",
                            result.elapsedSeconds,
                            result.throughputMBps
                        )
                        HarnessLogExporter.copyToPasteboard(line)
                        copied = true
                    }
                }
            }
        }
        .navigationTitle("LT-B Transfer")
        .onDisappear { harness.stop() }
    }
}
#endif
