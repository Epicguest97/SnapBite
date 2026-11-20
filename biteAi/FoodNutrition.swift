import Foundation

// Illustrative per-100 g estimates. Recipes and portions vary; these are not laboratory values.
struct FoodEstimate {
    let calories, protein, carbs, fat: Int
    let fiber, vitaminC, iron, sodium, sugar: Double
    var vitaminA: Double { Self.additional["\(calories)-\(protein)-\(carbs)-\(fat)"]?.0 ?? 0 }
    var folate: Double { Self.additional["\(calories)-\(protein)-\(carbs)-\(fat)"]?.1 ?? 0 }
    private static let additional: [String: (Double, Double)] = [
        "100-3-14-4": (30, 35), "130-3-20-5": (10, 20), "300-7-46-10": (0, 60), "100-3-12-5": (25, 45),
        "180-7-25-6": (20, 25), "45-2-6-2": (20, 5), "150-6-20-5": (15, 80), "200-3-10-18": (0, 20),
        "110-6-17-2": (10, 90), "170-4-28-5": (0, 25), "140-3-19-6": (25, 20), "150-13-5-8": (40, 15),
        "420-5-58-19": (20, 30), "80-2-10-4": (100, 35), "320-5-48-12": (35, 15), "140-4-29-1": (0, 25),
        "400-3-65-15": (0, 20), "220-17-6-14": (20, 15), "150-4-24-4": (35, 8), "220-5-25-11": (80, 10),
        "80-3-11-3": (25, 8), "210-16-5-14": (20, 12), "300-6-32-17": (5, 60), "160-7-7-12": (240, 70),
        "150-3-25-5": (10, 20), "140-7-21-3": (10, 80), "220-7-26-10": (70, 12), "260-5-30-14": (10, 25),
        "220-8-8-18": (100, 15), "130-3-28-0": (0, 8)
    ]
    init(_ c: Int, _ p: Int, _ b: Int, _ f: Int, _ fiber: Double, _ vitaminC: Double, _ iron: Double, _ sodium: Double, _ sugar: Double) {
        self.calories = c; self.protein = p; self.carbs = b; self.fat = f
        self.fiber = fiber; self.vitaminC = vitaminC; self.iron = iron; self.sodium = sodium; self.sugar = sugar
    }
}

enum FoodNutrition {
    static let estimates: [String: FoodEstimate] = [
        "aloogobi": .init(100, 3, 14, 4, 3, 20, 1, 250, 3),
        "aloomasala": .init(130, 3, 20, 5, 2, 10, 1, 300, 2),
        "bhatura": .init(300, 7, 46, 10, 2, 0, 2, 400, 3),
        "bhindimasala": .init(100, 3, 12, 5, 4, 12, 1, 300, 3),
        "biryani": .init(180, 7, 25, 6, 1, 2, 1, 350, 1),
        "chai": .init(45, 2, 6, 2, 0, 0, 0, 35, 5),
        "chole": .init(150, 6, 20, 5, 6, 4, 2, 350, 3),
        "chaichole": .init(150, 6, 20, 5, 6, 4, 2, 350, 3),
        "coconutchutney": .init(200, 3, 10, 18, 5, 2, 1, 350, 3),
        "dal": .init(110, 6, 17, 2, 5, 2, 2, 250, 1),
        "dosa": .init(170, 4, 28, 5, 2, 0, 1, 300, 1),
        "dumaloo": .init(140, 3, 19, 6, 2, 8, 1, 350, 3),
        "fishcurry": .init(150, 13, 5, 8, 1, 3, 1, 400, 2),
        "ghevar": .init(420, 5, 58, 19, 1, 0, 1, 100, 30),
        "greenchutney": .init(80, 2, 10, 4, 3, 15, 2, 450, 3),
        "gulabjamun": .init(320, 5, 48, 12, 0, 0, 1, 150, 35),
        "idli": .init(140, 4, 29, 1, 2, 0, 1, 250, 1),
        "jalebi": .init(400, 3, 65, 15, 0, 0, 1, 100, 40),
        "kebab": .init(220, 17, 6, 14, 1, 2, 2, 500, 1),
        "kheer": .init(150, 4, 24, 4, 0, 0, 0.2, 60, 17),
        "kulfi": .init(220, 5, 25, 11, 0, 1, 0.2, 90, 22),
        "lassi": .init(80, 3, 11, 3, 0, 1, 0.1, 50, 10),
        "muttoncurry": .init(210, 16, 5, 14, 1, 2, 2, 400, 2),
        "onionpakoda": .init(300, 6, 32, 17, 3, 3, 2, 400, 4),
        "palakpaneer": .init(160, 7, 7, 12, 2, 12, 2, 400, 3),
        "poha": .init(150, 3, 25, 5, 2, 4, 2, 300, 2),
        "rajmacurry": .init(140, 7, 21, 3, 6, 3, 2, 350, 2),
        "rasmalai": .init(220, 7, 26, 10, 0, 0, 0.2, 100, 22),
        "samosa": .init(260, 5, 30, 14, 2, 2, 1, 450, 2),
        "shahipaneer": .init(220, 8, 8, 18, 1, 3, 1, 400, 4),
        "whiterice": .init(130, 3, 28, 0, 0.4, 0, 0.2, 1, 0.1)
    ]
    static func lookup(_ name: String) -> FoodEstimate? { estimates[name.lowercased().filter { $0.isLetter || $0.isNumber }] }
}

// Update only today's meals whose saved ingredients are all identifiable.
enum FoodEstimateMigration {
    static func updateToday(_ profiles: [Profile]) -> [Profile] {
        profiles.map { original in
            var profile = original
            profile.meals = original.meals.map { originalMeal in
                var meal = originalMeal
                guard Calendar.current.isDateInToday(meal.date), (meal.nutritionEstimateVersion ?? 0) < 2 else { return meal }
                let existing: [DetectedFood]
                if let foods = meal.foods, !foods.isEmpty {
                    existing = foods
                } else {
                    // Older scans store only the first name; a multi-food scan cannot be reconstructed safely.
                    guard meal.detail == "AI scan • 1 foods", meal.quantity > 0, FoodNutrition.lookup(meal.name) != nil else { return meal }
                    existing = [DetectedFood(name: meal.name, estimatedQuantity: 100, quantity: meal.quantity, baseCalories: 0, baseProtein: 0, baseCarbs: 0, baseFat: 0)]
                }
                guard existing.allSatisfy({ FoodNutrition.lookup($0.name) != nil && $0.quantity > 0 }) else { return meal }
                let updated = existing.map { food in
                    let e = FoodNutrition.lookup(food.name)!
                    return DetectedFood(id: food.id, name: food.name, estimatedQuantity: 100, quantity: food.quantity, baseCalories: e.calories, baseProtein: e.protein, baseCarbs: e.carbs, baseFat: e.fat, baseFiber: e.fiber, baseVitaminC: e.vitaminC, baseIron: e.iron, baseSodium: e.sodium, baseSugar: e.sugar, baseVitaminA: e.vitaminA, baseFolate: e.folate)
                }
                meal.foods = updated
                meal.quantity = updated.reduce(0) { $0 + $1.quantity }
                meal.calories = updated.reduce(0) { $0 + $1.calories }
                meal.protein = updated.reduce(0) { $0 + $1.protein }
                meal.carbs = updated.reduce(0) { $0 + $1.carbs }
                meal.fat = updated.reduce(0) { $0 + $1.fat }
                meal.nutritionEstimateVersion = 2
                return meal
            }
            return profile
        }
    }
}
