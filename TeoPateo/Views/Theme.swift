import SwiftUI

enum QuitTheme {
    static let background = Color(red: 0.969, green: 0.957, blue: 0.929)
    static let paper = Color(red: 1.0, green: 0.996, blue: 0.976)
    static let ink = Color(red: 0.239, green: 0.165, blue: 0.122)
    static let muted = Color(red: 0.486, green: 0.400, blue: 0.337)
    static let faint = Color(red: 0.620, green: 0.573, blue: 0.522)
    static let cocoa = Color(red: 0.247, green: 0.157, blue: 0.106)
    static let peach = Color(red: 0.973, green: 0.843, blue: 0.667)
    static let sage = Color(red: 0.698, green: 0.769, blue: 0.643)
    static let line = Color(red: 0.357, green: 0.231, blue: 0.161).opacity(0.14)
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
