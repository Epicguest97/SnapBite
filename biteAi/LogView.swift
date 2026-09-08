import SwiftUI

struct LogView: View {
    let meals: [Meal]
    let goals: NutritionGoals

    private var week: [DayTotal] {
        let calendar = Calendar.current
        return (-6...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: .now) else { return nil }
            let calories = meals
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.calories }
            return DayTotal(date: date, calories: calories)
        }
    }

    private var groupedMeals: [(date: Date, meals: [Meal])] {
        Dictionary(grouping: meals) { Calendar.current.startOfDay(for: $0.date) }
            .map { (date: $0.key, meals: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Log").font(.largeTitle.bold())
                    Text("Your weekly nutrition overview").foregroundStyle(.secondary)
                }

                WeeklyCaloriesCard(days: week, goal: goals.calories)

                Text("Meal history").font(.title3.bold())
                ForEach(groupedMeals, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(sectionTitle(group.date))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        ForEach(group.meals) { meal in
                            LoggedMealCard(meal: meal)
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 18)
        }
    }

    private func sectionTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct DayTotal: Identifiable {
    let date: Date
    let calories: Int
    var id: Date { date }
}

private struct WeeklyCaloriesCard: View {
    let days: [DayTotal]
    let goal: Int
    @State private var selectedDate: Date?

    private var average: Int {
        let loggedDays = days.filter { $0.calories > 0 }
        guard !loggedDays.isEmpty else { return 0 }
        return loggedDays.reduce(0) { $0 + $1.calories } / loggedDays.count
    }
    private var selectedDay: DayTotal {
        guard let selectedDate,
              let day = days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) })
        else { return days.last ?? DayTotal(date: .now, calories: 0) }
        return day
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WEEKLY CALORIES")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
            HStack(alignment: .firstTextBaseline) {
                Text("\(selectedDay.calories)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(selectedDay.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                    Text("Average \(average) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            WeeklyBarChart(days: days, goal: goal, selectedDate: $selectedDate)
            Label("Tap a bar to see that day's calories", systemImage: "hand.tap")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct WeeklyBarChart: View {
    let days: [DayTotal]
    let goal: Int
    @Binding var selectedDate: Date?

    var body: some View {
        let maximum = max(goal, days.map(\.calories).max() ?? goal)
        VStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack {
                    VStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.secondary.opacity(0.12))
                                .frame(height: 1)
                            Spacer()
                        }
                    }
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(days) { day in
                            Button {
                                selectedDate = day.date
                            } label: {
                                VStack(spacing: 7) {
                                    Spacer(minLength: 0)
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Calendar.current.isDate(day.date, inSameDayAs: selectedDate ?? days.last?.date ?? .now) ? Color.orange : Color.orange.opacity(0.72))
                                        .frame(height: max(CGFloat(day.calories) / CGFloat(maximum) * (proxy.size.height - 20), 5))
                                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                                        .font(.caption.weight(Calendar.current.isDateInToday(day.date) ? .bold : .regular))
                                        .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Color.orange : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityLabel("\(day.date.formatted(date: .abbreviated, time: .omitted)): \(day.calories) calories")
                        }
                    }
                    .padding(.top, 5)
                    Rectangle()
                        .fill(Color.orange.opacity(0.65))
                        .frame(height: 1)
                        .padding(.bottom, (proxy.size.height - 20) * (1 - CGFloat(goal) / CGFloat(maximum)) + 20)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 155)
        }
    }
}

private struct LoggedMealCard: View {
    let meal: Meal

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: meal.mealType == .breakfast ? "sunrise.fill" : "fork.knife")
                .foregroundStyle(AppTheme.accent)
                .frame(width: 42, height: 42)
                .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.mealType.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                Text(meal.name).font(.headline)
                Text("\(meal.calories) kcal  •  P \(meal.protein)g  C \(meal.carbs)g  F \(meal.fat)g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}
