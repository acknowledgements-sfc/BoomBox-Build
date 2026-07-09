#if DEBUG
import Combine
import Foundation
import MultipeerConnectivity
import UIKit

enum LTB_Role: String, CaseIterable, Identifiable {
    case advertiser = "Advertiser (Phone A)"
    case browser = "Browser (Phone B)"

    var id: String { rawValue }
}

struct LTB_TransferResult: Equatable {
    let elapsedSeconds: Double
    let fileSizeBytes: Int64
    let throughputMBps: Double
    let role: String
}

@MainActor
final class LTB_TransferHarness: NSObject, ObservableObject {
    static let serviceType = "pkjb-lt"

    @Published var role: LTB_Role = .advertiser
    @Published var status = "Idle"
    @Published var connectedPeerName: String?
    @Published var lastResult: LTB_TransferResult?
    @Published var lastError: String?

    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var sendStart: CFAbsoluteTime?
    private var connectedPeer: MCPeerID?

    func start() {
        stop()
        lastError = nil
        status = "Starting \(role.rawValue)..."
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

        switch role {
        case .advertiser:
            let advertiser = MCNearbyServiceAdvertiser(
                peer: peerID,
                discoveryInfo: nil,
                serviceType: Self.serviceType
            )
            advertiser.delegate = self
            advertiser.startAdvertisingPeer()
            self.advertiser = advertiser
            status = "Advertising — waiting for browser"
        case .browser:
            let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
            browser.delegate = self
            browser.startBrowsingForPeers()
            self.browser = browser
            status = "Browsing — waiting for advertiser"
        }
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        session?.disconnect()
        session = nil
        connectedPeer = nil
        connectedPeerName = nil
        sendStart = nil
        status = "Stopped"
    }

    func sendTestFile() {
        guard role == .advertiser else {
            lastError = "Only the advertiser (Phone A) can send."
            return
        }
        guard let session, let peer = connectedPeer else {
            lastError = "No connected peer."
            return
        }
        guard let url = Bundle.main.url(forResource: "lt_transfer_5mb", withExtension: "mp3") else {
            lastError = "Bundled lt_transfer_5mb.mp3 not found."
            return
        }

        lastError = nil
        lastResult = nil
        status = "Sending..."
        sendStart = CFAbsoluteTimeGetCurrent()

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        session.sendResource(
            at: url,
            withName: url.lastPathComponent,
            toPeer: peer
        ) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.lastError = error.localizedDescription
                    self.status = "Send failed"
                    return
                }
                guard let start = self.sendStart else { return }
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                let mbps = elapsed > 0 ? (Double(fileSize) / 1_000_000.0) / elapsed : 0
                self.lastResult = LTB_TransferResult(
                    elapsedSeconds: elapsed,
                    fileSizeBytes: fileSize,
                    throughputMBps: mbps,
                    role: "sender"
                )
                self.status = String(format: "Send done in %.2f s (%.2f MB/s)", elapsed, mbps)
            }
        }
    }

    private func handleReceiveComplete(at localURL: URL?) {
        guard let start = sendStart else {
            sendStart = CFAbsoluteTimeGetCurrent()
            return
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let fileSize: Int64
        if let localURL {
            fileSize = (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64) ?? 0
        } else {
            fileSize = 0
        }
        let mbps = elapsed > 0 ? (Double(fileSize) / 1_000_000.0) / elapsed : 0
        lastResult = LTB_TransferResult(
            elapsedSeconds: elapsed,
            fileSizeBytes: fileSize,
            throughputMBps: mbps,
            role: "receiver"
        )
        status = String(format: "Receive done in %.2f s (%.2f MB/s)", elapsed, mbps)
    }
}

extension LTB_TransferHarness: MCSessionDelegate {
    nonisolated func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        Task { @MainActor in
            switch state {
            case .connected:
                connectedPeer = peerID
                connectedPeerName = peerID.displayName
                status = "Connected to \(peerID.displayName)"
            case .notConnected:
                if connectedPeer == peerID {
                    connectedPeer = nil
                    connectedPeerName = nil
                }
                status = "Disconnected from \(peerID.displayName)"
            case .connecting:
                status = "Connecting to \(peerID.displayName)..."
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {}

    nonisolated func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {
        Task { @MainActor in
            sendStart = CFAbsoluteTimeGetCurrent()
            status = "Receiving \(resourceName)..."
        }
    }

    nonisolated func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {
        Task { @MainActor in
            if let error {
                lastError = error.localizedDescription
                status = "Receive failed"
                return
            }
            handleReceiveComplete(at: localURL)
        }
    }
}

extension LTB_TransferHarness: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in
            guard let session else {
                invitationHandler(false, nil)
                return
            }
            invitationHandler(true, session)
        }
    }
}

extension LTB_TransferHarness: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        Task { @MainActor in
            guard let session, connectedPeer == nil else { return }
            status = "Found \(peerID.displayName) — inviting..."
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        }
    }

    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        lostPeer peerID: MCPeerID
    ) {
        Task { @MainActor in
            if connectedPeer == peerID {
                status = "Lost peer \(peerID.displayName)"
            }
        }
    }
}
#endif
