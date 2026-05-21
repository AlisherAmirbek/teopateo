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
                Button {
                    if selected.contains(item) {
                        selected.remove(item)
                    } else {
                        selected.insert(item)
                    }
                } label: {
                    Text(item)
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundColor(selected.contains(item) ? .white : QuitTheme.cocoa)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected.contains(item) ? QuitTheme.cocoa : QuitTheme.peach.opacity(0.62))
                        .cornerRadius(18)
                }
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
