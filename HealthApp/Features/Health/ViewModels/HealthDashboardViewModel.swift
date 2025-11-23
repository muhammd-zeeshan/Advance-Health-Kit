//
//  HealthDashboardViewModel.swift
//  MyHealthApp
//
//  Created by IOS-Developer on 23/11/2025.
//

import Foundation
import Combine


final class HealthDashboardViewModel: ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var isLoading: Bool = false
    @Published var totalStepsToday: Double = 0
    @Published var errorMessage: String? = nil
    
    private let repository: HealthRepositoryProtocol
    var streamTask: Task<Void, Never>? = nil
    
    init(repository: HealthRepositoryProtocol) {
        self.repository = repository
    }
    
    
    // Request HealthKit Permission
    func requestAuthorization() async {
        isLoading = true
        errorMessage = nil
        do {
            let ok = try await repository.requestAuthorization()
            isAuthorized = ok
        } catch {
            isAuthorized = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Authentication failed"
        }
        isLoading = false
    }
    
    
    // Load todays total steps once
    func loadTodayStep() async {
        isLoading = true
        errorMessage = nil
        let start = Calendar.current.startOfDay(for: Date())
        let end = Date()
        do {
            let sample = try await repository.getStepCount(from: start, to: end)
            totalStepsToday = sample.value
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to fetch steps"
        }
        isLoading = false
    }
    
    
    // Start streaming live updates (since start of day)
    func startStreamingTodaySteps() {
        // Cancel existing
        streamTask?.cancel()
        
        streamTask = Task { [weak self] in
            guard let self = self else { return }
            
            let start = Calendar.current.startOfDay(for: Date())
            for await sample in repository.stepCountStream(since: start) {
                await MainActor.run {
                    self.totalStepsToday = sample.value
                }
            }
        }
    }
    
    func stopStreaming() {
        streamTask?.cancel()
        repository.stopStreaming()
    }
}
