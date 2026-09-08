import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .today
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var detectedFoods = DetectedFood.sample
    @State private var selectedMealType: MealType = .lunch
    @State private var meals: [Meal]
    @State private var mealBeingEdited: Meal?
    @State private var goals: NutritionGoals
    @State private var showProfile = false

    init() {
        _meals = State(initialValue: MealStore.load())
        _goals = State(initialValue: GoalsStore.load())
    }

    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case .today:
                    TodayView(meals: meals, goals: goals) { mealBeingEdited = $0 }
                case .scan:
                    ScanView(image: capturedImage, foods: $detectedFoods, mealType: $selectedMealType, openCamera: startScan, logFood: logFood)
                case .log:
                    LogView(meals: meals, goals: goals)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showCamera) { ImagePicker(image: $capturedImage) }
            .sheet(item: $mealBeingEdited) { meal in
                MealEditor(meal: meal) { updatedMeal in
                    guard let index = meals.firstIndex(where: { $0.id == updatedMeal.id }) else { return }
                    meals[index] = updatedMeal
                }
            }
            .sheet(isPresented: $showProfile) {
                NavigationStack {
                    ProfileView(goals: $goals)
                }
            }
            .onChange(of: meals) { _, updatedMeals in
                MealStore.save(updatedMeals)
            }
            .onChange(of: goals) { _, updatedGoals in
                GoalsStore.save(updatedGoals)
            }
            .overlay(alignment: .topTrailing) {
                ProfileButton { showProfile = true }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AppTabBar(selectedTab: $selectedTab, scanAction: startScan)
            }
        }
    }

    private func startScan() {
        capturedImage = nil
        detectedFoods = DetectedFood.sample
        selectedTab = .scan
        showCamera = true
    }

    private func logFood() {
        meals.insert(
            Meal(
                name: "Chicken rice bowl",
                detail: "AI scan • \(detectedFoods.count) foods",
                mealType: selectedMealType,
                quantity: detectedFoods.reduce(0) { $0 + $1.quantity },
                calories: detectedFoods.reduce(0) { $0 + $1.calories },
                protein: detectedFoods.reduce(0) { $0 + $1.protein },
                carbs: detectedFoods.reduce(0) { $0 + $1.carbs },
                fat: detectedFoods.reduce(0) { $0 + $1.fat },
                date: .now
            ),
            at: 0
        )
        capturedImage = nil
        selectedTab = .today
    }
}

private struct TodayView: View {
    let meals: [Meal]
    let goals: NutritionGoals
    let editMeal: (Meal) -> Void
    private var todayMeals: [Meal] { meals.filter { Calendar.current.isDateInToday($0.date) } }
    private var calories: Int { todayMeals.reduce(0) { $0 + $1.calories } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Today").font(.largeTitle.bold())
                    Text(Date.now.formatted(date: .complete, time: .omitted)).foregroundStyle(.secondary)
                }
                CalorieSummary(consumed: calories, goal: goals.calories)
                HStack {
                    Text("Meals").font(.title3.bold())
                    Spacer()
                    Text("\(todayMeals.count) logged").font(.subheadline).foregroundStyle(.secondary)
                }
                if todayMeals.isEmpty {
                    ContentUnavailableView("No meals logged", systemImage: "fork.knife", description: Text("Scan a meal to add it here."))
                } else {
                    ForEach(todayMeals) { meal in MealCard(meal: meal) { editMeal(meal) } }
                }
            }
            .padding(20).padding(.bottom, 18)
        }
    }
}

private struct CalorieSummary: View {
    let consumed, goal: Int
    private var remaining: Int { max(goal - consumed, 0) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(consumed)").font(.system(size: 42, weight: .bold, design: .rounded))
                    Text("of \(goal) kcal daily goal").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "flame.fill").font(.title2).foregroundStyle(AppTheme.accent)
                    .padding(14).background(AppTheme.accent.opacity(0.12), in: Circle())
            }
            ProgressView(value: min(Double(consumed) / Double(goal), 1)).tint(AppTheme.accent).scaleEffect(y: 1.8)
            Text("\(remaining) kcal remaining").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
        }
        .padding(20).background(.background, in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct ScanView: View {
    let image: UIImage?
    @Binding var foods: [DetectedFood]
    @Binding var mealType: MealType
    let openCamera: () -> Void
    let logFood: () -> Void
    private var calories: Int { foods.reduce(0) { $0 + $1.calories } }
    private var protein: Int { foods.reduce(0) { $0 + $1.protein } }
    private var carbs: Int { foods.reduce(0) { $0 + $1.carbs } }
    private var fat: Int { foods.reduce(0) { $0 + $1.fat } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill().frame(height: 220).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 24))
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Review your scan").font(.title2.bold())
                            Text("Adjust quantities before logging.").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Retake", action: openCamera).font(.subheadline.weight(.semibold))
                    }
                    NutritionTotal(calories: calories, protein: protein, carbs: carbs, fat: fat)
                    Text("Detected foods").font(.title3.bold())
                    ForEach($foods) { $food in DetectedFoodRow(food: $food) }
                    Picker("Meal type", selection: $mealType) {
                        ForEach(MealType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu).padding(.horizontal, 16).padding(.vertical, 13)
                    .background(.background, in: RoundedRectangle(cornerRadius: 14))
                    Button(action: logFood) {
                        Label("Log Food", systemImage: "checkmark").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
                    }
                    .buttonStyle(.borderedProminent).tint(AppTheme.accent)
                } else {
                    Spacer(minLength: 56)
                    VStack(spacing: 18) {
                        Image(systemName: "camera.viewfinder").font(.system(size: 56, weight: .light)).foregroundStyle(AppTheme.accent)
                        Text("Scan a meal").font(.title.bold())
                        Text("Take a photo and review the estimated food, calories, and macros before logging.")
                            .multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal, 24)
                        Button("Open Camera", action: openCamera).buttonStyle(.borderedProminent).tint(AppTheme.accent).padding(.top, 6)
                    }.frame(maxWidth: .infinity)
                }
            }.padding(20).padding(.bottom, 18)
        }
    }
}

private struct NutritionTotal: View {
    let calories, protein, carbs, fat: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(calories)").font(.system(size: 34, weight: .bold, design: .rounded))
                Text("kcal").foregroundStyle(.secondary)
                Spacer()
                Text("AI estimate").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.accent)
            }
            HStack {
                MacroValue(title: "Protein", value: protein, color: .blue)
                MacroValue(title: "Carbs", value: carbs, color: .orange)
                MacroValue(title: "Fat", value: fat, color: .purple)
            }
        }.padding(18).background(.background, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct MacroValue: View {
    let title: String; let value: Int; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)g").font(.headline)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct DetectedFoodRow: View {
    @Binding var food: DetectedFood
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(food.name).font(.headline)
                    Text("\(food.calories) kcal • \(food.protein)g protein").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(food.quantity))g").font(.headline)
            }
            Stepper("Quantity", value: $food.quantity, in: 20...600, step: 10).labelsHidden()
        }.padding(16).background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct MealCard: View {
    let meal: Meal; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: meal.mealType == .breakfast ? "sunrise.fill" : "fork.knife")
                    .foregroundStyle(AppTheme.accent).frame(width: 42, height: 42)
                    .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.mealType.rawValue.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(AppTheme.accent)
                    Text(meal.name).font(.headline)
                    Text("\(meal.calories) kcal  •  P \(meal.protein)g  C \(meal.carbs)g  F \(meal.fat)g").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }.padding(14).background(.background, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }
}

private struct MealEditor: View {
    @Environment(\.dismiss) private var dismiss
    let meal: Meal; let save: (Meal) -> Void
    @State private var name: String; @State private var mealType: MealType; @State private var quantity: Double
    @State private var calories: Int; @State private var protein: Int; @State private var carbs: Int; @State private var fat: Int
    init(meal: Meal, save: @escaping (Meal) -> Void) {
        self.meal = meal; self.save = save
        _name = State(initialValue: meal.name); _mealType = State(initialValue: meal.mealType); _quantity = State(initialValue: meal.quantity)
        _calories = State(initialValue: meal.calories); _protein = State(initialValue: meal.protein); _carbs = State(initialValue: meal.carbs); _fat = State(initialValue: meal.fat)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Name", text: $name)
                    Picker("Meal type", selection: $mealType) { ForEach(MealType.allCases) { Text($0.rawValue).tag($0) } }
                    numberField("Quantity", value: $quantity, unit: "g", decimal: true)
                }
                Section("Nutrition") {
                    numberField("Calories", value: $calories, unit: "kcal")
                    numberField("Protein", value: $protein, unit: "g")
                    numberField("Carbs", value: $carbs, unit: "g")
                    numberField("Fat", value: $fat, unit: "g")
                }
            }
            .navigationTitle("Edit meal").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(Meal(id: meal.id, name: name, detail: meal.detail, mealType: mealType, quantity: quantity, calories: calories, protein: protein, carbs: carbs, fat: fat, date: meal.date)); dismiss()
                    }
                }
            }
        }
    }
    private func numberField(_ title: String, value: Binding<Int>, unit: String) -> some View {
        HStack { Text(title); Spacer(); TextField(title, value: value, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing); Text(unit).foregroundStyle(.secondary) }
    }
    private func numberField(_ title: String, value: Binding<Double>, unit: String, decimal: Bool) -> some View {
        HStack { Text(title); Spacer(); TextField(title, value: value, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing); Text(unit).foregroundStyle(.secondary) }
    }
}

private struct AppTabBar: View {
    @Binding var selectedTab: AppTab; let scanAction: () -> Void
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            tabButton(.today)
            Button { selectedTab = .scan; scanAction() } label: {
                Image(systemName: AppTab.scan.icon).font(.system(size: 27, weight: .medium)).foregroundStyle(.white)
                    .frame(width: 78, height: 78).background(AppTheme.accent, in: Circle())
                    .overlay { Circle().stroke(.white, lineWidth: 6) }.shadow(color: AppTheme.accent.opacity(0.25), radius: 18, y: 8)
            }.accessibilityLabel("Scan food").offset(y: -25)
            tabButton(.log)
        }.padding(.horizontal, 12).padding(.top, 10).frame(height: 82).background(Color(uiColor: .systemBackground))
    }
    private func tabButton(_ tab: AppTab) -> some View {
        Button { selectedTab = tab } label: {
            VStack(spacing: 6) {
                Image(systemName: tab.icon).font(.system(size: 22, weight: .medium))
                Text(tab.title).font(.system(size: 12, weight: .semibold))
            }.foregroundStyle(selectedTab == tab ? AppTheme.accent : Color.primary.opacity(0.7)).frame(maxWidth: .infinity)
        }.accessibilityLabel(tab.title)
    }
}

#Preview { ContentView() }
