#if DEBUG
import AVFoundation
import Foundation

struct LTC_TrialResult: Identifiable, Equatable {
    let id: Int
    let scheduledDeltaSeconds: Double
    let measuredErrorMs: Double
}

@MainActor
final class LTC_HostTimeHarness: ObservableObject {
    @Published var scheduledDeltaSeconds = 2.0
    @Published var trialCount = 5
    @Published var trials: [LTC_TrialResult] = []
    @Published var status = "Idle"
    @Published var lastError: String?
    @Published var isRunning = false

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?

    func runAllTrials() async {
        guard !isRunning else { return }
        isRunning = true
        lastError = nil
        trials = []
        defer { isRunning = false }

        for index in 1...trialCount {
            status = "Running trial \(index)/\(trialCount)..."
            do {
                let errorMs = try await runSingleTrial()
                trials.append(LTC_TrialResult(
                    id: index,
                    scheduledDeltaSeconds: scheduledDeltaSeconds,
                    measuredErrorMs: errorMs
                ))
            } catch {
                lastError = error.localizedDescription
                status = "Trial \(index) failed"
                break
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        if lastError == nil {
            status = "Done — \(trials.count) trials"
        }
    }

    func reset() {
        teardown()
        trials = []
        status = "Idle"
        lastError = nil
    }

    private func runSingleTrial() async throws -> Double {
        teardown()

        guard let fileURL = Bundle.main.url(forResource: "lt_click", withExtension: "wav") else {
            throw LTC_HarnessError.missingAsset
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        let file = try AVAudioFile(forReading: fileURL)
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)

        self.engine = engine
        self.playerNode = player
        self.audioFile = file

        try engine.start()
        await player.scheduleFile(file, at: nil)

        let scheduledHostTime = HostTimeHelpers.hostTime(offsetSeconds: scheduledDeltaSeconds)
        let scheduledTime = AVAudioTime(hostTime: scheduledHostTime)

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let format = file.processingFormat

            player.installTap(onBus: 0, bufferSize: 256, format: format) { buffer, time in
                guard !resumed else { return }
                let hostTime = time.hostTime
                guard self.bufferHasSignal(buffer) else { return }

                resumed = true
                player.removeTap(onBus: 0)
                let errorSeconds = HostTimeHelpers.hostTimeDifferenceSeconds(
                    scheduled: scheduledHostTime,
                    actual: hostTime
                )
                let errorMs = errorSeconds * 1000.0
                continuation.resume(returning: errorMs)
            }

            player.play(at: scheduledTime)

            Task {
                try await Task.sleep(nanoseconds: UInt64((scheduledDeltaSeconds + 3.0) * 1_000_000_000))
                if !resumed {
                    resumed = true
                    player.removeTap(onBus: 0)
                    continuation.resume(throwing: LTC_HarnessError.timeout)
                }
            }
        }
    }

    private func bufferHasSignal(_ buffer: AVAudioPCMBuffer) -> Bool {
        guard let channelData = buffer.floatChannelData else { return false }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return false }
        let samples = channelData[0]
        for index in 0..<frameCount {
            if abs(samples[index]) > 0.001 {
                return true
            }
        }
        return false
    }

    private func teardown() {
        playerNode?.stop()
        playerNode?.reset()
        if let playerNode {
            playerNode.removeTap(onBus: 0)
        }
        engine?.stop()
        engine?.reset()
        playerNode = nil
        engine = nil
        audioFile = nil
    }
}

private enum LTC_HarnessError: LocalizedError {
    case missingAsset
    case timeout

    var errorDescription: String? {
        switch self {
        case .missingAsset:
            return "Bundled lt_click.wav not found."
        case .timeout:
            return "No audio tap received within timeout."
        }
    }
}
#endif
