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
    private var bmr: Double? {
        guard let a = Double(age), (18...100).contains(a), let w = Double(weight), (30...300).contains(w), let h = Double(height), (100...250).contains(h), sex == "female" || sex == "male" else { return nil }
        return 10 * w + 6.25 * h - 5 * a + (sex == "male" ? 5 : -161)
    }
    private var tdee: Int? {
        guard let bmr, let factor = Double(activity) else { return nil }
        return Int((bmr * factor).rounded())
    }
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
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "calculator").font(.title2).foregroundStyle(.white).frame(width: 46, height: 46).background(.white.opacity(0.13), in: Circle())
                    VStack(alignment: .leading) {
                        Text("Smart daily goal").font(.custom("Nunito", size: 20, relativeTo: .title3).bold()).foregroundStyle(.white)
                        Text("Estimated maintenance calories").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(.white.opacity(0.7))
                    }
                }
                HStack(spacing: 8) {
                    stat("Resting", bmr.map { Int($0.rounded()) })
                    stat("Daily", tdee)
                    stat("Current", goals.calories)
                }
                Text("Mifflin–St Jeor estimate × activity. For adults 18–100; actual needs vary. This estimates maintenance, not a weight-loss target.").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(.white.opacity(0.75))
                if tdee == nil { Text("Enter valid details and select an activity level to calculate.").font(.caption).foregroundStyle(.white.opacity(0.8)) }
                Button("Apply estimate") { if let tdee { goals.calories = tdee } }.font(.custom("Nunito", size: 16, relativeTo: .body).bold()).foregroundStyle(AppTheme.foreground).frame(maxWidth: .infinity).padding(14).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14)).disabled(tdee == nil).opacity(tdee == nil ? 0.5 : 1)
            }.padding(20).background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 32))
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
    private func stat(_ label: String, _ value: Int?) -> some View {
        VStack(spacing: 5) { Text(label).font(.caption).foregroundStyle(.white.opacity(0.7)); Text(value.map(String.init) ?? "—").font(.custom("Nunito", size: 18, relativeTo: .headline).bold()).foregroundStyle(.white) }.frame(maxWidth: .infinity).padding(.vertical, 12).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
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
