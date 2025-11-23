//
//  HealthAppApp.swift
//  HealthApp
//
//  Created by IOS-Developer on 23/11/2025.
//

import SwiftUI

@main
struct HealthAppApp: App {
    var body: some Scene {
        WindowGroup {
            HealthDashboarddView(viewModel: HealthDashboardViewModel(repository: HealthRepository(service: HealthKitService())))
        }
    }
}
