//
//  HealthSamle.swift
//  MyHealthApp
//
//  Created by IOS-Developer on 23/11/2025.
//

import Foundation

struct HealthSample: Identifiable {
    let id: UUID = UUID()
    let date: Date
    let value: Double
    let unit: String
}
