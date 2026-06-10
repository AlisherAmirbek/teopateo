import SwiftUI
import UIKit

enum QuitTheme {
    static let background = adaptive(light: (0.969, 0.957, 0.929), dark: (0.071, 0.082, 0.075))
    static let paper = adaptive(light: (1.0, 0.996, 0.976), dark: (0.125, 0.137, 0.125))
    static let ink = adaptive(light: (0.239, 0.165, 0.122), dark: (0.965, 0.948, 0.902))
    static let muted = adaptive(light: (0.486, 0.400, 0.337), dark: (0.769, 0.722, 0.647))
    static let faint = adaptive(light: (0.620, 0.573, 0.522), dark: (0.604, 0.557, 0.506))
    static let cocoa = adaptive(light: (0.247, 0.157, 0.106), dark: (0.890, 0.582, 0.341))
    static let onCocoa = adaptive(light: (1.0, 1.0, 1.0), dark: (0.071, 0.082, 0.075))
    static let peach = adaptive(light: (0.973, 0.843, 0.667), dark: (0.298, 0.216, 0.157))
    static let sage = adaptive(light: (0.698, 0.769, 0.643), dark: (0.376, 0.529, 0.318))
    static let onSage = adaptive(light: (0.239, 0.165, 0.122), dark: (1.0, 1.0, 1.0))
    static let danger = adaptive(light: (0.690, 0.259, 0.184), dark: (0.842, 0.385, 0.306))
    static let line = adaptive(light: (0.357, 0.231, 0.161), dark: (0.965, 0.948, 0.902)).opacity(0.16)

    private static func adaptive(light: RGB, dark: RGB) -> Color {
        Color(UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat(value.red),
                green: CGFloat(value.green),
                blue: CGFloat(value.blue),
                alpha: 1
            )
        })
    }
}

private typealias RGB = (red: Double, green: Double, blue: Double)

enum L10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func key(_ value: String) -> LocalizedStringKey {
        LocalizedStringKey(value)
    }

    static func selectedState(_ isSelected: Bool) -> String {
        string(isSelected ? "Selected" : "Not selected")
    }

    static func scoreValue(_ value: Int, maximum: Int = 10) -> String {
        String(format: string("%d out of %d"), value, maximum)
    }
}

extension Font {
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }
}

// MARK: - Spacing scale (8pt system)
//
// Big gaps between sections (lg / xl), tight gaps within a group (xs / sm / smd).
// Replaces ad-hoc magic numbers so every screen breathes on the same rhythm.

enum Spacing {
    /// 4 — hairline gap inside a tight pair.
    static let xs: CGFloat = 4
    /// 8 — within a group (title ↔ body).
    static let sm: CGFloat = 8
    /// 12 — comfortable within-group gap.
    static let smd: CGFloat = 12
    /// 16 — default block / card padding.
    static let md: CGFloat = 16
    /// 24 — between distinct sections.
    static let lg: CGFloat = 24
    /// 32 — major separation / hero breathing room.
    static let xl: CGFloat = 32
}

// MARK: - Type scale (four roles)
//
// Hierarchy comes from type, weight, and colour — not borders or extra accents.
// Four roles with deliberate jumps: Display (one per screen) ≫ Section ≫ Body ≫ Label.
// Body defaults to `ink` (not `muted`) for contrast; `muted` is reserved for
// genuinely secondary copy via `typeBodySecondary`.

extension View {
    /// One hero title per screen. Heavy, ink. ~34.
    func typeDisplay() -> some View {
        self
            .font(.system(.largeTitle, design: .rounded).weight(.heavy))
            .foregroundColor(QuitTheme.ink)
            .lineSpacing(2)
    }

    /// Section / card titles. Clearly larger than body. ~20 bold.
    func typeSection() -> some View {
        self
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundColor(QuitTheme.ink)
    }

    /// Primary body copy. Regular weight, ink. ~16.
    func typeBody() -> some View {
        self
            .font(.system(.callout, design: .rounded))
            .foregroundColor(QuitTheme.ink)
            .lineSpacing(3)
    }

    /// Secondary / supporting copy. Muted, reserved for genuinely secondary text. ~16.
    func typeBodySecondary() -> some View {
        self
            .font(.system(.callout, design: .rounded))
            .foregroundColor(QuitTheme.muted)
            .lineSpacing(3)
    }

    /// Eyebrows, captions, metadata. Faint, small, semibold. ~13.
    func typeLabel() -> some View {
        self
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .foregroundColor(QuitTheme.faint)
    }
}

// MARK: - Surfaces (single canonical card)
//
// One committed surface: a `paper` fill, a `line` hairline, and a continuous
// corner. No shadows or elevation — the hairline is what makes a card read as a
// deliberate surface instead of a near-invisible "half-card".

extension View {
    func quietCard(cornerRadius: CGFloat = 18, padding: CGFloat = Spacing.md) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(QuitSurface(cornerRadius: cornerRadius))
    }
}

struct QuitSurface: View {
    var cornerRadius: CGFloat = 18

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(QuitTheme.paper)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(QuitTheme.line, lineWidth: 1)
            )
    }
}

// MARK: - Themed text inputs
//
// One field/editor treatment so stock `.roundedBorder` controls never break the
// aesthetic. A recessed `background` fill with the same hairline as cards.

struct QuietFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.rounded(.body))
            .foregroundColor(QuitTheme.ink)
            .tint(QuitTheme.cocoa)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(QuitFieldSurface())
    }
}

struct QuitFieldSurface: View {
    var cornerRadius: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(QuitTheme.background)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(QuitTheme.line, lineWidth: 1)
            )
    }
}

extension View {
    /// Themed container for `TextEditor` so it matches `QuietFieldStyle`.
    func quietEditor(minHeight: CGFloat = 96) -> some View {
        self
            .font(.rounded(.body))
            .foregroundColor(QuitTheme.ink)
            .tint(QuitTheme.cocoa)
            .scrollContentBackgroundHiddenIfAvailable()
            .frame(minHeight: minHeight)
            .padding(10)
            .background(QuitFieldSurface())
    }

    @ViewBuilder
    func scrollContentBackgroundHiddenIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

// MARK: - Haptics
//
// Quiet feedback, not loud celebration. Subtle, earned acknowledgements at the
// moments that carry emotional weight: rescue start, outcome, save, selection.

enum Haptics {
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Mascot poses
//
// Teo is one expressive asset used with restraint. These poses (in
// `images/additional`, mirrored into the asset catalog) let the mascot react to
// progress, wins, and time of day instead of being static furniture.

enum MascotPose: String, CaseIterable {
    case waiting = "TeoWaiting"
    case playful = "TeoPlayful"
    case playing = "TeoPlaying"
    case walking = "TeoWalking"
    case laying = "TeoLaying"
    case sleeping = "TeoSleeping"
    case standing = "TeoStanding"

    var assetName: String { rawValue }

    /// A calm description for VoiceOver — the mascot is decoration, but when it
    /// reacts to progress the mood is worth announcing.
    var accessibilityMood: String {
        switch self {
        case .waiting: return "Teo is waiting calmly with you."
        case .playful: return "Teo is celebrating with you."
        case .playing: return "Teo is playing, proud of your streak."
        case .walking: return "Teo is walking alongside you."
        case .laying: return "Teo is resting."
        case .sleeping: return "Teo is asleep. Good night."
        case .standing: return "Teo is here with you."
        }
    }
}

extension Image {
    init(pose: MascotPose) {
        self.init(pose.assetName)
    }
}
