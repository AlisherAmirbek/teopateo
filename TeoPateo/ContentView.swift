import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TeoPateoStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "house.fill")
                }
                .tag(AppTab.today)

            PlanView()
                .tabItem {
                    Label("Plan", systemImage: "calendar.badge.checkmark")
                }
                .tag(AppTab.plan)

            CheckInView()
                .tabItem {
                    Label("Check-in", systemImage: "checkmark")
                }
                .tag(AppTab.checkIn)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar")
                }
                .tag(AppTab.insights)

            CoachView()
                .tabItem {
                    Label("Coach", systemImage: "bubble.left")
                }
                .tag(AppTab.coach)
        }
        .accentColor(QuitTheme.cocoa)
        .fullScreenCover(isPresented: $store.isOnboardingPresented) {
            OnboardingView()
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $store.isCravingModePresented) {
            CravingModeView()
                .environmentObject(store)
        }
    }
}
