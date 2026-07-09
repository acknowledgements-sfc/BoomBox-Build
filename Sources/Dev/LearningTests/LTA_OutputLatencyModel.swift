#if DEBUG
import AVFoundation
import Combine
import Foundation

struct LTA_RouteSnapshot: Equatable {
    let routeDescription: String
    let outputLatencyMs: Double
    let ioBufferDurationMs: Double
    let isAirPlayOnly: Bool
}

@MainActor
final class LTA_OutputLatencyModel: ObservableObject {
    @Published var phoneLabel = "iPhone"
    @Published var snapshot = LTA_RouteSnapshot(
        routeDescription: "—",
        outputLatencyMs: 0,
        ioBufferDurationMs: 0,
        isAirPlayOnly: false
    )
    @Published var loggedRows: [String] = []
    @Published var routeChangeWarning: String?
    @Published var sessionError: String?

    private var routeObserver: NSObjectProtocol?
    private var previousLatencyMs: Double?

    func start() {
        configureSession()
        refreshSnapshot()
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleRouteChange()
            }
        }
    }

    func stop() {
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
            self.routeObserver = nil
        }
    }

    func logCurrentRow() {
        let btName = snapshot.isAirPlayOnly ? "(AirPlay — skip)" : snapshot.routeDescription
        let row = "\(phoneLabel) | \(btName) | \(formatMs(snapshot.outputLatencyMs)) | \(formatMs(snapshot.ioBufferDurationMs))"
        loggedRows.append(row)
    }

    func copyLog() -> String {
        HarnessLogExporter.markdownTable(
            rows: loggedRows,
            headers: ["Phone", "BT device", "outputLatency (ms)", "ioBufferDuration (ms)"]
        )
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true)
            sessionError = nil
        } catch {
            sessionError = error.localizedDescription
        }
    }

    private func handleRouteChange() {
        let before = previousLatencyMs
        refreshSnapshot()
        if let before, abs(before - snapshot.outputLatencyMs) < 0.01 {
            routeChangeWarning = "Route changed but outputLatency unchanged — log anyway and note in DECISIONS."
        } else {
            routeChangeWarning = nil
        }
    }

    private func refreshSnapshot() {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        let routeDescription = outputs.map { "\($0.portName) (\($0.portType.rawValue))" }
            .joined(separator: ", ")
        let isAirPlayOnly = !outputs.isEmpty && outputs.allSatisfy {
            $0.portType == .airPlay
        }
        let latencyMs = session.outputLatency * 1000
        previousLatencyMs = latencyMs
        snapshot = LTA_RouteSnapshot(
            routeDescription: routeDescription.isEmpty ? "No output route" : routeDescription,
            outputLatencyMs: latencyMs,
            ioBufferDurationMs: session.ioBufferDuration * 1000,
            isAirPlayOnly: isAirPlayOnly
        )
    }

    private func formatMs(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
#endif
