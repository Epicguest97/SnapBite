import SwiftUI

private struct PlanTemplate: Identifiable {
    let id, name, icon, focus, description: String
    let menus: [[String]]
    let duration = 7
    var mealCount: Int { duration * 3 }
    func menu(day: Int) -> [String] { menus[max(day, 0) % menus.count] }
    static let all: [PlanTemplate] = [
        PlanTemplate(id: "protein", name: "Protein Focus", icon: "💪", focus: "Strength & recovery", description: "Protein-rich foods throughout the day can support muscle maintenance alongside resistance exercise.", menus: [
            ["Greek yogurt, oats & berries", "Chicken, brown rice & greens", "Fish curry, rice & vegetables"],
            ["Eggs, whole-grain toast & fruit", "Lentil and paneer bowl", "Chicken, sweet potato & salad"],
            ["Paneer scramble & roti", "Fish, quinoa & vegetables", "Dal, rice & yogurt"]]),
        PlanTemplate(id: "veggie", name: "Veggie Balance", icon: "🌱", focus: "Plant variety & fiber", description: "A vegetarian pattern featuring beans, vegetables, fruit and whole grains for more dietary variety and fiber.", menus: [
            ["Oats, yogurt & fruit", "Rajma, brown rice & salad", "Palak paneer, roti & vegetables"],
            ["Idli, sambar & fruit", "Chole, roti & cucumber", "Tofu, quinoa & greens"],
            ["Poha, peanuts & yogurt", "Dal, rice & vegetable salad", "Bean and vegetable bowl"]]),
        PlanTemplate(id: "heart", name: "Heartwise", icon: "❤️", focus: "Heart-conscious choices", description: "Emphasizes vegetables, legumes, whole grains and unsaturated fats; choose lower-sodium ingredients when possible.", menus: [
            ["Oats, berries & walnuts", "Chickpea and vegetable salad", "Fish, brown rice & broccoli"],
            ["Yogurt, fruit & seeds", "Dal, roti & greens", "Tofu, quinoa & vegetables"],
            ["Whole-grain toast, egg & fruit", "Bean and vegetable bowl", "Fish curry, rice & salad"]])
    ]
}

struct PlansView: View {
    let goals: NutritionGoals
    let profileID: UUID
    let openGoals: () -> Void
    @State private var selectedID = ""
    @State private var started = Date()
    @State private var previewID: String?
    private var selectionKey: String { "mealPlan.\(profileID.uuidString)" }
    private var dateKey: String { "mealPlanStart.\(profileID.uuidString)" }
    private var selected: PlanTemplate? { PlanTemplate.all.first { $0.id == selectedID } }
    private var preview: PlanTemplate? { PlanTemplate.all.first { $0.id == previewID } }
    private var dayIndex: Int { max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: started), to: Calendar.current.startOfDay(for: .now)).day ?? 0) }
    private var activeDay: Int { min(dayIndex, 6) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Plans").font(.custom("Nunito", size: 30, relativeTo: .largeTitle).bold())
                    Spacer()
                    Button(action: openGoals) { Image(systemName: "slider.horizontal.3").foregroundStyle(AppTheme.foreground).frame(width: 44, height: 44).background(AppTheme.card, in: Circle()).overlay(Circle().stroke(AppTheme.border)) }.accessibilityLabel("Edit nutrition goals")
                }
                ZStack(alignment: .bottomLeading) {
                    Image("PlanHero").resizable().scaledToFill().frame(height: 205).frame(maxWidth: .infinity).clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selected?.focus ?? "YOUR GOALS").font(.custom("Nunito", size: 12, relativeTo: .caption).bold()).padding(.horizontal, 12).padding(.vertical, 6).background(AppTheme.card, in: Capsule())
                        Text(selected?.name ?? "Make today count").font(.custom("Nunito", size: 24, relativeTo: .title2).bold()).foregroundStyle(.white)
                        Text("\(goals.calories) kcal daily goal · \(goals.protein)g protein goal").font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold()).foregroundStyle(.white.opacity(0.85))
                    }.padding(20)
                }.frame(height: 205).clipShape(RoundedRectangle(cornerRadius: 32))
                todayCard
                Text("Explore plans").font(.custom("Nunito", size: 20, relativeTo: .title3).bold())
                ForEach(PlanTemplate.all) { plan in
                    planCard(plan)
                }
                Text("Meal ideas are examples, not a personalized prescription. Portions and calories depend on preparation. Your goals stay unchanged when choosing a plan.").font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
            }.padding(20).padding(.bottom, 16)
        }.background(AppTheme.canvas)
        .onAppear { loadSelection() }
        .onChange(of: profileID) { _, _ in loadSelection() }
        .sheet(isPresented: Binding(get: { previewID != nil }, set: { if !$0 { previewID = nil } })) {
            if let plan = preview {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(plan.icon).font(.system(size: 40))
                            Text(plan.name).font(.custom("Nunito", size: 30, relativeTo: .largeTitle).bold())
                            Text(plan.description).foregroundStyle(AppTheme.mutedForeground)
                            Text("7 days · 21 meal ideas · your goal: \(goals.calories) kcal/day").font(.custom("Nunito", size: 14, relativeTo: .subheadline).bold())
                            Text("The calorie target is your existing goal; these example meals have not been calculated to match it.").font(.caption).foregroundStyle(AppTheme.mutedForeground)
                            ForEach(0..<plan.duration, id: \.self) { day in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Day \(day + 1)").font(.custom("Nunito", size: 18, relativeTo: .headline).bold())
                                    ForEach(Array(plan.menu(day: day).enumerated()), id: \.offset) { index, meal in
                                        Text("\(["Breakfast", "Lunch", "Dinner"][index]) · \(meal)").font(.custom("Nunito", size: 14, relativeTo: .subheadline))
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border))
                            }
                            Button(selectedID == plan.id ? "Restart plan" : "Choose this plan") { choose(plan) }.font(.custom("Nunito", size: 16, relativeTo: .body).bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(16).background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 20))
                        }.padding(20)
                    }.background(AppTheme.canvas).navigationTitle("Plan preview").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { previewID = nil } }
                }.preferredColorScheme(.light)
            }
        }
    }
    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today’s plan").font(.custom("Nunito", size: 20, relativeTo: .title3).bold())
                Spacer()
                if selected != nil { Text(dayIndex >= 7 ? "Completed" : "Day \(activeDay + 1) of 7").font(.custom("Nunito", size: 12, relativeTo: .caption).bold()).foregroundStyle(AppTheme.accent).padding(8).background(AppTheme.secondary, in: Capsule()) }
            }
            if let plan = selected, dayIndex < plan.duration {
                ForEach(Array(plan.menu(day: activeDay).enumerated()), id: \.offset) { index, meal in
                    HStack(spacing: 12) {
                        Text(FoodIcon.emoji(for: meal)).font(.system(size: 24)).frame(width: 44, height: 44).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(meal).font(.custom("Nunito", size: 16, relativeTo: .body).bold())
                            Text(["Breakfast", "Lunch", "Dinner"][index]).font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(AppTheme.mutedForeground)
                        }
                        Spacer()
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border))
                }
                Text("Suggested meals · adjust portions to your needs.").font(.caption).foregroundStyle(AppTheme.mutedForeground)
            } else {
                Text(selected == nil ? "Choose a plan below to see your meal ideas." : "Your seven-day plan is complete. Preview it to restart or choose another.").foregroundStyle(AppTheme.mutedForeground)
            }
        }.padding(18).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 32)).overlay(RoundedRectangle(cornerRadius: 32).stroke(AppTheme.border))
    }
    private func planCard(_ plan: PlanTemplate) -> some View {
        let isSelected = plan.id == selectedID
        return VStack(alignment: .leading, spacing: 10) {
            Text(isSelected ? "CURRENT · \(plan.focus.uppercased())" : plan.focus.uppercased()).font(.custom("Nunito", size: 12, relativeTo: .caption).bold()).foregroundStyle(isSelected ? .white.opacity(0.8) : AppTheme.accent)
            Text("\(plan.icon)  \(plan.name)").font(.custom("Nunito", size: 20, relativeTo: .title3).bold()).foregroundStyle(isSelected ? .white : AppTheme.foreground)
            Text("7 days · 21 meal ideas · goal \(goals.calories) kcal/day").font(.custom("Nunito", size: 14, relativeTo: .subheadline)).foregroundStyle(isSelected ? .white.opacity(0.75) : AppTheme.mutedForeground)
            Text(plan.description).font(.custom("Nunito", size: 12, relativeTo: .caption)).foregroundStyle(isSelected ? .white.opacity(0.75) : AppTheme.mutedForeground)
            Button(isSelected ? "View current plan" : "Preview plan") { previewID = plan.id }.font(.custom("Nunito", size: 16, relativeTo: .body).bold()).foregroundStyle(AppTheme.foreground).frame(maxWidth: .infinity).padding(14).background(isSelected ? AppTheme.card : AppTheme.canvas, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border))
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(isSelected ? AppTheme.forest : AppTheme.card, in: RoundedRectangle(cornerRadius: 32)).overlay(RoundedRectangle(cornerRadius: 32).stroke(isSelected ? AppTheme.forest : AppTheme.border))
    }
    private func loadSelection() {
        selectedID = UserDefaults.standard.string(forKey: selectionKey) ?? ""
        started = UserDefaults.standard.object(forKey: dateKey) as? Date ?? .now
    }
    private func choose(_ plan: PlanTemplate) {
        selectedID = plan.id; started = .now
        UserDefaults.standard.set(plan.id, forKey: selectionKey)
        UserDefaults.standard.set(started, forKey: dateKey)
        previewID = nil
    }
}
