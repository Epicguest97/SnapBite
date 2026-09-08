import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var goals: NutritionGoals

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nutrition goals")
                        .font(.title2.bold())
                    Text("Set the daily targets that keep your meal summary useful.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("Daily targets") {
                goalRow("Calories", value: $goals.calories, range: 1_000...5_000, step: 50, unit: "kcal")
                goalRow("Protein", value: $goals.protein, range: 20...300, step: 5, unit: "g")
                goalRow("Carbs", value: $goals.carbs, range: 50...500, step: 5, unit: "g")
                goalRow("Fat", value: $goals.fat, range: 20...200, step: 5, unit: "g")
            }

            Section("Preferences") {
                Picker("Units", selection: $goals.units) {
                    ForEach(NutritionGoals.Units.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                Picker("Diet", selection: $goals.dietaryPreference) {
                    ForEach(NutritionGoals.DietaryPreference.allCases) { preference in
                        Text(preference.rawValue).tag(preference)
                    }
                }
            }
        }
        .navigationTitle("Profile & Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func goalRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue) \(unit)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ProfileButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "person.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 36, height: 36)
                .background(AppTheme.accent.opacity(0.13), in: Circle())
        }
        .accessibilityLabel("Profile and goals")
        .padding(.top, 20)
        .padding(.trailing, 20)
    }
}
