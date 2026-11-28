import SwiftUI

struct PersonalGoalCard: View {
    let profileID: UUID
    let name: String
    @Binding var goals: NutritionGoals
    let rename: (String) -> Void
    @State private var age = ""
    @State private var weight = ""
    @State private var height = ""
    @State private var sex = ""
    @State private var activity = ""
    @State private var displayName = ""
    @FocusState private var focused: Bool
    private var prefix: String { "personal.\(profileID.uuidString)." }
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Text(String(displayName.prefix(1)).uppercased()).font(.custom("Nunito", size: 24, relativeTo: .title2).bold()).foregroundStyle(.white).frame(width: 60, height: 60).background(AppTheme.forest, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName.isEmpty ? "Your profile" : displayName).font(.custom("Nunito", size: 20, relativeTo: .title3).bold())
                        Text("Personal details").foregroundStyle(AppTheme.mutedForeground)
                    }
                    Spacer()
                }
                Text("Personal details").font(.custom("Nunito", size: 18, relativeTo: .headline).bold())
                HStack(alignment: .top, spacing: 10) {
                    field("Name", text: $displayName, keyboard: .default)
                    field("Age (years)", text: $age, keyboard: .numberPad)
                }
                HStack(alignment: .top, spacing: 10) {
                    field("Weight (kg)", text: $weight, keyboard: .decimalPad)
                    field("Height (cm)", text: $height, keyboard: .decimalPad)
                }
                Picker("Equation", selection: $sex) {
                    Text("Select equation").tag("")
                    Text("Female formula").tag("female")
                    Text("Male formula").tag("male")
                }.tint(AppTheme.accent)
                Picker("Activity", selection: $activity) {
                    Text("Select activity").tag("")
                    Text("Sedentary").tag("1.2")
                    Text("Lightly active").tag("1.375")
                    Text("Moderately active").tag("1.55")
                    Text("Very active").tag("1.725")
                }.tint(AppTheme.accent)
                Text("Measurements use kg and cm. The formula uses sex-specific coefficients; choose the formula appropriate for you.").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
            }.padding(20).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 32)).overlay(RoundedRectangle(cornerRadius: 32).stroke(AppTheme.border))

        }
        .onAppear { load() }
        .onChange(of: age) { _, value in save("age", value) }
        .onChange(of: weight) { _, value in save("weight", value) }
        .onChange(of: height) { _, value in save("height", value) }
        .onChange(of: sex) { _, value in save("sex", value) }
        .onChange(of: activity) { _, value in save("activity", value) }
        .onChange(of: displayName) { _, value in if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { rename(value) } }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } } }
    }
    private func field(_ title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
            TextField(title, text: text).keyboardType(keyboard).focused($focused).padding(12).background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border))
        }.frame(maxWidth: .infinity)
    }
    private func load() {
        displayName = name
        age = UserDefaults.standard.string(forKey: prefix + "age") ?? ""
        weight = UserDefaults.standard.string(forKey: prefix + "weight") ?? ""
        height = UserDefaults.standard.string(forKey: prefix + "height") ?? ""
        sex = UserDefaults.standard.string(forKey: prefix + "sex") ?? ""
        activity = UserDefaults.standard.string(forKey: prefix + "activity") ?? ""
    }
    private func save(_ key: String, _ value: String) { UserDefaults.standard.set(value, forKey: prefix + key) }
}
