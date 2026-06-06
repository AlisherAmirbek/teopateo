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

extension View {
    func quietCard() -> some View {
        self
            .padding(16)
            .background(QuitTheme.paper)
            .cornerRadius(18)
    }
}
