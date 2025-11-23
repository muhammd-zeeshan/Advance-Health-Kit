//
//  HealthRepository.swift
//  MyHealthApp
//
//  Created by IOS-Developer on 23/11/2025.
//

import Foundation
import HealthKit

protocol HealthRepositoryProtocol {
    func requestAuthorization() async throws -> Bool
    func getStepCount(from start: Date, to end: Date) async throws -> HealthSample
    func stepCountStream(since: Date) -> AsyncStream<HealthSample>
    func stopStreaming()
}


final class HealthRepository: HealthRepositoryProtocol {
    private let service: HealthServiceProtocol
    
    init(service: HealthServiceProtocol) {
        self.service = service
    }
    
    
    func requestAuthorization() async throws -> Bool {
        let read: Set<HKObjectType> = [HKQuantityType(.stepCount)]
        let write: Set<HKSampleType> = []
        return try await service.requestAuthorization(read: read, write: write)
    }
    
    
    
    func getStepCount(from start: Date, to end: Date) async throws -> HealthSample {
        let steps = try await service.fetchStepCount(from: start, to: end)
        return HealthSample(date: Date(), value: steps, unit: "steps")
    }
    
    
    func stepCountStream(since: Date) -> AsyncStream<HealthSample> {
        AsyncStream<HealthSample>(bufferingPolicy: .unbounded) { continuation in
            let inner = service.stepCountUpdates(since: since)

            Task {
                for await value in inner {
                    let sample = HealthSample(date: Date(), value: value, unit: "steps")
                    continuation.yield(sample)
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.service.stopObservingSteps()
                }
            }
        }
    }
    
    func stopStreaming() {
        service.stopObservingSteps()
    }
}

