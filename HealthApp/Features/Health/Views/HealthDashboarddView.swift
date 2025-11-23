//
//  HealthDashboarddView.swift
//  MyHealthApp
//
//  Created by IOS-Developer on 23/11/2025.
//

import SwiftUI

struct HealthDashboarddView: View {
    @StateObject private var viewModel: HealthDashboardViewModel
    
    init(viewModel: HealthDashboardViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack {
            Text("Today's Steps")
                .font(.title)
            
            Text("\(Int(viewModel.totalStepsToday))")
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .padding()
                .background(.gray.opacity(0.2), in: .rect(cornerRadius: 10))
            
            if viewModel.isLoading {
                ProgressView()
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            HStack(spacing: 20) {
                Button {
                    Task {
                        await viewModel.requestAuthorization()
                    }
                } label: {
                    Text("Request Authorization")
                }
                
                
                
                Button {
                    Task {
                        await viewModel.loadTodayStep()
                    }
                } label: {
                    Text("Load Steps")
                }
            }
            
            Button {
                if viewModel.streamTask == nil {
                    viewModel.startStreamingTodaySteps()
                } else {
                    viewModel.stopStreaming()
                }
            } label: {
                Text(viewModel.streamTask == nil ? "Start Live Updates" : "Stop Live Updates")
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    HealthDashboarddView(viewModel: HealthDashboardViewModel(repository: HealthRepository(service: HealthKitService())))
}
