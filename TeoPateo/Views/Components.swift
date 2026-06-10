import AVFoundation
import SwiftUI

struct FlexibleTags: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let items: [String]
    @Binding var selected: Set<String>

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 148 : 104), spacing: 8)
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isSelected = selected.contains(item)
                Button {
                    Haptics.selection()
                    if isSelected {
                        selected.remove(item)
                    } else {
                        selected.insert(item)
                    }
                } label: {
                    Text(L10n.key(item))
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundColor(isSelected ? QuitTheme.onCocoa : QuitTheme.cocoa)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 24)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 6)
                        .background(isSelected ? QuitTheme.cocoa : QuitTheme.peach.opacity(0.62))
                        .cornerRadius(18)
                }
                .accessibilityLabel(L10n.string(item))
                .accessibilityValue(L10n.selectedState(isSelected))
                .accessibilityHint(isSelected ? L10n.string("Double-tap to deselect.") : L10n.string("Double-tap to select."))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("tag-\(item)")
            }
        }
    }
}

struct ScreenHeader: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(L10n.key(eyebrow))
                .accessibilityHidden(true)
                .typeLabel()
            Text(L10n.key(title))
                .typeDisplay()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Spacing.smd)
    }
}

struct AnimatedMascotView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let size: CGFloat

    /// Bumped on each tap to ask the video view to play from the beginning.
    @State private var playToken = 0

    var body: some View {
        content
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private var content: some View {
        if !reduceMotion, let url = Bundle.main.url(forResource: "basic_animation", withExtension: "mov") {
            TapToPlayMascotVideoView(url: url, playToken: playToken)
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.selection()
                    playToken += 1
                }
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(L10n.string("Teo"))
                .accessibilityHint(L10n.string("Double-tap to play Teo's animation."))
                .accessibilityIdentifier("teo-mascot")
        } else {
            staticMascot
                .accessibilityHidden(true)
        }
    }

    private var staticMascot: some View {
        Image("Mascot")
            .resizable()
            .scaledToFit()
            .opacity(0.98)
    }
}

/// A single expressive Teo pose used with restraint. Breathes gently when idle,
/// can be tapped for a quiet, haptic reaction, and can animate in for a win
/// moment. Honours Reduce Motion (no idle/spring motion, no pose swap).
struct TeoMascotView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let pose: MascotPose
    var breathing = true
    var interactive = false
    var entrance = false
    var reactionPose: MascotPose = .playful

    @State private var breathingIn = false
    @State private var reacting = false
    @State private var appeared = false

    var body: some View {
        Image(pose: reacting ? reactionPose : pose)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .opacity(entrance && !appeared ? 0 : 1)
            .animation(breathingAnimation, value: breathingIn)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.5), value: reacting)
            .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.72), value: appeared)
            .contentShape(Rectangle())
            .onTapGesture { react() }
            .allowsHitTesting(interactive)
            .onAppear {
                if breathing && !reduceMotion {
                    breathingIn = true
                }
                appeared = true
            }
            .accessibilityElement()
            .accessibilityLabel(pose.accessibilityMood)
            .accessibilityAddTraits(interactive ? .isButton : [])
            .accessibilityHint(interactive ? L10n.string("Double-tap for a little encouragement.") : "")
            .accessibilityIdentifier("teo-mascot")
    }

    private var scale: CGFloat {
        if entrance && !appeared {
            return reduceMotion ? 1 : 0.82
        }
        if reacting {
            return 1.08
        }
        if breathing && !reduceMotion {
            return breathingIn ? 1.015 : 0.985
        }
        return 1
    }

    private var breathingAnimation: Animation? {
        breathing && !reduceMotion
            ? .easeInOut(duration: 3.6).repeatForever(autoreverses: true)
            : nil
    }

    private func react() {
        guard interactive else { return }
        Haptics.selection()
        guard !reduceMotion else { return }
        reacting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            reacting = false
        }
    }
}

/// Shows Teo's first frame at rest and plays the clip once each time `playToken`
/// changes (i.e. on tap), freezing on the final frame when it finishes.
private struct TapToPlayMascotVideoView: UIViewRepresentable {
    let url: URL
    let playToken: Int

    func makeUIView(context: Context) -> TapToPlayVideoUIView {
        let view = TapToPlayVideoUIView()
        view.configure(url: url)
        view.syncPlayToken(playToken)
        return view
    }

    func updateUIView(_ uiView: TapToPlayVideoUIView, context: Context) {
        uiView.configure(url: url)
        uiView.syncPlayToken(playToken)
    }

    static func dismantleUIView(_ uiView: TapToPlayVideoUIView, coordinator: ()) {
        uiView.stop()
    }
}

private final class TapToPlayVideoUIView: UIView {
    private var currentURL: URL?
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var lastToken: Int?

    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        playerLayer.backgroundColor = UIColor.clear.cgColor
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        stop()
    }

    func configure(url: URL) {
        guard currentURL != url else {
            return
        }

        stop()
        currentURL = url
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.freezeOnLastFrame()
        }

        playerLayer.player = player
        self.player = player

        // Render the first frame at rest; playback only happens on tap.
        player.seek(to: .zero)
    }

    /// Plays from the start whenever the token advances. The very first sync
    /// only records the baseline so Teo stays still until the user taps.
    func syncPlayToken(_ token: Int) {
        defer { lastToken = token }
        guard let lastToken, token != lastToken else { return }
        playFromBeginning()
    }

    func stop() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        player?.pause()
        playerLayer.player = nil
        player = nil
        currentURL = nil
        lastToken = nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            player?.pause()
        }
    }

    private func playFromBeginning() {
        guard let player else { return }
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak player] _ in
            player?.play()
        }
    }

    private func freezeOnLastFrame() {
        player?.pause()
        guard let player, let duration = player.currentItem?.duration, duration.isNumeric else {
            return
        }

        let finalFrameOffset = CMTime(value: 1, timescale: 30)
        let targetTime = CMTimeCompare(duration, finalFrameOffset) > 0 ? duration - finalFrameOffset : .zero
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: finalFrameOffset)
    }
}

struct RootScreen<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = AdaptiveScreenMetrics(
                width: proxy.size.width,
                horizontalSizeClass: horizontalSizeClass,
                dynamicTypeSize: dynamicTypeSize
            )

            ZStack {
                QuitTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                        content
                    }
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, metrics.verticalPadding)
                    .padding(.bottom, metrics.verticalPadding)
                    .frame(maxWidth: metrics.readingMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct AdaptiveScreenMetrics {
    let width: CGFloat
    let horizontalSizeClass: UserInterfaceSizeClass?
    let dynamicTypeSize: DynamicTypeSize

    var usesWideLayout: Bool {
        horizontalSizeClass == .regular && width >= 760 && !dynamicTypeSize.isAccessibilitySize
    }

    var horizontalPadding: CGFloat {
        usesWideLayout ? 32 : 24
    }

    var verticalPadding: CGFloat {
        usesWideLayout ? 28 : 24
    }

    var contentMaxWidth: CGFloat {
        usesWideLayout ? 1080 : 620
    }

    var readingMaxWidth: CGFloat {
        usesWideLayout ? 680 : 620
    }

    var cardSpacing: CGFloat {
        usesWideLayout ? 18 : 14
    }

    var columnSpacing: CGFloat {
        usesWideLayout ? 18 : 14
    }
}

struct StatusBanner: View {
    let status: SaveStatus
    let persistenceError: String?

    var body: some View {
        if let message = persistenceError ?? status.message {
            Text(message)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(status.isFailure || persistenceError != nil ? QuitTheme.cocoa : QuitTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background((status.isFailure || persistenceError != nil ? QuitTheme.peach : QuitTheme.sage).opacity(0.5))
                .cornerRadius(12)
        }
    }
}

struct MedicalBoundaryNotice: View {
    var title = "TeoPateo is quit support, not medical care."
    var detail = "For medication, nicotine replacement, withdrawal symptoms, pregnancy, chest pain, severe mood changes, or treatment questions, talk with a doctor, pharmacist, or quitline counselor."

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "cross.case.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(QuitTheme.cocoa)
                .frame(width: 34, height: 34)
                .background(QuitTheme.peach.opacity(0.62))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.key(title))
                    .font(.rounded(.subheadline, weight: .bold))
                    .foregroundColor(QuitTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.key(detail))
                    .font(.rounded(.caption))
                    .foregroundColor(QuitTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .quietCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("medical-boundary-notice")
    }
}

struct SafetyResourcesView: View {
    var title = "Crisis and quitline support"
    var detail = "These options work without the AI coach."

    private let resources = SafetyResource.all

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.key(title))
                    .font(.rounded(.headline, weight: .bold))
                    .foregroundColor(QuitTheme.ink)
                Text(L10n.key(detail))
                    .font(.rounded(.caption))
                    .foregroundColor(QuitTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                ForEach(resources) { resource in
                    resourceLink(resource)
                }
            }
        }
        .quietCard()
        .accessibilityIdentifier("safety-resources-card")
    }

    private func resourceLink(_ resource: SafetyResource) -> some View {
        Link(destination: resource.url) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: resource.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                    .frame(width: 30, height: 30)
                    .background(QuitTheme.peach.opacity(0.54))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.key(resource.title))
                        .font(.rounded(.subheadline, weight: .bold))
                        .foregroundColor(QuitTheme.ink)
                    Text(L10n.key(resource.detail))
                        .font(.rounded(.caption))
                        .foregroundColor(QuitTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(QuitTheme.faint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
        .accessibilityIdentifier(resource.accessibilityIdentifier)
    }
}

private struct SafetyResource: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let url: URL

    var accessibilityIdentifier: String {
        "safety-resource-\(id)"
    }

    static let all = [
        SafetyResource(
            id: "988",
            title: "Call 988",
            detail: "Crisis support if you might hurt yourself or cannot stay safe.",
            icon: "phone.fill",
            url: URL(string: "tel:988")!
        ),
        SafetyResource(
            id: "911",
            title: "Call 911",
            detail: "Immediate emergency help in the United States.",
            icon: "exclamationmark.triangle.fill",
            url: URL(string: "tel:911")!
        ),
        SafetyResource(
            id: "quitline",
            title: "Call 1-800-QUIT-NOW",
            detail: "Free quit-smoking support from a quitline counselor.",
            icon: "person.line.dotted.person.fill",
            url: URL(string: "tel:18007848669")!
        )
    ]
}

struct PrivacyAndDataView: View {
    @EnvironmentObject private var store: TeoPateoStore
    @State private var isPolicyPresented = false
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Privacy & Data")
                .font(.rounded(.headline, weight: .bold))
                .foregroundColor(QuitTheme.ink)

            dataFlowSummary

            Toggle(
                "AI coach data sharing",
                isOn: Binding(
                    get: { store.canSendCoachDataOffDevice },
                    set: { isEnabled in
                        if isEnabled {
                            store.grantCoachDataConsent()
                        } else {
                            store.revokeCoachDataConsent()
                        }
                    }
                )
            )
            .font(.rounded(.subheadline, weight: .bold))
            .tint(QuitTheme.cocoa)
            .accessibilityIdentifier("privacy-coach-consent-toggle")

            HStack(spacing: 10) {
                Button {
                    isPolicyPresented = true
                } label: {
                    Label("View policy", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityIdentifier("privacy-policy-button")

                Link(destination: PrivacyPolicyCopy.onlineURL) {
                    Image(systemName: "safari")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(QuitTheme.cocoa)
                        .frame(width: 52, height: 52)
                        .background(QuitTheme.peach.opacity(0.55))
                        .cornerRadius(14)
                }
                .accessibilityLabel("Open online privacy policy")
            }

            Button {
                isDeleteConfirmationPresented = true
            } label: {
                Label("Delete local data", systemImage: "trash")
                    .font(.rounded(.headline, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(QuitTheme.background)
                    .cornerRadius(14)
            }
            .accessibilityIdentifier("privacy-delete-local-data-button")
        }
        .quietCard()
        .sheet(isPresented: $isPolicyPresented) {
            PrivacyPolicySheet()
        }
        .alert("Delete local data?", isPresented: $isDeleteConfirmationPresented) {
            Button("Delete", role: .destructive) {
                store.deleteAllLocalData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your quit plan, onboarding profile, check-ins, cravings, slips, coach chats, reasons, activities, risky situations, notification settings, and coach sharing consent from this device.")
        }
    }

    private var dataFlowSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            privacyRow(
                title: "Stored on this device",
                detail: "Quit plan, profile, check-ins, cravings, slips, reasons, activities, risky situations, coach chats, and notification settings."
            )
            privacyRow(
                title: "Shared only for coach replies",
                detail: "When coach sharing is on, TeoPateo sends your message plus limited quit context through the coach proxy to an AI provider."
            )
            privacyRow(
                title: "Not used for tracking",
                detail: "TeoPateo does not sell data or use coach data for ads."
            )
        }
    }

    private func privacyRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.faint)
                .textCase(.uppercase)
            Text(detail)
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            QuitTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Privacy Policy")
                                .font(.rounded(.title2, weight: .bold))
                                .foregroundColor(QuitTheme.ink)
                            Text("Effective \(PrivacyPolicyCopy.effectiveDate)")
                                .font(.rounded(.subheadline))
                                .foregroundColor(QuitTheme.muted)
                        }

                        Spacer()

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
                        .accessibilityLabel("Close privacy policy")
                    }

                    ForEach(PrivacyPolicyCopy.sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.rounded(.headline, weight: .bold))
                                .foregroundColor(QuitTheme.ink)
                            Text(section.body)
                                .font(.rounded(.subheadline))
                                .foregroundColor(QuitTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .quietCard()
                    }
                }
                .padding(24)
            }
        }
    }
}

private enum PrivacyPolicyCopy {
    static let effectiveDate = "June 6, 2026"
    static let onlineURL = URL(string: "https://teopateo.app/privacy")!

    static let sections = [
        PrivacyPolicySection(
            title: "What TeoPateo Stores Locally",
            body: "TeoPateo stores your quit plan, onboarding profile, smoking background, check-ins, cravings, slips, triggers, reasons, replacement activities, risky situations, coach chats, and notification settings on this device."
        ),
        PrivacyPolicySection(
            title: "What Leaves This Device",
            body: "Most app data stays local. If you turn on AI coach sharing and send a coach message, TeoPateo sends your message and a limited quit-plan context to the TeoPateo coach proxy. That context may include smoking history, check-ins, cravings, slips, triggers, reasons, and replacement activities."
        ),
        PrivacyPolicySection(
            title: "AI Provider",
            body: "The coach proxy forwards the request to an AI provider, currently OpenRouter, to generate a reply. The proxy trims quit-plan context to 6,000 characters before forwarding it and does not maintain a long-term user account."
        ),
        PrivacyPolicySection(
            title: "Retention",
            body: "Your local data remains on this device until you delete it or remove the app. Coach requests are used to return a reply. Production provider configuration should prefer no retention and no training on your data."
        ),
        PrivacyPolicySection(
            title: "Deletion and Export",
            body: "You can delete local TeoPateo data from Privacy & Data in the app. You can request an export of data TeoPateo controls through the online privacy policy contact path."
        ),
        PrivacyPolicySection(
            title: "Under 18",
            body: "If your profile age is under 18, TeoPateo asks you to use extra care with the AI coach and avoid sharing full names, contact details, or information you would not want a trusted adult to help you review."
        ),
        PrivacyPolicySection(
            title: "Tracking",
            body: "TeoPateo does not sell your data and does not use health-related coach data for advertising or cross-app tracking."
        )
    ]
}

private struct PrivacyPolicySection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

struct MotivationVaultView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TeoPateoStore

    @State private var newReason = ""
    @State private var editingReasonID: UUID?
    @State private var editReason = ""

    var body: some View {
        ZStack {
            QuitTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    StatusBanner(status: store.lastSaveStatus, persistenceError: store.persistenceError)
                    primaryPreview
                    reasonList
                    addReason
                }
                .padding(24)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            ScreenHeader(
                eyebrow: "Motivation vault",
                title: "Keep the reason you want in a craving."
            )
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
            .accessibilityLabel("Close motivation vault")
        }
    }

    private var primaryPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shown in craving mode")
                .font(.rounded(.headline, weight: .bold))
            Text(store.reasonForCravingMode())
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .quietCard()
    }

    private var reasonList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved reasons")
                .font(.rounded(.headline, weight: .bold))

            if store.userReasons.isEmpty {
                Text("Add one short, specific reason. It will appear when a craving starts.")
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
            } else {
                ForEach(store.userReasons) { reason in
                    reasonRow(reason, index: index(of: reason.id))
                }
            }
        }
        .quietCard()
    }

    @ViewBuilder
    private func reasonRow(_ reason: UserReason, index: Int) -> some View {
        if editingReasonID == reason.id {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Reason", text: $editReason)
                    .textFieldStyle(QuietFieldStyle())
                HStack(spacing: 10) {
                    Button("Save reason") {
                        store.updateUserReason(reason.id, text: editReason)
                        editingReasonID = nil
                    }
                    .buttonStyle(QuietButtonStyle())
                    Button("Cancel") {
                        editingReasonID = nil
                    }
                    .font(.rounded(.caption, weight: .bold))
                    .foregroundColor(QuitTheme.muted)
                }
            }
            .padding(.vertical, 4)
        } else {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reason.text)
                        .font(.rounded(.subheadline, weight: .bold))
                        .foregroundColor(QuitTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(reason.isPrimary ? "Primary reason" : "Saved reason")
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundColor(QuitTheme.muted)
                }
                Spacer()
                if !reason.isPrimary {
                    Button("Use") {
                        store.setPrimaryUserReason(reason.id)
                    }
                    .font(.rounded(.caption, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                }
                priorityButtons(
                    index: index,
                    count: store.userReasons.count,
                    moveUp: { store.moveUserReason(reason.id, direction: -1) },
                    moveDown: { store.moveUserReason(reason.id, direction: 1) }
                )
                iconButton(systemName: "pencil", title: "Edit reason") {
                    editingReasonID = reason.id
                    editReason = reason.text
                }
                iconButton(systemName: "trash", title: "Remove reason") {
                    store.deleteUserReason(reason.id)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var addReason: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add reason")
                .font(.rounded(.headline, weight: .bold))
            TextField("Example: I want mornings without chest tightness.", text: $newReason)
                .textFieldStyle(QuietFieldStyle())
            Button("Add to vault") {
                store.addUserReason(newReason, isPrimary: store.userReasons.isEmpty)
                newReason = ""
            }
            .buttonStyle(FilledButtonStyle())
        }
        .quietCard()
    }

    private func priorityButtons(
        index: Int,
        count: Int,
        moveUp: @escaping () -> Void,
        moveDown: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 4) {
            iconButton(systemName: "chevron.up", title: "Move reason up", action: moveUp)
                .disabled(index <= 0)
                .opacity(index <= 0 ? 0.38 : 1)
            iconButton(systemName: "chevron.down", title: "Move reason down", action: moveDown)
                .disabled(index >= count - 1)
                .opacity(index >= count - 1 ? 0.38 : 1)
        }
    }

    private func iconButton(
        systemName: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(QuitTheme.cocoa)
                .frame(width: 31, height: 31)
                .background(QuitTheme.peach.opacity(0.55))
                .clipShape(Circle())
        }
        .accessibilityLabel(title)
    }

    private func index(of id: UUID) -> Int {
        store.userReasons.firstIndex { $0.id == id } ?? 0
    }
}
