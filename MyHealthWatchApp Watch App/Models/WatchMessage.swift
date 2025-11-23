//
//  WatchMessage.swift
//  MyHealthWatchApp Watch App
//
//  Created by IOS-Developer on 23/11/2025.
//

import Foundation
import WatchConnectivity


enum WatchMessage: Codable {
    case requestSteps(since: Date?)            // watch -> phone: ask for steps
    case stepsSnapshot(steps: Double, date: Date) // phone -> watch: send snapshot
    case heartbeat
}


// Utility helper for encoding/decoding enum with associated values
extension WatchMessage {
    enum CodingKeys: String, CodingKey { case type, payload }
    enum MessageType: String, Codable { case requestSteps, stepsSnapshot, heartbeat }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)
        switch type {
        case .requestSteps:
            let payload = try container.decodeIfPresent(Date.self, forKey: .payload)
            self = .requestSteps(since: payload)
        case .stepsSnapshot:
            let payload = try container.decode([String: String].self, forKey: .payload)
            let steps = Double(payload["steps"] ?? "0") ?? 0
            let date = ISO8601DateFormatter().date(from: payload["date"] ?? "") ?? Date()
            self = .stepsSnapshot(steps: steps, date: date)
        case .heartbeat:
            self = .heartbeat
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .requestSteps(let since):
            try container.encode(MessageType.requestSteps, forKey: .type)
            try container.encodeIfPresent(since, forKey: .payload)
        case .stepsSnapshot(let steps, let date):
            try container.encode(MessageType.stepsSnapshot, forKey: .type)
            let payload = ["steps": String(steps), "date": ISO8601DateFormatter().string(from: date)]
            try container.encode(payload, forKey: .payload)
        case .heartbeat:
            try container.encode(MessageType.heartbeat, forKey: .type)
        }
    }
}
