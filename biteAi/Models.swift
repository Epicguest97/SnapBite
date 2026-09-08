import Foundation
import SwiftUI

enum AppTab {
    case today, scan, log

    var title: String {
        switch self {
        case .today: "Today"
        case .scan: "Scan"
        case .log: "Log"
        }
    }

    var icon: String {
        switch self {
        case .today: "sun.max.fill"
        case .scan: "viewfinder"
        case .log: "book"
        }
    }
}

enum MealType: String, CaseIterable, Identifiable, Codable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"

    var id: String { rawValue }
}

struct Meal: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var detail: String
    var mealType: MealType
    var quantity: Double
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var date: Date

    init(id: UUID = UUID(), name: String, detail: String, mealType: MealType, quantity: Double, calories: Int, protein: Int, carbs: Int, fat: Int, date: Date) {
        self.id = id
        self.name = name
        self.detail = detail
        self.mealType = mealType
        self.quantity = quantity
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.date = date
    }

    static let sample: [Meal] = [
        Meal(name: "Greek yogurt & berries", detail: "1 bowl", mealType: .breakfast, quantity: 280, calories: 320, protein: 22, carbs: 38, fat: 8, date: .now),
        Meal(name: "Veggie sandwich", detail: "1 sandwich", mealType: .lunch, quantity: 260, calories: 430, protein: 16, carbs: 58, fat: 15, date: .now),
        Meal(name: "Dal rice", detail: "1 plate", mealType: .dinner, quantity: 360, calories: 510, protein: 19, carbs: 82, fat: 12, date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!),
        Meal(name: "Apple & almonds", detail: "1 serving", mealType: .snack, quantity: 180, calories: 230, protein: 6, carbs: 29, fat: 11, date: Calendar.current.date(byAdding: .day, value: -2, to: .now)!)
    ]
}

struct DetectedFood: Identifiable {
    let id = UUID()
    let name: String
    let estimatedQuantity: Double
    var quantity: Double
    let baseCalories, baseProtein, baseCarbs, baseFat: Int

    private var multiplier: Double { quantity / estimatedQuantity }
    var calories: Int { Int((Double(baseCalories) * multiplier).rounded()) }
    var protein: Int { Int((Double(baseProtein) * multiplier).rounded()) }
    var carbs: Int { Int((Double(baseCarbs) * multiplier).rounded()) }
    var fat: Int { Int((Double(baseFat) * multiplier).rounded()) }

    static let sample = [
        DetectedFood(name: "Grilled chicken", estimatedQuantity: 120, quantity: 120, baseCalories: 198, baseProtein: 37, baseCarbs: 0, baseFat: 4),
        DetectedFood(name: "Steamed rice", estimatedQuantity: 160, quantity: 160, baseCalories: 208, baseProtein: 4, baseCarbs: 45, baseFat: 1),
        DetectedFood(name: "Mixed salad", estimatedQuantity: 80, quantity: 80, baseCalories: 42, baseProtein: 2, baseCarbs: 8, baseFat: 1)
    ]
}

struct NutritionGoals: Codable, Equatable {
    var calories = 2_000
    var protein = 110
    var carbs = 220
    var fat = 65
    var units: Units = .metric
    var dietaryPreference: DietaryPreference = .none

    enum Units: String, CaseIterable, Identifiable, Codable {
        case metric = "Metric"
        case imperial = "Imperial"
        var id: String { rawValue }
    }

    enum DietaryPreference: String, CaseIterable, Identifiable, Codable {
        case none = "No preference"
        case vegetarian = "Vegetarian"
        case vegan = "Vegan"
        case highProtein = "High protein"
        var id: String { rawValue }
    }
}

enum MealStore {
    private static let storageKey = "savedMeals"

    static func load() -> [Meal] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let meals = try? JSONDecoder().decode([Meal].self, from: data) else {
            return Meal.sample
        }
        return meals
    }

    static func save(_ meals: [Meal]) {
        guard let data = try? JSONEncoder().encode(meals) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

enum GoalsStore {
    private static let storageKey = "nutritionGoals"

    static func load() -> NutritionGoals {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let goals = try? JSONDecoder().decode(NutritionGoals.self, from: data) else {
            return NutritionGoals()
        }
        return goals
    }

    static func save(_ goals: NutritionGoals) {
        guard let data = try? JSONEncoder().encode(goals) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

enum AppTheme {
    static let accent = Color(red: 0.04, green: 0.55, blue: 0.36)
}
