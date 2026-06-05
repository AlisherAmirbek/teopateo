import AVFoundation
import SwiftUI

struct FlexibleTags: View {
    let items: [String]
    @Binding var selected: Set<String>

    private let columns = [
        GridItem(.adaptive(minimum: 104), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isSelected = selected.contains(item)
                Button {
                    if isSelected {
                        selected.remove(item)
                    } else {
                        selected.insert(item)
                    }
                } label: {
                    Text(item)
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundColor(isSelected ? .white : QuitTheme.cocoa)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? QuitTheme.cocoa : QuitTheme.peach.opacity(0.62))
                        .cornerRadius(18)
                }
                .accessibilityLabel(item)
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
                .accessibilityHint(isSelected ? "Double-tap to deselect." : "Double-tap to select.")
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
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.muted)
            Text(title)
                .font(.system(size: 31, weight: .heavy, design: .rounded))
                .foregroundColor(QuitTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 10)
    }
}

struct AnimatedMascotView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let size: CGFloat

    var body: some View {
        Group {
            if reduceMotion {
                staticMascot
            } else if let url = Bundle.main.url(forResource: "basic_animation", withExtension: "mov") {
                TimedMascotVideoView(url: url, replayInterval: 60)
            } else {
                staticMascot
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var staticMascot: some View {
        Image("Mascot")
            .resizable()
            .scaledToFit()
            .opacity(0.98)
    }
}

private struct TimedMascotVideoView: UIViewRepresentable {
    let url: URL
    let replayInterval: TimeInterval

    func makeUIView(context: Context) -> TimedVideoPlayerUIView {
        let view = TimedVideoPlayerUIView()
        view.configure(url: url, replayInterval: replayInterval)
        return view
    }

    func updateUIView(_ uiView: TimedVideoPlayerUIView, context: Context) {
        uiView.configure(url: url, replayInterval: replayInterval)
    }

    static func dismantleUIView(_ uiView: TimedVideoPlayerUIView, coordinator: ()) {
        uiView.stop()
    }
}

private final class TimedVideoPlayerUIView: UIView {
    private var currentURL: URL?
    private var player: AVPlayer?
    private var replayInterval: TimeInterval = 60
    private var endObserver: NSObjectProtocol?
    private var replayWorkItem: DispatchWorkItem?
    private var playbackStartedAt: Date?
    private var hasStartedPlayback = false
    private var didFinishPlayback = false

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

    func configure(url: URL, replayInterval: TimeInterval) {
        self.replayInterval = replayInterval

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
            self?.freezeAndScheduleReplay()
        }

        playerLayer.player = player
        self.player = player

        if window != nil {
            playFromBeginning()
        }
    }

    func stop() {
        replayWorkItem?.cancel()
        replayWorkItem = nil

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        player?.pause()
        playerLayer.player = nil
        player = nil
        currentURL = nil
        playbackStartedAt = nil
        hasStartedPlayback = false
        didFinishPlayback = false
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            player?.pause()
            replayWorkItem?.cancel()
            replayWorkItem = nil
        } else if hasStartedPlayback && !didFinishPlayback {
            player?.play()
        } else {
            playFromBeginning()
        }
    }

    private func playFromBeginning() {
        guard let player, window != nil else { return }

        replayWorkItem?.cancel()
        replayWorkItem = nil
        playbackStartedAt = Date()
        hasStartedPlayback = true
        didFinishPlayback = false

        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak player] _ in
            player?.play()
        }
    }

    private func freezeAndScheduleReplay() {
        didFinishPlayback = true
        player?.pause()
        freezeOnLastFrame()

        let elapsed = playbackStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        scheduleReplay(after: max(0, replayInterval - elapsed))
    }

    private func freezeOnLastFrame() {
        guard let player, let duration = player.currentItem?.duration, duration.isNumeric else {
            return
        }

        let finalFrameOffset = CMTime(value: 1, timescale: 30)
        let targetTime = CMTimeCompare(duration, finalFrameOffset) > 0 ? duration - finalFrameOffset : .zero
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: finalFrameOffset)
    }

    private func scheduleReplay(after delay: TimeInterval) {
        replayWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.playFromBeginning()
        }
        replayWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}

struct RootScreen<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            QuitTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    content
                }
                .padding(24)
            }
        }
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
                    .textFieldStyle(.roundedBorder)
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
                .textFieldStyle(.roundedBorder)
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
