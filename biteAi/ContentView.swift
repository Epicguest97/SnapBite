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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                
                VStack(spacing: 8) {
                    Text("inBiteAI")
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
                
                Button {
                    showCamera = true
                } label: {
                    HStack {
                        Image(systemName: "camera")
                        Text("Scan Food")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 15)
                    )
                }
            }
            .padding(25)
            .navigationBarHidden(true)
            .sheet(isPresented: $showCamera) {
                ImagePicker(image: $capturedImage)
            }
        }
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
