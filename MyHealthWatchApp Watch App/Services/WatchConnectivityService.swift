//
//  WatchConnectivityService.swift
//  MyHealthWatchApp Watch App
//
//  Created by IOS-Developer on 23/11/2025.
//

import Foundation
import WatchConnectivity
import Combine

protocol WatchConnectivityServiceProtocol: AnyObject {
    var messages: AsyncStream<WatchMessage> { get }
    func send(_ message: WatchMessage)
    func activateSession()
}

final class WatchConnectivityService: NSObject, WatchConnectivityServiceProtocol {
    public static let shared = WatchConnectivityService()

    private let session: WCSession = .default
    private var continuation: AsyncStream<WatchMessage>.Continuation? = nil

    override init() {
        super.init()
        session.delegate = self
        if WCSession.isSupported() {
            session.activate()
        }
    }

   var messages: AsyncStream<WatchMessage> {
        AsyncStream { cont in
            self.continuation = cont
            cont.onTermination = { _ in self.continuation = nil }
        }
    }

    func activateSession() {
        if WCSession.isSupported() { session.activate() }
    }

    func send(_ message: WatchMessage) {
        // Encode message data
        do {
            let data = try JSONEncoder().encode(message)

            if session.isReachable {
                // sendMessageData for binary
                session.sendMessageData(data, replyHandler: nil) { error in
                    // on error fallback
                    print("[WatchConnectivity] sendMessageData error: \(error.localizedDescription)")
                    self.fallbackTransfer(message)
                }
                return
            }

            // Not reachable -> fallback to transferUserInfo
            fallbackTransfer(message)

        } catch {
            print("[WatchConnectivity] Encoding error: \(error)")
        }
    }

    private func fallbackTransfer(_ message: WatchMessage) {
        do {
            // We send minimal payload as userInfo (must be plist-safe types)
            switch message {
            case .requestSteps(let since):
                var info: [String: Any] = ["type": "requestSteps"]
                if let s = since { info["since"] = ISO8601DateFormatter().string(from: s) }
                session.transferUserInfo(info)

            case .stepsSnapshot(let steps, let date):
                let info: [String: Any] = ["type": "stepsSnapshot", "steps": steps, "date": ISO8601DateFormatter().string(from: date)]
                session.transferUserInfo(info)

            case .heartbeat:
                session.transferUserInfo(["type": "heartbeat"])
            }
        } catch {
            print("[WatchConnectivity] fallbackTransfer error: \(error)")
        }
    }
}

// MARK: WCSessionDelegate
extension WatchConnectivityService: WCSessionDelegate {
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let err = error { print("[WC] activation error: \(err)") }
        print("[WC] activated: \(activationState.rawValue)")
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        decodeAndYield(data: messageData)
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        // when userInfo arrives, convert to WatchMessage if possible
        if let type = userInfo["type"] as? String {
            switch type {
            case "requestSteps":
                var since: Date? = nil
                if let s = userInfo["since"] as? String { since = ISO8601DateFormatter().date(from: s) }
                continuation?.yield(.requestSteps(since: since))
            case "stepsSnapshot":
                let steps = (userInfo["steps"] as? Double) ?? 0
                let date = ISO8601DateFormatter().date(from: (userInfo["date"] as? String ?? "")) ?? Date()
                continuation?.yield(.stepsSnapshot(steps: steps, date: date))
            case "heartbeat":
                continuation?.yield(.heartbeat)
            default:
                break
            }
        }
    }

    private func decodeAndYield(data: Data) {
        do {
            let msg = try JSONDecoder().decode(WatchMessage.self, from: data)
            continuation?.yield(msg)
        } catch {
            print("[WC] decode error: \(error)")
        }
    }
}
