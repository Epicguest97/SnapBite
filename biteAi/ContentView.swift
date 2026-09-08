import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .today
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var detectedFoods = DetectedFood.sample
    @State private var selectedMealType: MealType = .lunch
    @State private var mealName = "Chicken rice bowl"
    @State private var meals: [Meal]
    @State private var mealBeingEdited: Meal?
    @State private var goals: NutritionGoals
    @State private var showProfile = false
    @State private var profiles: [Profile]
    @State private var activeProfileID: UUID

    init() {
        let loadedProfiles = ProfileStore.load()
        let loadedActiveProfileID = ProfileStore.loadActiveProfileID(from: loadedProfiles)
        let activeProfile = loadedProfiles.first(where: { $0.id == loadedActiveProfileID }) ?? loadedProfiles[0]
        _profiles = State(initialValue: loadedProfiles)
        _activeProfileID = State(initialValue: activeProfile.id)
        _meals = State(initialValue: activeProfile.meals)
        _goals = State(initialValue: activeProfile.goals)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case .today:
                    TodayView(
                        meals: meals,
                        goals: goals,
                        editMeal: { mealBeingEdited = $0 },
                        deleteMeal: deleteMeal
                    )
                case .scan:
                    ScanView(image: capturedImage, foods: $detectedFoods, mealName: $mealName, mealType: $selectedMealType, openCamera: startScan, logFood: logFood)
                case .log:
                    LogView(meals: meals, goals: goals)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showCamera) { ImagePicker(image: $capturedImage) }
            .sheet(item: $mealBeingEdited) { meal in
                MealEditor(
                    meal: meal,
                    save: { updatedMeal in
                        guard let index = meals.firstIndex(where: { $0.id == updatedMeal.id }) else { return }
                        meals[index] = updatedMeal
                    },
                    delete: deleteMeal
                )
            }
            .sheet(isPresented: $showProfile) {
                NavigationStack {
                    ProfileView(
                        goals: $goals,
                        profiles: profiles,
                        activeProfileID: activeProfileID,
                        switchProfile: switchProfile
                    )
                }
            }
            .onChange(of: meals) { _, updatedMeals in
                updateActiveProfile()
            }
            .onChange(of: goals) { _, updatedGoals in
                updateActiveProfile()
            }
            .overlay(alignment: .topTrailing) {
                ProfileButton(
                    action: { showProfile = true },
                    doubleTapAction: switchToNextProfile
                )
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AppTabBar(selectedTab: $selectedTab, scanAction: startScan)
            }
        }
    }

    private func startScan() {
        capturedImage = nil
        detectedFoods = DetectedFood.sample
        mealName = "Chicken rice bowl"
        selectedTab = .scan
        showCamera = true
    }

    private func logFood() {
        let photoData = capturedImage?.jpegData(compressionQuality: 0.8)
        meals.insert(
            Meal(
                name: mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Chicken rice bowl" : mealName.trimmingCharacters(in: .whitespacesAndNewlines),
                detail: "AI scan • \(detectedFoods.count) foods",
                mealType: selectedMealType,
                quantity: detectedFoods.reduce(0) { $0 + $1.quantity },
                calories: detectedFoods.reduce(0) { $0 + $1.calories },
                protein: detectedFoods.reduce(0) { $0 + $1.protein },
                carbs: detectedFoods.reduce(0) { $0 + $1.carbs },
                fat: detectedFoods.reduce(0) { $0 + $1.fat },
                date: .now,
                imageData: photoData
            ),
            at: 0
        )
        capturedImage = nil
        selectedTab = .today
    }

    private func deleteMeal(_ meal: Meal) {
        meals.removeAll { $0.id == meal.id }
    }

    private func switchProfile(_ profile: Profile) {
        updateActiveProfile()
        activeProfileID = profile.id
        meals = profile.meals
        goals = profile.goals
        ProfileStore.saveActiveProfileID(profile.id)
    }

    private func switchToNextProfile() {
        guard profiles.count > 1,
              let activeIndex = profiles.firstIndex(where: { $0.id == activeProfileID }) else { return }
        let nextIndex = (activeIndex + 1) % profiles.count
        switchProfile(profiles[nextIndex])
    }

    private func updateActiveProfile() {
        guard let index = profiles.firstIndex(where: { $0.id == activeProfileID }) else { return }
        profiles[index].meals = meals
        profiles[index].goals = goals
        ProfileStore.save(profiles)
    }
}

private struct TodayView: View {
    let meals: [Meal]
    let goals: NutritionGoals
    let editMeal: (Meal) -> Void
    let deleteMeal: (Meal) -> Void
    private var todayMeals: [Meal] { meals.filter { Calendar.current.isDateInToday($0.date) } }
    private var calories: Int { todayMeals.reduce(0) { $0 + $1.calories } }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Today").font(.largeTitle.bold())
                    Text(Date.now.formatted(date: .complete, time: .omitted)).foregroundStyle(.secondary)
                }
                .listRowSeparator(.hidden)
                CalorieSummary(consumed: calories, goal: goals.calories)
                    .listRowSeparator(.hidden)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 20, leading: 20, bottom: 0, trailing: 20))

            Section {
                if todayMeals.isEmpty {
                    ContentUnavailableView("No meals logged", systemImage: "fork.knife", description: Text("Scan a meal to add it here."))
                } else {
                    ForEach(todayMeals) { meal in
                        MealCard(meal: meal)
                            .contentShape(Rectangle())
                            .onTapGesture { editMeal(meal) }
                    }
                }
            }
            header: {
                HStack {
                    Text("Meals").font(.title3.bold())
                    Spacer()
                    Text("\(todayMeals.count) logged").font(.subheadline).foregroundStyle(.secondary)
                }
                .textCase(nil)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
    @Binding var mealName: String
    @Binding var mealType: MealType
    let openCamera: () -> Void
    let logFood: () -> Void
    @State private var showAddFood = false
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
                    HStack {
                        Text("Detected foods").font(.title3.bold())
                        Spacer()
                        Button {
                            showAddFood = true
                        } label: {
                            Label("Add food", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    ForEach($foods) { $food in
                        DetectedFoodRow(food: $food) {
                            foods.removeAll { $0.id == food.id }
                        }
                    }
                    TextField("Meal name", text: $mealName)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 16).padding(.vertical, 13)
                        .background(.background, in: RoundedRectangle(cornerRadius: 14))
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
        .sheet(isPresented: $showAddFood) {
            AddFoodView { food in
                foods.append(food)
            }
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
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(food.name).font(.headline)
                    Text("\(food.calories) kcal • \(food.protein)g protein").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(food.quantity))g").font(.headline)
                Button(role: .destructive, action: remove) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                }
                .accessibilityLabel("Remove \(food.name)")
            }
            Stepper("Quantity", value: $food.quantity, in: 20...600, step: 10).labelsHidden()
        }.padding(16).background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct AddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    let addFood: (DetectedFood) -> Void
    @State private var name = ""
    @State private var quantity = 100.0
    @State private var calories = 100
    @State private var protein = 0
    @State private var carbs = 0
    @State private var fat = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Food name", text: $name)
                    numberField("Quantity", value: $quantity, unit: "g", decimal: true)
                }
                Section("Nutrition") {
                    numberField("Calories", value: $calories, unit: "kcal")
                    numberField("Protein", value: $protein, unit: "g")
                    numberField("Carbs", value: $carbs, unit: "g")
                    numberField("Fat", value: $fat, unit: "g")
                }
            }
            .navigationTitle("Add food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addFood(
                            DetectedFood(
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                estimatedQuantity: quantity,
                                quantity: quantity,
                                baseCalories: calories,
                                baseProtein: protein,
                                baseCarbs: carbs,
                                baseFat: fat
                            )
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

private struct MealCard: View {
    let meal: Meal
    var body: some View {
            HStack(spacing: 13) {
                MealThumbnail(meal: meal)
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.mealType.rawValue.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(AppTheme.accent)
                    Text(meal.name).font(.headline)
                    Text("\(meal.calories) kcal  •  P \(meal.protein)g  C \(meal.carbs)g  F \(meal.fat)g").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }.padding(14).background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct MealThumbnail: View {
    let meal: Meal

    var body: some View {
        Group {
            if let imageData = meal.imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: meal.mealType == .breakfast ? "sunrise.fill" : "fork.knife")
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.accent.opacity(0.12))
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct MealEditor: View {
    @Environment(\.dismiss) private var dismiss
    let meal: Meal
    let save: (Meal) -> Void
    let delete: (Meal) -> Void
    @State private var name: String; @State private var mealType: MealType; @State private var quantity: Double
    @State private var calories: Int; @State private var protein: Int; @State private var carbs: Int; @State private var fat: Int
    init(meal: Meal, save: @escaping (Meal) -> Void, delete: @escaping (Meal) -> Void) {
        self.meal = meal; self.save = save; self.delete = delete
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
                Section {
                    Button(role: .destructive) {
                        delete(meal)
                        dismiss()
                    } label: {
                        Label("Delete Meal", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Edit meal").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(Meal(id: meal.id, name: name, detail: meal.detail, mealType: mealType, quantity: quantity, calories: calories, protein: protein, carbs: carbs, fat: fat, date: meal.date, imageData: meal.imageData)); dismiss()
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
