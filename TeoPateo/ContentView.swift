import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TeoPateoStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

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
                .environmentObject(subscriptionStore)
        }
        .fullScreenCover(isPresented: $store.isCravingModePresented) {
            CravingModeView()
                .environmentObject(store)
        }
        .sheet(item: paywallFeatureBinding) { feature in
            PremiumPaywallView(feature: feature)
                .environmentObject(subscriptionStore)
        }
        .onAppear {
            store.refreshNotificationAuthorization()
        }
        .onChange(of: subscriptionStore.isPremium) { isPremium in
            guard !isPremium, store.notificationSettings.riskyWindowEnabled else { return }
            store.setNotificationEnabled(.riskyWindow, isEnabled: false)
        }
    }

    private var paywallFeatureBinding: Binding<PremiumFeature?> {
        Binding(
            get: { subscriptionStore.paywallFeature },
            set: { feature in
                if feature == nil {
                    subscriptionStore.dismissPaywall()
                }
            }
        )
    }
}
