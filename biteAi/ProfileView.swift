import SwiftUI

struct ProfileView: View {
    @Binding var goals: NutritionGoals
    let meals: [Meal]
    private var progress: NutritionProgress { NutritionProgress(meals: meals, goals: goals) }
    let profiles: [Profile]
    let activeProfileID: UUID
    let switchProfile: (Profile) -> Void
    let addProfile: (String) -> Void
    let openPlans: () -> Void
    let rename: (String) -> Void
    @State private var showAddProfile = false
    @State private var newProfileName = ""
    private var planName: String {
        let id = UserDefaults.standard.string(forKey: "mealPlan.\(activeProfileID.uuidString)") ?? ""
        switch id { case "protein": return "Protein Focus"; case "veggie": return "Veggie Balance"; case "heart": return "Heartwise"; default: return "No plan selected" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PersonalGoalCard(profileID: activeProfileID, name: profiles.first(where: { $0.id == activeProfileID })?.name ?? "", goals: $goals, rename: rename).id(activeProfileID)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Preferences & plan").font(.custom("Nunito", size: 20, relativeTo: .title3).bold()).padding(.bottom, 12)
                    HStack(spacing: 12) {
                        preferenceIcon("fork.knife")
                        VStack(alignment: .leading, spacing: 3) { Text("Protein target").font(.custom("Nunito", size: 16, relativeTo: .body).bold()); Text("\(goals.protein)g per day").font(.custom("Nunito", size: 14, relativeTo: .subheadline)).foregroundStyle(AppTheme.mutedForeground) }
                        Spacer()
                        Stepper("Protein target", value: $goals.protein, in: 20...300, step: 5).labelsHidden()
                    }.padding(.vertical, 12)
                    Divider().overlay(AppTheme.border)
                    HStack(spacing: 12) {
                        preferenceIcon("leaf")
                        VStack(alignment: .leading, spacing: 3) { Text("Diet type").font(.custom("Nunito", size: 16, relativeTo: .body).bold()); Text(goals.dietaryPreference.rawValue).font(.custom("Nunito", size: 14, relativeTo: .subheadline)).foregroundStyle(AppTheme.mutedForeground) }
                        Spacer()
                        Picker("Diet type", selection: $goals.dietaryPreference) { ForEach(NutritionGoals.DietaryPreference.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().tint(AppTheme.accent)
                    }.padding(.vertical, 12)
                    Divider().overlay(AppTheme.border)
                    Button(action: openPlans) { HStack(spacing: 12) {
                        preferenceIcon("calendar")
                        VStack(alignment: .leading, spacing: 3) { Text("Meal plan").font(.custom("Nunito", size: 16, relativeTo: .body).bold()).foregroundStyle(AppTheme.foreground); Text(planName).font(.custom("Nunito", size: 14, relativeTo: .subheadline)).foregroundStyle(AppTheme.mutedForeground) }
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(AppTheme.accent)
                    }.padding(.vertical, 12) }.buttonStyle(.plain)
                    Divider().overlay(AppTheme.border)
                    HStack(spacing: 12) {
                        preferenceIcon("drop")
                        VStack(alignment: .leading, spacing: 3) { Text("Water intake").font(.custom("Nunito", size: 16, relativeTo: .body).bold()); Text("8 glasses per day · track on Home").font(.custom("Nunito", size: 14, relativeTo: .subheadline)).foregroundStyle(AppTheme.mutedForeground) }
                        Spacer()
                    }.padding(.vertical, 12)
                }.padding(20).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 32)).overlay(RoundedRectangle(cornerRadius: 32).stroke(AppTheme.border))
                VStack(alignment: .leading, spacing: 14) {
                    HStack { Text("Switch profile").font(.custom("Nunito", size: 20, relativeTo: .title3).bold()); Spacer(); Button { newProfileName = ""; showAddProfile = true } label: { Label("Add", systemImage: "plus").font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()) }.tint(AppTheme.accent) }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(profiles) { profile in
                                Button { switchProfile(profile) } label: {
                                    VStack(spacing: 8) {
                                        Text(String(profile.name.prefix(1)).uppercased()).font(.custom("Nunito", size: 20, relativeTo: .title3).bold()).foregroundStyle(.white).frame(width: 48, height: 48).background(AppTheme.forest, in: Circle())
                                        Text(profile.name).font(.custom("Nunito", size: 16, relativeTo: .body).bold()).foregroundStyle(AppTheme.foreground).lineLimit(1)
                                        Text(profile.id == activeProfileID ? "● Active" : "\(profile.goals.calories) kcal").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(profile.id == activeProfileID ? AppTheme.accent : AppTheme.mutedForeground)
                                    }.frame(width: 112).padding(.vertical, 16).background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(profile.id == activeProfileID ? AppTheme.accent : AppTheme.border, lineWidth: profile.id == activeProfileID ? 2 : 1))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    Text("Each profile keeps its own diary, goals and plans.").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
                }.padding(20).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 32)).overlay(RoundedRectangle(cornerRadius: 32).stroke(AppTheme.border))
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("This week").foregroundStyle(AppTheme.mutedForeground)
                            Text(progress.streak > 0 ? "You’re on a streak!" : "Build your streak").font(.custom("Nunito", size: 24, relativeTo: .title2).bold()).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Label("\(progress.streak) days", systemImage: "flame.fill").font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).foregroundStyle(AppTheme.forest).padding(10).background(AppTheme.secondary, in: Capsule())
                    }
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(progress.week, id: \.self) { date in
                            let value = progress.calories(on: date)
                            VStack(spacing: 8) {
                                if Calendar.current.isDateInToday(date) { Text("\(value)").font(.custom("Nunito", size: 12, relativeTo: .caption).bold()).lineLimit(1).minimumScaleFactor(0.6) }
                                RoundedRectangle(cornerRadius: 14).fill(Calendar.current.isDateInToday(date) ? AppTheme.forest : AppTheme.muted)
                                    .frame(height: max(6, 90 * min(CGFloat(value) / CGFloat(max(goals.calories, 1)), 1)))
                                Text(date.formatted(.dateTime.weekday(.narrow))).font(.custom("Nunito", size: 12, relativeTo: .caption).bold()).foregroundStyle(Calendar.current.isDateInToday(date) ? .white : AppTheme.mutedForeground).frame(width: 28, height: 28).background(Calendar.current.isDateInToday(date) ? AppTheme.forest : .clear, in: Circle())
                            }.frame(maxWidth: .infinity, alignment: .bottom).accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted)): \(value) calories")
                        }
                    }.frame(height: 150, alignment: .bottom)
                    let loggedDays = progress.week.filter { !progress.meals(on: $0).isEmpty }
                    let averageCalories = loggedDays.isEmpty ? 0 : loggedDays.reduce(0) { $0 + progress.calories(on: $1) } / loggedDays.count
                    let averageProtein = loggedDays.isEmpty ? 0 : loggedDays.reduce(0) { total, day in total + progress.meals(on: day).reduce(0) { $0 + $1.protein } } / loggedDays.count
                    HStack(spacing: 8) {
                        progressValue("Avg kcal", "\(averageCalories)")
                        progressValue("Avg protein", "\(averageProtein)g")
                        progressValue("Goal days", "\(progress.week.filter { progress.calories(on: $0) >= goals.calories }.count)/7")
                    }
                    Text("Goal days and streak use your current calorie target. A streak can continue from yesterday.").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
                }.padding(20).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 32)).overlay(RoundedRectangle(cornerRadius: 32).stroke(AppTheme.border))
                let todayCalories = progress.calories(on: .now)
                HStack(spacing: 16) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.25), lineWidth: 8)
                        Circle().trim(from: 0, to: min(Double(todayCalories) / Double(max(goals.calories, 1)), 1)).stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                        Image(systemName: "target").font(.title2).foregroundStyle(.white)
                    }.frame(width: 62, height: 62)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Daily calorie goal").font(.custom("Nunito", size: 18, relativeTo: .headline).bold()).foregroundStyle(.white)
                        Text("\(todayCalories) / \(goals.calories) kcal today").font(.custom("Nunito", size: 14, relativeTo: .subheadline)).foregroundStyle(.white.opacity(0.7))
                        ProgressView(value: min(Double(todayCalories) / Double(max(goals.calories, 1)), 1)).tint(.white)
                    }
                }.padding(20).background(AppTheme.forest, in: RoundedRectangle(cornerRadius: 32))
                let proteinDays = progress.week.filter { day in progress.meals(on: day).reduce(0) { $0 + $1.protein } >= goals.protein }.count
                let lateSnacks = meals.filter { meal in progress.week.contains(where: { Calendar.current.isDate($0, inSameDayAs: meal.date) }) && meal.mealType == .snack && (Calendar.current.component(.hour, from: meal.date) >= 21 || Calendar.current.component(.hour, from: meal.date) < 5) }.count
                HStack(spacing: 12) {
                    insightCard("Protein goal hit", value: "\(proteinDays)/7", detail: "Days this week", icon: "protein", color: AppTheme.carbs)
                    insightCard("Late-night snacks", value: "\(lateSnacks)", detail: "Logged this week", icon: "moon", color: AppTheme.fats)
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text("Daily targets").font(.custom("Nunito", size: 18, relativeTo: .headline))
                    VStack(spacing: 0) {
                        goalRow("Calories", value: $goals.calories, range: 1_000...5_000, step: 50, unit: "kcal")
                        Divider()
                        goalRow("Protein", value: $goals.protein, range: 20...300, step: 5, unit: "g")
                        Divider()
                        goalRow("Carbs", value: $goals.carbs, range: 50...500, step: 5, unit: "g")
                        Divider()
                        goalRow("Fat", value: $goals.fat, range: 20...200, step: 5, unit: "g")
                    }.padding(.horizontal, 16).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20))
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text("Preferences").font(.custom("Nunito", size: 18, relativeTo: .headline))
                    VStack(spacing: 16) {
                        Picker("Units", selection: $goals.units) { ForEach(NutritionGoals.Units.allCases) { Text($0.rawValue).tag($0) } }
                        Divider()
                        Picker("Diet", selection: $goals.dietaryPreference) { ForEach(NutritionGoals.DietaryPreference.allCases) { Text($0.rawValue).tag($0) } }
                    }.tint(AppTheme.accent).padding(18).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20))
                }
            }.padding(20).padding(.bottom, 24)
        }
        .alert("Add profile", isPresented: $showAddProfile) {
            TextField("Name", text: $newProfileName)
            Button("Cancel", role: .cancel) { }
            Button("Add") { let name = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines); if !name.isEmpty { addProfile(name) } }
        } message: { Text("Enter a name for the new profile.") }
        .background(AppTheme.canvas)
        .foregroundStyle(AppTheme.foreground)
        .font(.custom("Nunito", size: 16, relativeTo: .body))

    }

    private func preferenceIcon(_ symbol: String) -> some View {
        Image(systemName: symbol).foregroundStyle(AppTheme.foreground).frame(width: 42, height: 42).background(AppTheme.canvas, in: Circle()).overlay(Circle().stroke(AppTheme.border))
    }

    private func insightCard(_ title: String, value: String, detail: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if icon == "protein" { SteakIcon().stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)).frame(width: 23, height: 23) }
                else { Image(systemName: icon).foregroundStyle(color) }
            }.frame(width: 42, height: 42).background(color.opacity(0.15), in: Circle())
            Text(title).font(.custom("Nunito", size: 14, relativeTo: .subheadline)).foregroundStyle(AppTheme.mutedForeground).lineLimit(2)
            Text(value).font(.custom("Nunito", size: 30, relativeTo: .largeTitle).bold())
            Text(detail).font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
        }.frame(maxWidth: .infinity, minHeight: 150, alignment: .leading).padding(16).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border))
    }

    private func progressValue(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.custom("Nunito", size: 18, relativeTo: .headline).bold())
            Text(title).font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground).lineLimit(1).minimumScaleFactor(0.75)
        }.frame(maxWidth: .infinity).padding(.vertical, 12).background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border))
    }

    private func goalRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue) \(unit)")
                    .foregroundStyle(AppTheme.mutedForeground)
            }
        }.padding(.vertical, 14)
    }
}

struct ProfileButton: View {
    let action: () -> Void
    let doubleTapAction: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "person.fill")
                .font(.custom("Nunito", size: 14, relativeTo: .subheadline).weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 36, height: 36)
                .background(AppTheme.accent.opacity(0.13), in: Circle())
        }
        .accessibilityLabel("Profile and goals")
        .onTapGesture(count: 2, perform: doubleTapAction)
        .padding(.top, 20)
        .padding(Edge.Set.trailing, 20)
    }
}

private struct SteakIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.78))
        path.addCurve(to: CGPoint(x: rect.width * 0.84, y: rect.height * 0.28), control1: CGPoint(x: rect.width * 0.02, y: rect.height * 0.52), control2: CGPoint(x: rect.width * 0.43, y: -rect.height * 0.12))
        path.addCurve(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.78), control1: CGPoint(x: rect.width * 1.12, y: rect.height * 0.64), control2: CGPoint(x: rect.width * 0.36, y: rect.height * 1.05))
        path.addEllipse(in: CGRect(x: rect.width * 0.45, y: rect.height * 0.26, width: rect.width * 0.20, height: rect.height * 0.20))
        path.move(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.62))
        path.addCurve(to: CGPoint(x: rect.width * 0.83, y: rect.height * 0.51), control1: CGPoint(x: rect.width * 0.31, y: rect.height * 0.83), control2: CGPoint(x: rect.width * 0.65, y: rect.height * 0.75))
        return path
    }
}
