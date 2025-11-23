//
//  HealthServiceProtocol.swift
//  MyHealthApp
//
//  Created by IOS-Developer on 23/11/2025.
//

import Foundation
import HealthKit


protocol HealthServiceProtocol {
    // Request Authorization for given read and wirite types
    func requestAuthorization(read: Set<HKObjectType>, write: Set<HKSampleType>) async throws -> Bool
    
    // Fetch aggregated steps count between dates
    func fetchStepCount(from start: Date, to end: Date) async throws -> Double
    
    // Start observing step count changes; returned AsyncStream yields latest total steps for 'since' date
    func stepCountUpdates(since: Date) -> AsyncStream<Double>
    
    // Stop observing updates (optional)
    func stopObservingSteps()
}
