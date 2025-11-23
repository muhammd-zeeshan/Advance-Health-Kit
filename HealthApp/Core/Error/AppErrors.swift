//
//  AppErrors.swift
//  MyHealthApp
//
//  Created by IOS-Developer on 23/11/2025.
//

import Foundation

enum AppErrors: Error, LocalizedError {
    case permissionDenied
    case notAvailable
    case hkError(Error)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Permission denied for Health data"
        case .notAvailable: return "Health data not available on this device"
        case .hkError(let e): return e.localizedDescription
        case .unknown: return "Unknown error"
        }
    }
}
