import SwiftUI
import Roboflow

struct ContentView: View {
    @State private var selectedTab: AppTab = .today
    @State private var showCamera = false
    @State private var showModelSettings = false
    @AppStorage("roboflowAPIKey") private var apiKey = ""
    @AppStorage("selectedFoodModelFoodTaste") private var selectedModel = "foodtaste"
    @AppStorage("indianFoodNetModelID") private var modelID = "indianfoodnet-7mpua"
    @AppStorage("indianFoodNetModelVersion") private var modelVersion = "2"
    @State private var scanMessage = ""
    @State private var scanning = false
    @State private var scanID = UUID()
    @State private var capturedImage: UIImage?
    @State private var detectedFoods: [DetectedFood] = []
    @State private var selectedMealType: MealType = .lunch
    @State private var mealName = ""
    @State private var meals: [Meal]
    @State private var mealBeingEdited: Meal?
    @State private var goals: NutritionGoals
    @State private var profiles: [Profile]
    @State private var activeProfileID: UUID

    init() {
        let originalProfiles = ProfileStore.load()
        let loadedProfiles = FoodEstimateMigration.updateToday(originalProfiles)
        if loadedProfiles != originalProfiles { ProfileStore.save(loadedProfiles) }
        let loadedActiveProfileID = ProfileStore.loadActiveProfileID(from: loadedProfiles)
        let activeProfile = loadedProfiles.first(where: { $0.id == loadedActiveProfileID }) ?? loadedProfiles[0]
        _profiles = State(initialValue: loadedProfiles)
        _activeProfileID = State(initialValue: activeProfile.id)
        _meals = State(initialValue: activeProfile.meals)
        _goals = State(initialValue: activeProfile.goals)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if selectedTab != .profile {
                    AppHeader(profileName: profiles.first(where: { $0.id == activeProfileID })?.name ?? "You", meals: meals, goals: goals, profileAction: { selectedTab = .profile })
                        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 4)
                }
                Group {
                switch selectedTab {
                case .today:
                    TodayView(
                        meals: meals,
                        goals: goals,
                        profileID: activeProfileID,
                        seeAll: { selectedTab = .log },
                        scanAction: startScan,
                        editMeal: { mealBeingEdited = $0 },
                        deleteMeal: deleteMeal
                    )
                case .scan:
                    ScanView(image: capturedImage, foods: $detectedFoods, mealName: $mealName, mealType: $selectedMealType, openCamera: startScan, logFood: logFood, scanning: scanning, scanMessage: scanMessage, openSettings: { showModelSettings = true }, meals: meals, goals: goals, goBack: leaveScan)
                case .log:
                    LogView(meals: meals, goals: goals, openMeal: { mealBeingEdited = $0 })
                case .plans:
                    PlansView(goals: goals, profileID: activeProfileID, openGoals: { selectedTab = .profile })
                case .profile:
                    ProfileView(goals: $goals, meals: meals, profiles: profiles, activeProfileID: activeProfileID, switchProfile: switchProfile, addProfile: { name in updateActiveProfile(); let newProfile = Profile(name: name, meals: [], goals: NutritionGoals()); profiles.append(newProfile); ProfileStore.save(profiles); switchProfile(newProfile) }, openPlans: { selectedTab = .plans }, rename: { name in if let index = profiles.firstIndex(where: { $0.id == activeProfileID }) { profiles[index].name = name; ProfileStore.save(profiles) } })
                }
                }
            }
            .background(AppTheme.canvas)
            .foregroundStyle(AppTheme.foreground)
            .font(.custom("Nunito", size: 16, relativeTo: .body))
            .navigationBarHidden(true)
            .preferredColorScheme(.light)
            .fullScreenCover(isPresented: $showCamera) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    LiveCameraView(image: $capturedImage, apiKey: apiKey, modelID: activeModelID, version: activeModelVersion)
                } else {
                    ImagePicker(image: $capturedImage)
                }
            }
            .sheet(isPresented: $showModelSettings) {
                NavigationStack {
                    Form {
                        Picker("Food model", selection: $selectedModel) {
                            Text("Food Taste").tag("foodtaste")
                            Text("IndianFoodNet").tag("indian")
                            Text("Custom").tag("custom")
                        }
                        if selectedModel == "custom" {
                            TextField("Model project ID", text: $modelID).textInputAutocapitalization(.never).autocorrectionDisabled()
                            TextField("Model version", text: $modelVersion).keyboardType(.numberPad)
                        }
                        Text(selectedModel == "foodtaste" ? "food-taste / 1" : selectedModel == "indian" ? "indianfoodnet-7mpua / 2" : "Enter a Roboflow project and version.")
                            .font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
                        SecureField("Roboflow API key", text: $apiKey).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Text("The key is stored on this device. Use a restricted key appropriate for a mobile app.").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
                    }
                    .navigationTitle("Roboflow model")
                    .toolbar { Button("Done") { showModelSettings = false; if let image = capturedImage { detectFood(in: image) } } }
                }
            }
            .onChange(of: capturedImage) { _, image in
                if let image {
                    selectedMealType = MealType.forTime(.now)
                    detectFood(in: image)
                }
            }
            .sheet(item: $mealBeingEdited) { meal in
                MealDetailView(
                    meal: meal,
                    save: { updatedMeal in
                        guard let index = meals.firstIndex(where: { $0.id == updatedMeal.id }) else { return }
                        meals[index] = updatedMeal
                    },
                    delete: deleteMeal
                )
            }
            .onChange(of: meals) { _, updatedMeals in
                updateActiveProfile()
            }
            .onChange(of: goals) { _, updatedGoals in
                updateActiveProfile()
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AppTabBar(selectedTab: $selectedTab, scanAction: startScan)
            }
        }
    }

    private func leaveScan() {
        scanID = UUID()
        scanning = false
        capturedImage = nil
        detectedFoods = []
        selectedTab = .today
    }

    private func startScan() {
        capturedImage = nil
        detectedFoods = []
        scanID = UUID()
        scanning = false
        scanMessage = ""
        mealName = ""
        selectedTab = .scan
        showCamera = true
    }

    private var activeModelID: String {
        selectedModel == "foodtaste" ? "food-taste" : selectedModel == "indian" ? "indianfoodnet-7mpua" : modelID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var activeModelVersion: Int? {
        selectedModel == "foodtaste" ? 1 : selectedModel == "indian" ? 2 : Int(modelVersion)
    }

    private func detectFood(in image: UIImage) {
        let id = UUID()
        scanID = id
        detectedFoods = []
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !activeModelID.isEmpty,
              let version = activeModelVersion, version > 0 else {
            scanning = false
            scanMessage = "Add your Roboflow model details to detect food."
            return
        }
        scanning = true
        scanMessage = "Loading model and analyzing photo…"
        let roboflow = RoboflowMobile(apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
        roboflow.load(model: activeModelID, modelVersion: version) { model, error, _, _ in
            guard let model, error == nil else {
                DispatchQueue.main.async {
                    guard scanID == id else { return }
                    scanning = false
                    scanMessage = "Could not load the model: \(error?.localizedDescription ?? "Unknown error")"
                }
                return
            }
            model.configure(threshold: 0.5, overlap: 0.4, maxObjects: 20)
            model.detect(image: image) { predictions, error in
                let names = (predictions ?? []).compactMap { ($0 as? RFObjectDetectionPrediction)?.className }
                DispatchQueue.main.async {
                    guard scanID == id else { return }
                    scanning = false
                    if let error {
                        scanMessage = "Could not analyze the photo: \(error.localizedDescription)"
                        return
                    }
                    detectedFoods = names.map { name in
                        let estimate = FoodNutrition.lookup(name)
                        return DetectedFood(name: name, estimatedQuantity: 100, quantity: 100, baseCalories: estimate?.calories ?? 0, baseProtein: estimate?.protein ?? 0, baseCarbs: estimate?.carbs ?? 0, baseFat: estimate?.fat ?? 0, baseFiber: estimate?.fiber, baseVitaminC: estimate?.vitaminC, baseIron: estimate?.iron, baseSodium: estimate?.sodium, baseSugar: estimate?.sugar, baseVitaminA: estimate?.vitaminA, baseFolate: estimate?.folate)
                    }
                    mealName = names.first ?? ""
                    scanMessage = names.isEmpty ? "No food detected. You can add food manually or retake the photo." : "Nutrition values are illustrative estimates per 100 g. Check portions and values before logging."
                }
            }
        }
    }

    private func logFood() {
        let photoData = capturedImage?.jpegData(compressionQuality: 0.8)
        meals.insert(
            Meal(
                name: mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Meal" : mealName.trimmingCharacters(in: .whitespacesAndNewlines),
                detail: "AI scan • \(detectedFoods.count) foods",
                mealType: selectedMealType,
                quantity: detectedFoods.reduce(0) { $0 + $1.quantity },
                calories: detectedFoods.reduce(0) { $0 + $1.calories },
                protein: detectedFoods.reduce(0) { $0 + $1.protein },
                carbs: detectedFoods.reduce(0) { $0 + $1.carbs },
                fat: detectedFoods.reduce(0) { $0 + $1.fat },
                date: .now,
                imageData: photoData,
                foods: detectedFoods,
                nutritionEstimateVersion: 2
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

private struct AppHeader: View {
    let profileName: String
    let meals: [Meal]
    let goals: NutritionGoals
    let profileAction: () -> Void
    var body: some View {
                HStack(spacing: 12) {
                    Text(String(profileName.prefix(1)).uppercased()).font(.custom("Nunito", size: 24, relativeTo: .title2).bold()).foregroundStyle(.white).frame(width: 52, height: 52).background(AppTheme.forest, in: Circle())
                    VStack(alignment: .leading) {
                        Text("Welcome back").font(.custom("Nunito", size: 14, relativeTo: .subheadline)).foregroundStyle(AppTheme.mutedForeground)
                        Text("\(profileName)’s Kitchen").font(.custom("Nunito", size: 24, relativeTo: .title2).bold()).lineLimit(1)
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill").foregroundStyle(AppTheme.orange)
                        Text("\(NutritionProgress(meals: meals, goals: goals).streak)").font(.custom("Nunito", size: 16, relativeTo: .body).bold())
                    }.padding(.horizontal, 10).padding(.vertical, 8).background(AppTheme.card, in: Capsule()).overlay(Capsule().stroke(AppTheme.border)).accessibilityLabel("Calorie goal streak: \(NutritionProgress(meals: meals, goals: goals).streak) days")
                    Button(action: profileAction) { Image(systemName: "person.crop.circle.fill").font(.system(size: 38)).foregroundStyle(AppTheme.accent) }.accessibilityLabel("Profile and goals")
                }.padding(.bottom, 4)
    }
}

private struct TodayView: View {
    let meals: [Meal]
    let goals: NutritionGoals
    let profileID: UUID
    let seeAll: () -> Void
    let scanAction: () -> Void
    let editMeal: (Meal) -> Void
    let deleteMeal: (Meal) -> Void
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var waterMask = 0
    @State private var showingSearch = false
    @State private var query = ""
    private var dayMeals: [Meal] { meals.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } }
    private var calories: Int { dayMeals.reduce(0) { $0 + $1.calories } }
    private var dates: [Date] { (-3...1).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: .now)) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    ForEach(dates, id: \.self) { date in
                        let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        Button { selectedDate = date } label: {
                            VStack(spacing: 4) {
                                Text(Calendar.current.isDateInToday(date) ? "Today" : date.formatted(.dateTime.weekday(.abbreviated))).font(.custom("Nunito", size: 12, relativeTo: .caption).bold())
                                Text(date.formatted(.dateTime.day())).font(.custom("Nunito", size: 18, relativeTo: .headline).bold())
                            }.frame(maxWidth: .infinity).padding(.vertical, 11).foregroundStyle(selected ? .white : AppTheme.foreground)
                                .background(selected ? AppTheme.forest : AppTheme.card, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? AppTheme.forest : AppTheme.border))
                        }.buttonStyle(.plain)
                    }
                }
                CalorieSummary(consumed: calories, goals: goals, meals: dayMeals, isToday: Calendar.current.isDateInToday(selectedDate))
                HStack(spacing: 10) {
                    Button(action: scanAction) { Label("Snap a meal", systemImage: "viewfinder").font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).frame(maxWidth: .infinity).padding(.vertical, 16) }.foregroundStyle(.white).background(AppTheme.orange, in: RoundedRectangle(cornerRadius: 14))
                    Button { showingSearch.toggle(); query = "" } label: { Label("Search food", systemImage: "magnifyingglass").font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).frame(maxWidth: .infinity).padding(.vertical, 16) }.foregroundStyle(AppTheme.foreground).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border))
                }
                waterCard
                if showingSearch {
                    TextField("Search logged meals", text: $query).padding(14).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border))
                    Text("Search your meal history").font(.caption).foregroundStyle(AppTheme.mutedForeground)
                }
                HStack {
                    Text(showingSearch ? "Search results" : Calendar.current.isDateInToday(selectedDate) ? "Today’s meals" : "Meals for \(selectedDate.formatted(date: .abbreviated, time: .omitted))").font(.custom("Nunito", size: 20, relativeTo: .title3).bold())
                    Spacer()
                    Button("See all", action: seeAll).font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).foregroundStyle(AppTheme.accent)
                }.padding(.top, 4)
                let shownMeals = showingSearch ? (query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : meals.filter { $0.name.localizedCaseInsensitiveContains(query) }) : dayMeals
                if shownMeals.isEmpty {
                    Text(showingSearch ? "No matching meals." : "No meals logged for this day.").font(.custom("Nunito", size: 14, relativeTo: .subheadline)).foregroundStyle(AppTheme.mutedForeground).padding(16).frame(maxWidth: .infinity, alignment: .leading).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20))
                } else {
                    VStack(spacing: 8) {
                        ForEach(shownMeals) { meal in
                            Button { editMeal(meal) } label: { MealCard(meal: meal) }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(20).padding(.bottom, 12)
        }.background(AppTheme.canvas)
            .onAppear { loadWater() }
            .onChange(of: selectedDate) { _, _ in loadWater() }
            .onChange(of: profileID) { _, _ in loadWater() }
    }
    private var waterKey: String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        return "water.\(profileID.uuidString).\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
    private var waterCount: Int { (0..<8).filter { waterMask & (1 << $0) != 0 }.count }
    private func loadWater() { waterMask = UserDefaults.standard.integer(forKey: waterKey) & 255 }
    private func toggleWater(_ index: Int) {
        waterMask ^= 1 << index
        UserDefaults.standard.set(waterMask, forKey: waterKey)
    }
    private var waterCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "drop.fill").font(.title3).foregroundStyle(AppTheme.fats).frame(width: 44, height: 44).background(AppTheme.fats.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Water").font(.custom("Nunito", size: 20, relativeTo: .title3).bold())
                    Text("\(waterCount) of 8 glasses").font(.custom("Nunito", size: 14, relativeTo: .subheadline)).foregroundStyle(AppTheme.mutedForeground)
                }
                Spacer()
                Button {
                    if let index = (0..<8).first(where: { waterMask & (1 << $0) == 0 }) { toggleWater(index) }
                } label: { Label("Add", systemImage: "plus").font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 10).background(AppTheme.foreground, in: Capsule()) }.disabled(waterCount == 8)
            }
            HStack(spacing: 5) {
                ForEach(0..<8, id: \.self) { index in
                    let filled = waterMask & (1 << index) != 0
                    Button { toggleWater(index) } label: {
                        Image(systemName: filled ? "drop.fill" : "drop").font(.system(size: 17, weight: .semibold)).foregroundStyle(filled ? .white : AppTheme.mutedForeground)
                            .frame(maxWidth: .infinity).frame(height: 44).background(filled ? AppTheme.fats : AppTheme.canvas, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(filled ? AppTheme.fats : AppTheme.border))
                    }.buttonStyle(.plain).accessibilityLabel("Glass \(index + 1), \(filled ? "logged" : "not logged")").accessibilityHint(filled ? "Double tap to remove" : "Double tap to log")
                }
            }
        }.padding(16).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 32)).overlay(RoundedRectangle(cornerRadius: 32).stroke(AppTheme.border))
    }
}

private struct CalorieSummary: View {
    let consumed: Int
    let goals: NutritionGoals
    let meals: [Meal]
    let isToday: Bool
    private var remaining: Int { max(goals.calories - consumed, 0) }
    private var progress: Double { min(Double(consumed) / Double(max(goals.calories, 1)), 1) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(isToday ? "Remaining today" : "Remaining").font(.custom("Nunito", size: 14, relativeTo: .subheadline)).foregroundStyle(.white.opacity(0.7))
                    Text("\(remaining) kcal").font(.custom("Nunito", size: 30, relativeTo: .largeTitle).bold()).foregroundStyle(.white)
                    Text("Eaten \(consumed) · Goal \(goals.calories)").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                ZStack {
                    Circle().stroke(.white.opacity(0.18), lineWidth: 10)
                    Circle().trim(from: 0, to: progress).stroke(.white, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text("\(Int(progress * 100))%").font(.custom("Nunito", size: 18, relativeTo: .headline).bold()).foregroundStyle(.white)
                }.frame(width: 78, height: 78).accessibilityLabel("\(Int(progress * 100)) percent of calorie goal")
            }
            HStack(spacing: 8) {
                summaryMacro("Protein", meals.reduce(0) { $0 + $1.protein }, goals.protein)
                summaryMacro("Carbs", meals.reduce(0) { $0 + $1.carbs }, goals.carbs)
                summaryMacro("Fat", meals.reduce(0) { $0 + $1.fat }, goals.fat)
            }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 32))
    }
    private func summaryMacro(_ title: String, _ value: Int, _ goal: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(.white.opacity(0.7))
            Text("\(value) / \(goal)g").font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).foregroundStyle(.white).minimumScaleFactor(0.7).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ScanView: View {
    let image: UIImage?
    @Binding var foods: [DetectedFood]
    @Binding var mealName: String
    @Binding var mealType: MealType
    let openCamera: () -> Void
    let logFood: () -> Void
    let scanning: Bool
    let scanMessage: String
    let openSettings: () -> Void
    let meals: [Meal]
    let goals: NutritionGoals
    let goBack: () -> Void
    @State private var showAddFood = false
    @State private var editingFoods = false
    @State private var choosingShare = false
    @State private var shareContent: MealShareContent?
    private var calories: Int { foods.reduce(0) { $0 + $1.calories } }
    private var protein: Int { foods.reduce(0) { $0 + $1.protein } }
    private var carbs: Int { foods.reduce(0) { $0 + $1.carbs } }
    private var fat: Int { foods.reduce(0) { $0 + $1.fat } }

    private var shareSummary: String {
        let name = mealName.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = foods.map { "• \($0.name): \(Int($0.quantity)) g, \($0.calories) kcal" }.joined(separator: "\n")
        return "\(name.isEmpty ? "My meal" : name)\n\(calories) kcal · Protein \(protein)g · Carbs \(carbs)g · Fat \(fat)g\n\n\(items)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let image {
                    HStack {
                        Button(action: goBack) { Image(systemName: "arrow.left").font(.headline).foregroundStyle(AppTheme.foreground).frame(width: 44, height: 44).background(AppTheme.card, in: Circle()).overlay(Circle().stroke(AppTheme.border)).contentShape(Circle()) }.buttonStyle(.plain).accessibilityLabel("Back to Home")
                        Text("Today · \(mealType.rawValue) · \(Date.now.formatted(date: .omitted, time: .shortened))").font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).foregroundStyle(AppTheme.mutedForeground).lineLimit(1)
                        Spacer()
                        Text("\(Int(foods.reduce(0) { $0 + $1.quantity }))g").font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).padding(10).background(AppTheme.card, in: Capsule()).overlay(Capsule().stroke(AppTheme.border))
                    }
                    Image(uiImage: image).resizable().scaledToFill().frame(height: 290).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 32))
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Detected dish").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(.white.opacity(0.8))
                                Text(mealName.isEmpty ? "Your meal" : mealName).font(.custom("Nunito", size: 20, relativeTo: .title3).bold()).foregroundStyle(.white).lineLimit(2)
                            }.padding(14).background(AppTheme.forest.opacity(0.85), in: RoundedRectangle(cornerRadius: 20)).padding(12)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            Button(action: openCamera) { Label("Retake", systemImage: "camera").font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).foregroundStyle(AppTheme.foreground).padding(10).background(AppTheme.card, in: Capsule()) }.padding(12)
                        }
                        .overlay(alignment: .topLeading) {
                            if !scanning && !foods.isEmpty { Label("AI identified", systemImage: "circle.fill").font(.custom("Nunito", size: 12, relativeTo: .caption).bold()).foregroundStyle(AppTheme.accent).padding(10).background(AppTheme.card, in: Capsule()).padding(12) }
                        }
                    if scanning { ProgressView(scanMessage) }
                    else if !scanMessage.isEmpty { Text(scanMessage).font(.custom("Nunito", size: 14, relativeTo: .subheadline)).foregroundStyle(AppTheme.mutedForeground) }
                    Button("Model settings", action: openSettings).font(.custom("Nunito", size: 14, relativeTo: .subheadline))
                    ScanNutritionHero(calories: calories, protein: protein, carbs: carbs, fat: fat, log: logFood, edit: { editingFoods.toggle() }, disabled: scanning || foods.isEmpty)
                    let today = meals.filter { Calendar.current.isDateInToday($0.date) }
                    HStack(spacing: 10) {
                        ScanMacroCard(title: "Protein", value: protein, dailyTotal: today.reduce(0) { $0 + $1.protein } + protein, goal: goals.protein, color: AppTheme.protein, icon: "leaf")
                        ScanMacroCard(title: "Carbs", value: carbs, dailyTotal: today.reduce(0) { $0 + $1.carbs } + carbs, goal: goals.carbs, color: AppTheme.carbs, icon: "carrot")
                        ScanMacroCard(title: "Fat", value: fat, dailyTotal: today.reduce(0) { $0 + $1.fat } + fat, goal: goals.fat, color: AppTheme.fats, icon: "drop")
                    }
                    Text("Bars show today’s total including this meal.").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("What’s inside").font(.custom("Nunito", size: 20, relativeTo: .title3).bold())
                            Spacer()
                            Button(editingFoods ? "Done" : "Edit") { editingFoods.toggle() }.font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).tint(AppTheme.protein)
                        }
                        ForEach($foods) { $food in
                            DetectedFoodRow(food: $food, editing: editingFoods) { foods.removeAll { $0.id == food.id } }
                            if food.id != foods.last?.id { Divider().overlay(AppTheme.border) }
                        }
                        if editingFoods { Button { showAddFood = true } label: { Label("Add food", systemImage: "plus") }.tint(AppTheme.protein) }
                        if foods.isEmpty && !scanning { Text("No foods added yet.").foregroundStyle(AppTheme.mutedForeground) }
                    }.padding(18).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 32)).overlay(RoundedRectangle(cornerRadius: 32).stroke(AppTheme.border))
                    TextField("Meal name", text: $mealName)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 16).padding(.vertical, 13)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14))
                    let todayCalories = meals.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.calories }
                    HStack(spacing: 14) {
                        Image(systemName: "target").font(.title2).foregroundStyle(.white).frame(width: 48, height: 48).background(.white.opacity(0.15), in: Circle())
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(todayCalories) / \(goals.calories) kcal today").font(.custom("Nunito", size: 16, relativeTo: .body).bold()).foregroundStyle(.white)
                            ProgressView(value: min(Double(todayCalories) / Double(max(goals.calories, 1)), 1)).tint(.white)
                            Text("\(max(goals.calories - todayCalories, 0)) kcal left").font(.caption).foregroundStyle(.white.opacity(0.7))
                        }
                    }.padding(18).background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 20))
                    HStack(spacing: 10) {
                        Button(action: logFood) {
                            Label("Add to diary", systemImage: "plus").font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).frame(maxWidth: .infinity).padding(.vertical, 16)
                        }.foregroundStyle(.white).background(AppTheme.foreground, in: RoundedRectangle(cornerRadius: 20)).disabled(scanning || foods.isEmpty).opacity(scanning || foods.isEmpty ? 0.5 : 1)
                        Button { choosingShare = true } label: {
                            Label("Share", systemImage: "square.and.arrow.up").font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).frame(maxWidth: .infinity).padding(.vertical, 16)
                        }.foregroundStyle(AppTheme.foreground).background(AppTheme.blush, in: RoundedRectangle(cornerRadius: 20))
                    }
                } else {
                    Spacer(minLength: 56)
                    VStack(spacing: 18) {
                        Image(systemName: "camera.viewfinder").font(.system(size: 56, weight: .light)).foregroundStyle(AppTheme.accent)
                        Text("Scan a meal").font(.custom("Nunito", size: 30, relativeTo: .title).bold())
                        Text("Take a photo and review the estimated food, calories, and macros before logging.")
                            .multilineTextAlignment(.center).foregroundStyle(AppTheme.mutedForeground).padding(.horizontal, 24)
                        Button("Open Camera", action: openCamera).buttonStyle(.borderedProminent).tint(AppTheme.accent).padding(.top, 6)
                    }.frame(maxWidth: .infinity)
                }
            }.padding(20).padding(.bottom, 18)
        }
        .confirmationDialog("What would you like to share?", isPresented: $choosingShare, titleVisibility: .visible) {
            Button("Photo only") { if let image { shareContent = MealShareContent(items: [image]) } }
            Button("Meal summary only") { shareContent = MealShareContent(items: [shareSummary]) }
            Button("Photo and meal summary") { if let image { shareContent = MealShareContent(items: [image, shareSummary]) } }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(item: $shareContent) { content in ActivitySheet(items: content.items) }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
        .sheet(isPresented: $showAddFood) {
            AddFoodView { food in
                foods.append(food)
            }
        }
    }
}

private struct MealShareContent: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}

private struct ScanNutritionHero: View {
    let calories, protein, carbs, fat: Int
    let log: () -> Void
    let edit: () -> Void
    let disabled: Bool
    private var total: Double { Double(max(protein + carbs + fat, 1)) }
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(AppTheme.muted, lineWidth: 12)
                Circle().trim(from: 0, to: Double(protein) / total).stroke(AppTheme.protein, lineWidth: 12)
                Circle().trim(from: Double(protein) / total, to: Double(protein + carbs) / total).stroke(AppTheme.carbs, lineWidth: 12)
                Circle().trim(from: Double(protein + carbs) / total, to: Double(protein + carbs + fat) / total).stroke(AppTheme.fats, lineWidth: 12)
                VStack(spacing: 0) { Text("\(calories)").font(.custom("Nunito", size: 24, relativeTo: .title2).bold()); Text("kcal").font(.caption).foregroundStyle(AppTheme.mutedForeground) }
            }.frame(width: 110, height: 110)
            VStack(alignment: .leading, spacing: 10) {
                Text("Nutrition entered").font(.custom("Nunito", size: 12, relativeTo: .caption).bold()).foregroundStyle(AppTheme.protein).padding(.horizontal, 9).padding(.vertical, 5).background(AppTheme.secondary, in: Capsule())
                Text("Review your meal").font(.custom("Nunito", size: 18, relativeTo: .headline).bold())
                Text("Enter nutrition and adjust portions before logging.").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
                HStack(spacing: 8) {
                    macroLegend(protein, AppTheme.protein)
                    macroLegend(carbs, AppTheme.carbs)
                    macroLegend(fat, AppTheme.fats)
                }
                HStack {
                Button("Log meal", action: log).font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(10).background(AppTheme.protein, in: RoundedRectangle(cornerRadius: 14)).disabled(disabled).opacity(disabled ? 0.5 : 1)
                Button(action: edit) { Image(systemName: "pencil").foregroundStyle(AppTheme.foreground).padding(10).background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border)) }.accessibilityLabel("Edit detected foods")
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(18).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 32)).overlay(RoundedRectangle(cornerRadius: 32).stroke(AppTheme.border))
    }
    private func macroLegend(_ value: Int, _ color: Color) -> some View {
        HStack(spacing: 3) { Circle().fill(color).frame(width: 7, height: 7); Text("\(value)g").font(.custom("Nunito", size: 12, relativeTo: .caption).bold()) }.fixedSize()
    }
}

private struct ScanMacroCard: View {
    let title: String
    let value: Int
    let dailyTotal: Int
    let goal: Int
    let color: Color
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 34, height: 34).background(color.opacity(0.15), in: Circle())
            Text(title).font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
            Text("\(value)g").font(.custom("Nunito", size: 20, relativeTo: .title3).bold())
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.muted)
                    Capsule().fill(color).frame(width: geometry.size.width * min(CGFloat(max(dailyTotal, 0)) / CGFloat(max(goal, 1)), 1))
                }
            }.frame(height: 5).accessibilityLabel("\(dailyTotal) of \(goal) grams today including this meal")
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border))
    }
}

private struct NutritionTotal: View {
    let calories, protein, carbs, fat: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(calories)").font(.system(size: 34, weight: .bold, design: .rounded))
                Text("kcal").foregroundStyle(AppTheme.mutedForeground)
                Spacer()
                Text("Nutrition entered").font(.custom("Nunito", size: 12, relativeTo: .caption).weight(.semibold)).foregroundStyle(AppTheme.accent)
            }
            HStack {
                MacroValue(title: "Protein", value: protein, color: AppTheme.protein)
                MacroValue(title: "Carbs", value: carbs, color: AppTheme.carbs)
                MacroValue(title: "Fat", value: fat, color: AppTheme.fats)
            }
        }.padding(18).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border.opacity(0.7)))
    }
}

private struct MacroValue: View {
    let title: String; let value: Int; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)g").font(.custom("Nunito", size: 18, relativeTo: .headline))
            Text(title).font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct DetectedFoodRow: View {
    @Binding var food: DetectedFood
    let editing: Bool
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(FoodIcon.emoji(for: food.name)).font(.system(size: 24)).frame(width: 46, height: 46).background(AppTheme.muted, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border))
                VStack(alignment: .leading, spacing: 3) {
                    Text(food.name).font(.custom("Nunito", size: 18, relativeTo: .headline))
                    Text("\(Int(food.quantity))g").font(.custom("Nunito", size: 14, relativeTo: .subheadline)).foregroundStyle(AppTheme.mutedForeground)
                }
                Spacer()
                Text("\(food.calories) kcal").font(.custom("Nunito", size: 16, relativeTo: .headline).bold()).lineLimit(1).fixedSize()
                if editing { Button(role: .destructive, action: remove) {
                    Image(systemName: "trash")
                        .font(.custom("Nunito", size: 14, relativeTo: .subheadline))
                }
                .accessibilityLabel("Remove \(food.name)") }
            }
            if editing {
            Stepper("Quantity", value: $food.quantity, in: 20...600, step: 10).labelsHidden()
            Text("Nutrition for \(Int(food.estimatedQuantity)) g").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
            HStack {
                nutritionField("kcal", value: $food.baseCalories)
                nutritionField("Protein", value: $food.baseProtein)
                nutritionField("Carbs", value: $food.baseCarbs)
                nutritionField("Fat", value: $food.baseFat)
            }
            }
        }.padding(.vertical, 4)
    }
    private func nutritionField(_ title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.custom("Nunito", size: 12, relativeTo: .caption2)).foregroundStyle(AppTheme.mutedForeground)
            TextField(title, value: value, format: .number)
                .keyboardType(.numberPad).foregroundStyle(AppTheme.foreground).tint(AppTheme.protein)
                .padding(.horizontal, 8).padding(.vertical, 10)
                .background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
        }
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
        HStack { Text(title); Spacer(); TextField(title, value: value, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing); Text(unit).foregroundStyle(AppTheme.mutedForeground) }
    }

    private func numberField(_ title: String, value: Binding<Double>, unit: String, decimal: Bool) -> some View {
        HStack { Text(title); Spacer(); TextField(title, value: value, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing); Text(unit).foregroundStyle(AppTheme.mutedForeground) }
    }
}

private struct MealCard: View {
    let meal: Meal
    var body: some View {
        HStack(spacing: 12) {
            MealThumbnail(meal: meal)
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name).font(.custom("Nunito", size: 18, relativeTo: .headline).bold()).foregroundStyle(AppTheme.foreground).lineLimit(2)
                Text("\(meal.date.formatted(date: .omitted, time: .shortened)) · \(meal.mealType.rawValue) · \(meal.protein)g protein")
                    .font(.custom("Nunito", size: 14, relativeTo: .subheadline)).foregroundStyle(AppTheme.mutedForeground).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading).layoutPriority(1)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(meal.calories) kcal").font(.custom("Nunito", size: 16, relativeTo: .body).bold()).foregroundStyle(AppTheme.foreground).lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text("Logged").lineLimit(1)
                }.font(.custom("Nunito", size: 12, relativeTo: .caption).bold()).foregroundStyle(AppTheme.accent).fixedSize()
            }.fixedSize(horizontal: true, vertical: true).layoutPriority(2)
        }.padding(16).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border))
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
                Text(FoodIcon.emoji(for: meal.name))
                    .font(.system(size: 26))
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.accent.opacity(0.12))
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct MealDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let meal: Meal
    let save: (Meal) -> Void
    let delete: (Meal) -> Void
    @State private var editing = false
    @State private var showingPhoto = false
    private var canEdit: Bool { Date().timeIntervalSince(meal.date) < 24 * 60 * 60 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let data = meal.imageData, let image = UIImage(data: data) {
                        Button { showingPhoto = true } label: {
                            Image(uiImage: image).resizable().scaledToFill().frame(height: 240).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 20))
                                .overlay(alignment: .bottomTrailing) { Label("View photo", systemImage: "arrow.up.left.and.arrow.down.right").font(.custom("Nunito", size: 12, relativeTo: .caption).bold()).padding(10).background(.ultraThinMaterial, in: Capsule()).padding(12) }
                        }.buttonStyle(.plain)
                    }
                    Text(meal.mealType.rawValue.uppercased()).font(.custom("Nunito", size: 12, relativeTo: .caption).bold()).tracking(1.2).foregroundStyle(AppTheme.accent)
                    Text(meal.name).font(.custom("Nunito", size: 30, relativeTo: .largeTitle).bold())
                    Text(meal.date.formatted(date: .complete, time: .shortened)).foregroundStyle(AppTheme.mutedForeground)
                    NutritionTotal(calories: meal.calories, protein: meal.protein, carbs: meal.carbs, fat: meal.fat)
                    Text("Quantity: \(Int(meal.quantity)) g").foregroundStyle(AppTheme.mutedForeground)
                    if !canEdit { Text("Editing is available for 24 hours after logging.").font(.footnote).foregroundStyle(AppTheme.mutedForeground) }
                }.padding(20)
            }.background(AppTheme.canvas)
                .navigationTitle("Meal details").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                    if canEdit { ToolbarItem(placement: .confirmationAction) { Button("Edit") { editing = true } } }
                }
                .sheet(isPresented: $editing) {
                    MealEditor(meal: meal, save: { updated in save(updated); dismiss() }, delete: { item in delete(item); dismiss() })
                }
                .fullScreenCover(isPresented: $showingPhoto) {
                    if let data = meal.imageData, let image = UIImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Color.black.ignoresSafeArea()
                            Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity)
                            Button { showingPhoto = false } label: { Image(systemName: "xmark").font(.custom("Nunito", size: 18, relativeTo: .headline)).foregroundStyle(.white).padding(14).background(.white.opacity(0.2), in: Circle()) }.padding()
                        }
                    }
                }
        }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 16) {
                        MealThumbnail(meal: meal)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(meal.mealType.rawValue.uppercased()).font(.custom("Nunito", size: 12, relativeTo: .caption).bold()).tracking(1).foregroundStyle(AppTheme.accent)
                            Text("Meal details").font(.custom("Nunito", size: 24, relativeTo: .title2).bold())
                            Text(meal.date.formatted(date: .abbreviated, time: .shortened)).font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
                        }
                        Spacer()
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
                    Text("YOUR MEAL").font(.custom("Nunito", size: 12, relativeTo: .caption).bold()).tracking(1.2).foregroundStyle(AppTheme.mutedForeground)
                    VStack(spacing: 16) {
                        TextField("Meal name", text: $name).font(.custom("Nunito", size: 18, relativeTo: .headline))
                        Divider()
                        Picker("Meal type", selection: $mealType) { ForEach(MealType.allCases) { Text($0.rawValue).tag($0) } }.tint(AppTheme.accent)
                        Divider()
                        numberField("Quantity", value: $quantity, unit: "g", decimal: true)
                    }.padding(18).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20))
                    Text("NUTRITION").font(.custom("Nunito", size: 12, relativeTo: .caption).bold()).tracking(1.2).foregroundStyle(AppTheme.mutedForeground)
                    VStack(spacing: 16) {
                        numberField("Calories", value: $calories, unit: "kcal")
                        Divider()
                        numberField("Protein", value: $protein, unit: "g")
                        Divider()
                        numberField("Carbs", value: $carbs, unit: "g")
                        Divider()
                        numberField("Fat", value: $fat, unit: "g")
                    }.padding(18).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20))
                    Button(role: .destructive) { delete(meal); dismiss() } label: {
                        Label("Delete meal", systemImage: "trash").frame(maxWidth: .infinity).padding(16)
                    }.background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                }.padding(20)
            }.background(AppTheme.canvas)
            .navigationTitle("Edit meal").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(Meal(id: meal.id, name: name, detail: meal.detail, mealType: mealType, quantity: quantity, calories: calories, protein: protein, carbs: carbs, fat: fat, date: meal.date, imageData: meal.imageData, foods: (quantity == meal.quantity && calories == meal.calories && protein == meal.protein && carbs == meal.carbs && fat == meal.fat) ? meal.foods : nil, nutritionEstimateVersion: meal.nutritionEstimateVersion)); dismiss()
                    }
                }
            }
        }
    }
    private func numberField(_ title: String, value: Binding<Int>, unit: String) -> some View {
        HStack { Text(title); Spacer(); TextField(title, value: value, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing); Text(unit).foregroundStyle(AppTheme.mutedForeground) }
    }
    private func numberField(_ title: String, value: Binding<Double>, unit: String, decimal: Bool) -> some View {
        HStack { Text(title); Spacer(); TextField(title, value: value, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing); Text(unit).foregroundStyle(AppTheme.mutedForeground) }
    }
}

private struct AppTabBar: View {
    @Binding var selectedTab: AppTab
    let scanAction: () -> Void
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            tabButton(.today)
            tabButton(.log)
            Button(action: scanAction) {
                Image(systemName: "viewfinder").font(.system(size: 25, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 64, height: 64).background(AppTheme.orange, in: Circle())
                    .overlay(Circle().stroke(AppTheme.canvas, lineWidth: 5))
                    .shadow(color: AppTheme.orange.opacity(0.3), radius: 12, y: 5)
            }.accessibilityLabel("Scan food").offset(y: -14).frame(maxWidth: .infinity)
            tabButton(.plans)
            tabButton(.profile)
        }.padding(.horizontal, 8).frame(height: 72).background {
                Capsule().fill(AppTheme.card).overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 6).background(AppTheme.canvas)
    }
    private func tabButton(_ tab: AppTab) -> some View {
        Button { selectedTab = tab } label: {
            VStack(spacing: 4) { Image(systemName: tab.icon).font(.system(size: 21, weight: .medium)); Text(tab.title).font(.custom("Nunito", size: 12, relativeTo: .caption).weight(.semibold)) }
                .foregroundStyle(selectedTab == tab ? AppTheme.accent : AppTheme.mutedForeground).frame(maxWidth: .infinity)
        }
    }
}

#Preview { ContentView() }
