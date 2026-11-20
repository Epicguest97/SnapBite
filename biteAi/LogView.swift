import SwiftUI

struct LogView: View {
    let meals: [Meal]
    let goals: NutritionGoals
    let openMeal: (Meal) -> Void
    @State private var month = false
    private let calendar = Calendar.current
    private var dates: [Date] {
        let today = calendar.startOfDay(for: .now)
        return (-(month ? 29 : 6)...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }
    private func dayMeals(_ day: Date) -> [Meal] { meals.filter { calendar.isDate($0.date, inSameDayAs: day) } }
    private func calories(_ day: Date) -> Int { dayMeals(day).reduce(0) { $0 + $1.calories } }
    private var loggedDays: [Date] { dates.filter { !dayMeals($0).isEmpty } }
    private var periodMeals: [Meal] { meals.filter { meal in dates.contains { calendar.isDate($0, inSameDayAs: meal.date) } } }
    private var avgCalories: Int { loggedDays.isEmpty ? 0 : loggedDays.reduce(0) { $0 + calories($1) } / loggedDays.count }
    private func avg(_ key: KeyPath<Meal, Int>) -> Int { loggedDays.isEmpty ? 0 : periodMeals.reduce(0) { $0 + $1[keyPath: key] } / loggedDays.count }
    private var protein: Int { avg(\.protein) }
    private var carbs: Int { avg(\.carbs) }
    private var fat: Int { avg(\.fat) }
    private var macroTotal: Int { max(protein + carbs + fat, 1) }
    private var rankedMeals: [Meal] { periodMeals.filter { $0.calories > 0 && $0.foods != nil }.sorted { score($0) > score($1) }.prefix(3).map { $0 } }
    // A simple comparison score, not a clinical measure: protein per calorie minus saturated-energy proxy.
    private func score(_ meal: Meal) -> Int {
        let proteinDensity = Double(meal.protein) * 100 / Double(max(meal.calories, 1))
        let fatDensity = Double(meal.fat) * 100 / Double(max(meal.calories, 1))
        return Int(max(0, min(100, 50 + proteinDensity * 3 - fatDensity * 2)).rounded())
    }
    private var completeMicroDays: [Date] {
        loggedDays.filter { day in
            let meals = dayMeals(day)
            return !meals.isEmpty && meals.allSatisfy { meal in
                guard let foods = meal.foods, !foods.isEmpty else { return false }
                return foods.allSatisfy { $0.fiber != nil && $0.vitaminC != nil && $0.iron != nil && $0.sodium != nil && $0.sugar != nil }
            }
        }
    }
    private func microAverage(_ key: KeyPath<DetectedFood, Double?>) -> Double? {
        guard !completeMicroDays.isEmpty else { return nil }
        let eligible = completeMicroDays.filter { dayMeals($0).flatMap { $0.foods ?? [] }.allSatisfy { $0[keyPath: key] != nil } }
        guard !eligible.isEmpty else { return nil }
        let total = eligible.flatMap { dayMeals($0) }.flatMap { $0.foods ?? [] }.reduce(0.0) { $0 + ($1[keyPath: key] ?? 0) }
        return total / Double(eligible.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Stats").font(.custom("Nunito", size: 30, relativeTo: .largeTitle).bold())
                    Spacer()
                    HStack(spacing: 0) {
                        rangeButton("Week", selected: !month) { month = false }
                        rangeButton("Month", selected: month) { month = true }
                    }.padding(4).background(AppTheme.card, in: Capsule()).overlay(Capsule().stroke(AppTheme.border))
                }
                intakeCard
                macrosCard
                microsCard
                Text(month ? "Top meals this month" : "Top meals this week").font(.custom("Nunito", size: 20, relativeTo: .title3).bold())
                if rankedMeals.isEmpty {
                    Text("Log meals with estimated nutrition to see rankings.").foregroundStyle(AppTheme.mutedForeground).padding(16).frame(maxWidth: .infinity, alignment: .leading).statsCard()
                } else {
                    Text("Ranked by protein and fat per calorie; a simple comparison, not a health rating.").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
                    ForEach(rankedMeals) { meal in
                        Button { openMeal(meal) } label: {
                            HStack(spacing: 12) {
                                MealThumbnail(meal: meal)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(meal.name).font(.custom("Nunito", size: 16, relativeTo: .body).bold()).foregroundStyle(AppTheme.foreground)
                                    Text(meal.date.formatted(date: .abbreviated, time: .shortened)).font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
                                }
                                Spacer()
                                Text("\(score(meal)) score").font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).foregroundStyle(AppTheme.accent)
                            }.padding(14).statsCard()
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(20).padding(.bottom, 20)
        }.background(AppTheme.canvas)
    }
    private func rangeButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).foregroundStyle(selected ? .white : AppTheme.mutedForeground).padding(.horizontal, 16).padding(.vertical, 9).background(selected ? AppTheme.foreground : .clear, in: Capsule()) }.buttonStyle(.plain)
    }
    private var intakeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Avg. daily intake").font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).foregroundStyle(AppTheme.mutedForeground)
            HStack(alignment: .firstTextBaseline) {
                Text("\(avgCalories)").font(.custom("Nunito", size: 30, relativeTo: .largeTitle).bold())
                Text("kcal").font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).foregroundStyle(AppTheme.mutedForeground)
            }
            GeometryReader { proxy in
                let maxValue = max(goals.calories, dates.map { calories($0) }.max() ?? 0, 1)
                HStack(alignment: .bottom, spacing: month ? 2 : 8) {
                    ForEach(dates, id: \.self) { day in
                        let value = calories(day)
                        RoundedRectangle(cornerRadius: month ? 3 : 9)
                            .fill(calendar.isDateInToday(day) ? AppTheme.orange : AppTheme.forest.opacity(value == 0 ? 0.12 : 0.65))
                            .frame(maxWidth: .infinity).frame(height: max(4, (proxy.size.height - 4) * CGFloat(value) / CGFloat(maxValue)))
                            .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)): \(value) calories")
                    }
                }.frame(maxHeight: .infinity, alignment: .bottom)
            }.frame(height: 120)
            HStack { Text(dates.first?.formatted(.dateTime.month(.abbreviated).day()) ?? ""); Spacer(); Text("Today") }.font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
            let under = loggedDays.filter { Double(calories($0)) < Double(goals.calories) * 0.95 }.count
            let on = loggedDays.filter { Double(calories($0)) >= Double(goals.calories) * 0.95 && Double(calories($0)) <= Double(goals.calories) * 1.05 }.count
            let over = loggedDays.count - under - on
            HStack(spacing: 8) { goalTile(under, "Under goal", AppTheme.protein); goalTile(on, "On goal", AppTheme.forest); goalTile(over, "Over goal", AppTheme.orange) }
            Text("Averages use logged days. On goal means within 5% of your current target.").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
        }.padding(18).statsCard()
    }
    private func goalTile(_ count: Int, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count) days").foregroundStyle(color).font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold())
            Text(label).font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity).padding(.vertical, 10).background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border))
    }
    private var macrosCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Macros split").font(.custom("Nunito", size: 20, relativeTo: .title3).bold())
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    AppTheme.protein.frame(width: proxy.size.width * CGFloat(protein) / CGFloat(macroTotal))
                    AppTheme.carbs.frame(width: proxy.size.width * CGFloat(carbs) / CGFloat(macroTotal))
                    AppTheme.fats.frame(width: proxy.size.width * CGFloat(fat) / CGFloat(macroTotal))
                }.background(AppTheme.muted).clipShape(Capsule())
            }.frame(height: 10)
            HStack(spacing: 8) {
                macroTile("Protein", protein, goals.protein, AppTheme.protein)
                macroTile("Carbs", carbs, goals.carbs, AppTheme.carbs)
                macroTile("Fat", fat, goals.fat, AppTheme.fats)
            }
            Text("Daily averages on logged days; split is by grams.").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
        }.padding(18).statsCard()
    }
    private func macroTile(_ title: String, _ value: Int, _ goal: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) { Circle().fill(color).frame(width: 7, height: 7); Text(title).lineLimit(1).minimumScaleFactor(0.7) }.font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
            Text("\(value)g").font(.custom("Nunito", size: 18, relativeTo: .headline).bold())
            Text("\(value * 100 / macroTotal)% · goal \(goal)g").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground).lineLimit(2).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, minHeight: 75, alignment: .leading).padding(10).background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border))
    }
    private var microsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Micros & fiber").font(.custom("Nunito", size: 20, relativeTo: .title3).bold())
            microRow("Fiber", value: microAverage(\.fiber), goal: 25, unit: "g", color: AppTheme.protein)
            microRow("Sugar", value: microAverage(\.sugar), goal: 50, unit: "g", color: AppTheme.carbs)
            microRow("Vitamin C", value: microAverage(\.vitaminC), goal: 90, unit: "mg", color: AppTheme.orange)
            microRow("Vitamin A", value: microAverage(\.vitaminA), goal: 900, unit: "µg", color: AppTheme.orange)
            microRow("Folate", value: microAverage(\.folate), goal: 400, unit: "µg", color: AppTheme.protein)
            microRow("Iron", value: microAverage(\.iron), goal: 18, unit: "mg", color: AppTheme.carbs)
            microRow("Sodium", value: microAverage(\.sodium), goal: 2300, unit: "mg", color: AppTheme.fats)
            Text(completeMicroDays.isEmpty ? "No complete micronutrient data for this period." : "Illustrative averages for \(completeMicroDays.count) days with complete food data. Values and reference amounts are not personalized.").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.foreground).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(AppTheme.blush, in: RoundedRectangle(cornerRadius: 14))
        }.padding(18).statsCard()
    }
    private func microRow(_ title: String, value: Double?, goal: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack { Text(title).font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()); Spacer(); Text(value.map { String(format: "%.1f / %.0f %@", $0, goal, unit) } ?? "Not available").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground) }
            GeometryReader { proxy in ZStack(alignment: .leading) { Capsule().fill(AppTheme.muted); Capsule().fill(color).frame(width: proxy.size.width * min(max(value ?? 0, 0) / goal, 1)) } }.frame(height: 5)
        }
    }

}

private extension View {
    func statsCard() -> some View {
        background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border))
    }
}
