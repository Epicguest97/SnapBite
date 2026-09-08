//
//  ContentView.swift
//  biteAi
//
//  Created by Mehul Kaushik on 08/09/26.
//

import SwiftUI

struct ContentView: View {
    
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var selectedTab: AppTab = .today
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                
                VStack(spacing: 8) {
                    Text("BiteAI")
                        .font(.system(size: 36, weight: .bold))
                    
                    Text("Snap your food. Know your nutrition.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.gray.opacity(0.1))
                    
                    if let image = capturedImage {
                        
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 300)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 25)
                            )
                        
                    } else {
                        
                        VStack(spacing: 15) {
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 55))
                                .foregroundStyle(.blue)
                            
                            Text("Take a photo of your food")
                                .font(.headline)
                            
                            Text("AI will estimate calories and nutrition")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 300)
                
                // Sample result
                if capturedImage != nil {
                    NutritionCard()
                }
                
                Spacer()
                
            }
            .padding(25)
            .navigationBarHidden(true)
            .sheet(isPresented: $showCamera) {
                ImagePicker(image: $capturedImage)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AppTabBar(selectedTab: $selectedTab) {
                    showCamera = true
                }
            }
        }
    }
}

private enum AppTab: String, CaseIterable {
    case today = "Today"
    case log = "Log"
    case scan = "Scan"
    case insights = "Insights"
    case goals = "Goals"

    var icon: String {
        switch self {
        case .today: "flame"
        case .log: "book"
        case .scan: "viewfinder"
        case .insights: "chart.line.uptrend.xyaxis"
        case .goals: "slider.horizontal.3"
        }
    }
}

private struct AppTabBar: View {
    @Binding var selectedTab: AppTab
    let scanAction: () -> Void

    private let accent = Color(red: 0.04, green: 0.74, blue: 0.48)

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            tabButton(.today)
            tabButton(.log)

            Button {
                selectedTab = .scan
                scanAction()
            } label: {
                Image(systemName: AppTab.scan.icon)
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 78, height: 78)
                    .background(accent)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(.white, lineWidth: 6)
                    }
                    .shadow(color: accent.opacity(0.25), radius: 18, y: 8)
            }
            .accessibilityLabel("Scan food")
            .offset(y: -25)

            tabButton(.insights)
            tabButton(.goals)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .frame(height: 82)
        .background(Color(uiColor: .systemBackground))
    }

    @ViewBuilder
    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 23, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(selectedTab == tab ? accent : Color.primary.opacity(0.72))
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(tab.rawValue)
    }
}

struct NutritionCard: View {
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 15) {
            
            Text("AI Estimate")
                .font(.headline)
            
            HStack {
                
                VStack(alignment: .leading) {
                    Text("Biryani")
                        .font(.title2)
                        .bold()
                    
                    Text("Estimated serving")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text("520")
                        .font(.title)
                        .bold()
                    
                    Text("kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            HStack {
                NutritionValue(
                    title: "Protein",
                    value: "18g"
                )
                
                Spacer()
                
                NutritionValue(
                    title: "Carbs",
                    value: "65g"
                )
                
                Spacer()
                
                NutritionValue(
                    title: "Fat",
                    value: "20g"
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(
            RoundedRectangle(cornerRadius: 20)
        )
    }
}

struct NutritionValue: View {
    
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
