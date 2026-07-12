import Foundation
import SwiftUI

struct PremiumPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    let feature: PremiumFeature

    @State private var statusMessage: String?

    var body: some View {
        NavigationView {
            RootScreen {
                ScreenHeader(
                    eyebrow: "TeoPateo Premium",
                    title: "Stay supported through cravings, slips, and restarts."
                )

                VStack(alignment: .leading, spacing: 10) {
                    Label(feature.title, systemImage: "sparkles")
                        .font(.rounded(.headline, weight: .bold))
                        .foregroundColor(QuitTheme.cocoa)
                    Text(feature.summary)
                        .typeBodySecondary()
                        .fixedSize(horizontal: false, vertical: true)
                }
                .quietCard()

                includedSupport
                planOptions

                if let message = availabilityMessage {
                    Text(message)
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundColor(QuitTheme.cocoa)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(QuitTheme.peach.opacity(0.62))
                        .cornerRadius(12)
                }

                restoreAndManage

                Text("No payment is needed for basic planning, daily check-ins, progress, quitline support, or the free craving fallback.")
                    .font(.rounded(.caption))
                    .foregroundColor(QuitTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        subscriptionStore.dismissPaywall()
                        dismiss()
                    }
                    .foregroundColor(QuitTheme.cocoa)
                    .accessibilityIdentifier("premium-paywall-close-button")
                }
            }
        }
        .onAppear {
            Task {
                await subscriptionStore.loadProducts()
            }
        }
        .onChange(of: subscriptionStore.isPremium) { isPremium in
            guard isPremium else { return }
            subscriptionStore.dismissPaywall()
            dismiss()
        }
    }

    private var availabilityMessage: String? {
        statusMessage ?? subscriptionStore.lastErrorMessage
    }

    private var includedSupport: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Premium includes")
                .typeSection()

            ForEach([
                "Full guided craving rescue",
                "Adaptive recovery after a slip",
                "AI coach with your quit context",
                "Pattern insights, history, reminders, and motivation vault"
            ], id: \.self) { item in
                Label(item, systemImage: "checkmark.circle.fill")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundColor(QuitTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .quietCard()
    }

    private var planOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your support")
                .typeSection()

            planOption(.yearly, badge: "Best value")
            planOption(.monthly, badge: nil)
        }
    }

    private func planOption(_ plan: SubscriptionPlan, badge: String?) -> some View {
        let product = subscriptionStore.product(for: plan)
        let hasTrial = subscriptionStore.isEligibleForIntroductoryOffer(on: plan)
        let title = plan == .yearly ? "Yearly" : "Monthly"
        let price = product?.displayPrice ?? (plan == .yearly ? "$59.99" : "$9.99")
        let detail: String
        if hasTrial {
            detail = "7-day free trial, then \(price). Auto-renews until cancelled."
        } else {
            detail = "\(price). Auto-renews until cancelled."
        }

        return Button {
            purchase(plan)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: plan == .yearly ? "calendar" : "calendar.badge.clock")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                    .frame(width: 38, height: 38)
                    .background(QuitTheme.peach.opacity(0.68))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.rounded(.headline, weight: .bold))
                            .foregroundColor(QuitTheme.ink)
                        if let badge {
                            Text(badge)
                                .font(.rounded(.caption, weight: .bold))
                                .foregroundColor(QuitTheme.onSage)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(QuitTheme.sage)
                                .cornerRadius(8)
                        }
                    }
                    Text(detail)
                        .typeBodySecondary()
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if isPlanInProgress(plan) || subscriptionStore.isLoadingProducts {
                    ProgressView()
                        .tint(QuitTheme.cocoa)
                        .padding(.top, 8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(QuitTheme.faint)
                        .padding(.top, 10)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(QuitTheme.paper)
            .cornerRadius(18)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(subscriptionStore.isProcessingPurchase || subscriptionStore.isLoadingProducts)
        .opacity(subscriptionStore.isLoadingProducts ? 0.58 : 1)
        .accessibilityIdentifier("premium-purchase-\(plan.rawValue)-button")
    }

    private var restoreAndManage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("Restore purchases") {
                restorePurchases()
            }
            .buttonStyle(QuietButtonStyle())
            .disabled(subscriptionStore.isProcessingPurchase)
            .accessibilityIdentifier("restore-purchases-button")

            Link("Manage subscription", destination: Self.manageSubscriptionsURL)
                .font(.rounded(.subheadline, weight: .bold))
                .foregroundColor(QuitTheme.cocoa)
                .accessibilityIdentifier("manage-subscription-link")
        }
        .quietCard()
    }

    private func isPlanInProgress(_ plan: SubscriptionPlan) -> Bool {
        if case let .purchasing(purchasingPlan) = subscriptionStore.operation {
            return purchasingPlan == plan
        }
        return false
    }

    private func purchase(_ plan: SubscriptionPlan) {
        Task {
            switch await subscriptionStore.purchase(plan) {
            case .purchased:
                statusMessage = "Premium is ready."
            case .cancelled:
                statusMessage = nil
            case .pending:
                statusMessage = "Your purchase is waiting for approval. Premium will unlock when Apple confirms it."
            case let .failed(message):
                statusMessage = message
            }
        }
    }

    private func restorePurchases() {
        Task {
            let restored = await subscriptionStore.restorePurchases()
            if restored {
                statusMessage = subscriptionStore.isPremium
                    ? "Your Premium access has been restored."
                    : "No active TeoPateo Premium subscription was found."
            } else {
                statusMessage = subscriptionStore.lastErrorMessage
            }
        }
    }

    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!
}

/// A voluntary offer immediately after a user has received their personalized
/// quit plan. It always retains a clear free path so support is never held
/// behind a purchase decision.
struct OnboardingSubscriptionOfferView: View {
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    let finishOnboarding: () -> Void

    @State private var statusMessage: String?

    var body: some View {
        ZStack {
            QuitTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ScreenHeader(
                        eyebrow: "Your plan is ready",
                        title: "Choose the support that fits your quit."
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start with 7 days free")
                            .typeSection()
                        Text("Premium adds guided craving rescue, adaptive recovery, the AI coach, and pattern insights to the plan you just made.")
                            .typeBodySecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .quietCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose your support")
                            .typeSection()

                        planOption(
                            .yearly,
                            badge: "Best value",
                            savingsNote: "Save 50% compared with monthly."
                        )
                        planOption(.monthly, badge: nil, savingsNote: nil)
                    }

                    if let message = availabilityMessage {
                        Text(message)
                            .font(.rounded(.caption, weight: .bold))
                            .foregroundColor(QuitTheme.cocoa)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(QuitTheme.peach.opacity(0.62))
                            .cornerRadius(12)
                    }

                    Button("Restore purchases") {
                        restorePurchases()
                    }
                    .font(.rounded(.caption, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                    .disabled(subscriptionStore.isProcessingPurchase)
                    .accessibilityIdentifier("onboarding-restore-purchases-button")

                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 132)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Button("Continue with free version") {
                    finishOnboarding()
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityIdentifier("onboarding-continue-free-button")

                Text("Free includes your quit plan, daily check-ins, progress, quitline support, and a simple craving fallback.")
                    .font(.rounded(.caption))
                    .foregroundColor(QuitTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(QuitTheme.background)
        }
        .onAppear {
            guard !subscriptionStore.isPremium else {
                finishOnboarding()
                return
            }

            Task {
                await subscriptionStore.loadProducts()
                if subscriptionStore.isPremium {
                    finishOnboarding()
                }
            }
        }
        .onChange(of: subscriptionStore.isPremium) { isPremium in
            if isPremium {
                finishOnboarding()
            }
        }
    }

    private var availabilityMessage: String? {
        statusMessage ?? subscriptionStore.lastErrorMessage
    }

    private func planOption(
        _ plan: SubscriptionPlan,
        badge: String?,
        savingsNote: String?
    ) -> some View {
        let product = subscriptionStore.product(for: plan)
        let hasTrial = subscriptionStore.isEligibleForIntroductoryOffer(on: plan)
        let title = plan == .yearly ? "Yearly" : "Monthly"
        let price = product?.displayPrice ?? (plan == .yearly ? "$59.99" : "$9.99")
        let period = plan == .yearly ? "year" : "month"
        let detail = hasTrial
            ? "7-day free trial, then \(price) per \(period). Cancel anytime."
            : "\(price) per \(period). Cancel anytime."

        return Button {
            purchase(plan)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: plan == .yearly ? "calendar" : "calendar.badge.clock")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                    .frame(width: 38, height: 38)
                    .background(QuitTheme.peach.opacity(0.68))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.rounded(.headline, weight: .bold))
                            .foregroundColor(QuitTheme.ink)
                        if let badge {
                            Text(badge)
                                .font(.rounded(.caption, weight: .bold))
                                .foregroundColor(QuitTheme.onSage)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(QuitTheme.sage)
                                .cornerRadius(8)
                        }
                    }

                    Text(detail)
                        .typeBodySecondary()
                        .fixedSize(horizontal: false, vertical: true)

                    if let savingsNote {
                        Text(savingsNote)
                            .font(.rounded(.caption, weight: .bold))
                            .foregroundColor(QuitTheme.cocoa)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                if isPlanInProgress(plan) || subscriptionStore.isLoadingProducts {
                    ProgressView()
                        .tint(QuitTheme.cocoa)
                        .padding(.top, 8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(QuitTheme.faint)
                        .padding(.top, 10)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(QuitTheme.paper)
            .cornerRadius(18)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(subscriptionStore.isProcessingPurchase || subscriptionStore.isLoadingProducts)
        .opacity(subscriptionStore.isLoadingProducts ? 0.58 : 1)
        .accessibilityIdentifier("onboarding-purchase-\(plan.rawValue)-button")
    }

    private func isPlanInProgress(_ plan: SubscriptionPlan) -> Bool {
        if case let .purchasing(purchasingPlan) = subscriptionStore.operation {
            return purchasingPlan == plan
        }
        return false
    }

    private func purchase(_ plan: SubscriptionPlan) {
        Task {
            switch await subscriptionStore.purchase(plan) {
            case .purchased:
                finishOnboarding()
            case .cancelled:
                statusMessage = nil
            case .pending:
                statusMessage = "Your purchase is waiting for approval. Premium will unlock when Apple confirms it."
            case let .failed(message):
                statusMessage = message
            }
        }
    }

    private func restorePurchases() {
        Task {
            let restored = await subscriptionStore.restorePurchases()
            if restored, subscriptionStore.isPremium {
                finishOnboarding()
            } else if restored {
                statusMessage = "No active TeoPateo Premium subscription was found."
            } else {
                statusMessage = subscriptionStore.lastErrorMessage
            }
        }
    }
}

struct SubscriptionAccountCard: View {
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @Environment(\.openURL) private var openURL

    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: subscriptionStore.isPremium ? "checkmark.seal.fill" : "sparkles")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                    .frame(width: 38, height: 38)
                    .background(QuitTheme.peach.opacity(0.68))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(subscriptionTitle)
                        .typeSection()
                    Text(subscriptionDetail)
                        .typeBodySecondary()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if subscriptionStore.isPremium {
                Button("Manage subscription") {
                    openURL(PremiumPaywallView.manageSubscriptionsURL)
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityIdentifier("manage-subscription-button")
            } else {
                Button("Explore Premium") {
                    subscriptionStore.presentPaywall(for: .fullRescue)
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityIdentifier("open-premium-paywall-button")
            }

            Button("Restore purchases") {
                restorePurchases()
            }
            .font(.rounded(.caption, weight: .bold))
            .foregroundColor(QuitTheme.cocoa)
            .disabled(subscriptionStore.isProcessingPurchase)
            .accessibilityIdentifier("subscription-card-restore-button")

            if let statusMessage {
                Text(statusMessage)
                    .font(.rounded(.caption, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
            }
        }
        .quietCard()
    }

    private var subscriptionTitle: String {
        guard let entitlement = subscriptionStore.entitlement.premiumEntitlement else {
            return "TeoPateo Premium"
        }
        return entitlement.isTrial ? "Premium trial active" : "Premium active"
    }

    private var subscriptionDetail: String {
        guard let entitlement = subscriptionStore.entitlement.premiumEntitlement else {
            return "Full guided support is available when you want more help through cravings and restarts."
        }
        guard let expirationDate = entitlement.expirationDate else {
            return "Your Premium support is active."
        }
        return "Active through \(expirationDate.formatted(date: .abbreviated, time: .omitted))."
    }

    private func restorePurchases() {
        Task {
            let restored = await subscriptionStore.restorePurchases()
            if restored {
                statusMessage = subscriptionStore.isPremium
                    ? "Your Premium access is active."
                    : "No active TeoPateo Premium subscription was found."
            } else {
                statusMessage = subscriptionStore.lastErrorMessage
            }
        }
    }
}

struct PremiumFeaturePreview: View {
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    let feature: PremiumFeature
    let eyebrow: String
    let title: String
    let freeSupportMessage: String

    var body: some View {
        RootScreen {
            ScreenHeader(eyebrow: eyebrow, title: title)

            VStack(alignment: .leading, spacing: 10) {
                Label(feature.title, systemImage: "lock.fill")
                    .font(.rounded(.headline, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                Text(feature.summary)
                    .typeBodySecondary()
                    .fixedSize(horizontal: false, vertical: true)
                Button("See Premium support") {
                    subscriptionStore.presentPaywall(for: feature)
                }
                .buttonStyle(FilledButtonStyle())
                .accessibilityIdentifier("unlock-\(feature.rawValue)-button")
            }
            .quietCard()

            VStack(alignment: .leading, spacing: 8) {
                Text("Still available free")
                    .typeSection()
                Text(freeSupportMessage)
                    .typeBodySecondary()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .quietCard()
        }
    }
}

struct FreeRescueFallbackView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TeoPateoStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    @State private var secondsRemaining = 60
    @State private var isPauseRunning = false
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            QuitTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Pause before deciding")
                            .typeSection()
                        Text("You do not have to solve the whole day right now. Give this craving a little room to change.")
                            .typeBodySecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .quietCard()

                    fallbackSteps
                    pauseCard

                    Link("Call 1-800-QUIT-NOW", destination: Self.quitlineURL)
                        .font(.rounded(.headline, weight: .bold))
                        .foregroundColor(QuitTheme.cocoa)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(QuitTheme.peach.opacity(0.7))
                        .cornerRadius(16)

                    Button("Open basic check-in") {
                        store.selectedTab = .checkIn
                        dismiss()
                    }
                    .buttonStyle(QuietButtonStyle())

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Want a fuller plan?")
                            .typeSection()
                        Text("Premium adds the guided 10-minute rescue, adaptive recovery, and a coach that remembers your plan.")
                            .typeBodySecondary()
                            .fixedSize(horizontal: false, vertical: true)
                        Button("See full guided rescue") {
                            dismiss()
                            DispatchQueue.main.async {
                                subscriptionStore.presentPaywall(for: .fullRescue)
                            }
                        }
                        .buttonStyle(QuietButtonStyle())
                        .accessibilityIdentifier("open-full-rescue-paywall-button")
                    }
                    .quietCard()
                }
                .padding(24)
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            ScreenHeader(eyebrow: "Craving support", title: "Stay with this moment.")
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                    .frame(width: 38, height: 38)
                    .background(QuitTheme.peach.opacity(0.7))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close craving support")
        }
    }

    private var fallbackSteps: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Try this now")
                .typeSection()
            fallbackStep(number: 1, text: "Put down anything you are holding and take one sip of water.")
            fallbackStep(number: 2, text: "Breathe in for 4, then out for 6. Repeat slowly ten times.")
            fallbackStep(number: 3, text: "Delay the decision for ten minutes. Cravings rise and fall even when you do nothing else.")
        }
        .quietCard()
    }

    private var pauseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isPauseRunning ? "Keep breathing" : "Start with one minute")
                .typeSection()
            Text(isPauseRunning ? formattedTime : "A short pause can make the next choice easier.")
                .font(.rounded(.title2, weight: .heavy))
                .foregroundColor(QuitTheme.cocoa)
                .monospacedDigit()
            Button(isPauseRunning ? "Pause running" : "Start 60-second pause") {
                if !isPauseRunning {
                    startPause()
                }
            }
            .buttonStyle(FilledButtonStyle())
            .disabled(isPauseRunning)
            .accessibilityIdentifier("free-rescue-pause-button")
        }
        .quietCard()
    }

    private func fallbackStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.onCocoa)
                .frame(width: 26, height: 26)
                .background(QuitTheme.cocoa)
                .clipShape(Circle())
            Text(text)
                .typeBody()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var formattedTime: String {
        String(format: "0:%02d", max(secondsRemaining, 0))
    }

    private func startPause() {
        secondsRemaining = 60
        isPauseRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard secondsRemaining > 0 else {
                isPauseRunning = false
                timer?.invalidate()
                timer = nil
                return
            }
            secondsRemaining -= 1
        }
    }

    private static let quitlineURL = URL(string: "tel:18007848669")!
}
