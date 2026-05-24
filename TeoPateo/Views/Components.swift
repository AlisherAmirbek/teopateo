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
