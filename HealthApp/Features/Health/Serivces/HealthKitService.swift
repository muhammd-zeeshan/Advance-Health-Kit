//
//  HealthKitService.swift
//  MyHealthApp
//
//  Created by IOS-Developer on 23/11/2025.
//

import Foundation
import HealthKit

// Concrete implementation using HKHealthStore
final class HealthKitService: HealthServiceProtocol {
    private let healthStore: HKHealthStore
    private var observerQuery: HKObserverQuery?
    private var anchoredQuery: HKAnchoredObjectQuery?
    @MainActor private var continuation: AsyncStream<Double>.Continuation?
    
    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }
    
    
    func requestAuthorization(read: Set<HKObjectType>, write: Set<HKSampleType>) async throws -> Bool {
        // HealthKit authorization uses callback-based API, so wrap with continuation
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            guard HKHealthStore.isHealthDataAvailable() else {
                continuation.resume(throwing: AppErrors.notAvailable)
                return
            }
            
            healthStore.requestAuthorization(toShare: write, read: read) { success, error in
                if let e = error {
                    continuation.resume(throwing: AppErrors.hkError(e))
                    return
                }
                continuation.resume(returning: success)
            }
        }
    }
    
    
    
    
    func fetchStepCount(from start: Date, to end: Date) async throws -> Double {
        let stepType = HKQuantityType(.stepCount)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: AppErrors.hkError(error))
                    return
                }
                
                let sum = result?.sumQuantity()
                let steps = sum?.doubleValue(for: HKUnit.count()) ?? 0.0
                continuation.resume(returning: steps)
            }
            
            self.healthStore.execute(query)
        }
    }
    
    
    

    func stepCountUpdates(since: Date) -> AsyncStream<Double> {
        // if already streaming, return the existing stream continuation in a new AsuncStream wrapper
        let stream = AsyncStream<Double> { continuation in
            // Store continuation so that observer callback can push updates
            Task { @MainActor in
                self.continuation = continuation
            }
            
            // Ensure observer query is setup
            self.setupObserverQueary(since: since)
            
            // on termination, cleanup
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.teardownQueries()
                    self.continuation = nil
                }
            }
        }
        
        return stream
    }
    
    
    
    func stopObservingSteps() {
        teardownQueries()
        continuation?.finish()
        continuation = nil
    }
}


// MARK: Private helpers
extension HealthKitService {
    private func setupObserverQueary(since: Date) {
        let stepType = HKQuantityType(.stepCount)
        
        // Avoid re-creating if exists
        if observerQuery != nil { return }
        
        // HKObserverQuery notifies when samples are added.
        observerQuery = HKObserverQuery(sampleType: stepType, predicate: nil, updateHandler: { [weak self] _, completionHandler, error in
            guard let self else { return }
            
            if let error = error {
                // push error as 0 and let caller decide; better is to use Result-based stream but keep simple
                print("HKObserverQueryy error:\(error)")
                completionHandler()
                return
            }
            
            // When observer fires, run anchored query to fetchy new samples since 'since' date
            self.runAnchoredQuery(since: since)
            
            completionHandler()
        })
        
        if let q = observerQuery {
            healthStore.execute(q)
            
            // enable background delivery - best-effort (may fail silently)
            healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
                if let err = error {
                    print("enableBackgroundDelivery error:\(err)")
                }
                print("Background Delivery enabled? \(success)")
            }
        }
    }
    
    
    
    private func runAnchoredQuery(since: Date) {
        let stepType = HKQuantityType(.stepCount)
        
        // if anchoredQuery exists, we sshould update it rather than creating new each time.
        // for simpllicity we will create a shoort anchored query to fetch recent samples then finish.
        
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: stepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
            guard let self = self else { return }
            if let error = error {
                print("HKSampleQuery error: \(error)")
                return
            }
            
            // Aggregate samples to total steps 'since' date
            var totalSteps: Double = 0
            let hkSamples = samples as? [HKQuantitySample] ?? []
            for s in hkSamples {
                totalSteps += s.quantity.doubleValue(for: HKUnit.count())
            }
            
            // push update
            Task{ @MainActor in
                self.continuation?.yield(totalSteps)
            }
        }
        
        self.healthStore.execute(query)
    }
    
    
    private func teardownQueries() {
        if let observer = observerQuery {
            healthStore.stop(observer)
            observerQuery = nil
        }
        if let anchored = anchoredQuery {
            healthStore.stop(anchored)
            anchoredQuery = nil
        }
    }
}

