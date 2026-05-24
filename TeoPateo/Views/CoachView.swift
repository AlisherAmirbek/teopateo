import Foundation
import SwiftUI

struct CoachView: View {
    @EnvironmentObject private var store: TeoPateoStore
    @State private var input = ""
    @State private var chatPendingDeletion: CoachChat?

    private let promptColumns = [
        GridItem(.adaptive(minimum: 140), spacing: 8)
    ]
    private let promptOptions = [
        CoachPromptOption(
            title: "I want to smoke now",
            message: "I want to smoke now. Help me get through the next 10 minutes."
        ),
        CoachPromptOption(
            title: "I already smoked",
            message: "I smoked and want help getting back on track without spiraling."
        ),
        CoachPromptOption(
            title: "Plan a risky moment",
            message: "Help me plan for a risky smoking moment."
        )
    ]

    var body: some View {
        RootScreen {
            header
            chatSwitcher
            messages
            responseStatus
            if shouldShowPromptStarters {
                prompts
            }
            inputRow
        }
        .alert(item: $chatPendingDeletion) { chat in
            Alert(
                title: Text("Delete chat?"),
                message: Text("This removes this coach conversation."),
                primaryButton: .destructive(Text("Delete")) {
                    input = ""
                    store.deleteCoachChat(chat.id)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ScreenHeader(eyebrow: "AI coach", title: "Get help before you smoke.")

            HStack(spacing: 8) {
                Button {
                    input = ""
                    store.startNewCoachChat()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(store.canStartNewCoachChat ? QuitTheme.cocoa : QuitTheme.faint)
                        .clipShape(Circle())
                }
                .disabled(!store.canStartNewCoachChat)
                .accessibilityLabel("Start new coach chat")
                .accessibilityIdentifier("coach-new-chat-button")

                Button {
                    chatPendingDeletion = store.selectedCoachChat
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(store.canDeleteSelectedCoachChat ? QuitTheme.cocoa : QuitTheme.faint)
                        .frame(width: 44, height: 44)
                        .background(QuitTheme.peach.opacity(0.7))
                        .clipShape(Circle())
                }
                .disabled(!store.canDeleteSelectedCoachChat)
                .accessibilityLabel("Delete coach chat")
                .accessibilityIdentifier("coach-delete-chat-button")
            }
        }
    }

    private var chatSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.coachChats) { chat in
                    chatButton(chat)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var messages: some View {
        VStack(spacing: 10) {
            if store.coachMessages.isEmpty {
                emptyChat
            }

            ForEach(store.coachMessages) { message in
                if !message.text.isEmpty {
                    CoachMessageBubble(message: message)
                }
            }

            if store.isCoachResponding {
                HStack {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(QuitTheme.cocoa)
                        Text("Preparing a response...")
                            .font(.rounded(.subheadline))
                            .foregroundColor(QuitTheme.muted)
                    }
                    .padding(12)
                    .background(QuitTheme.paper)
                    .cornerRadius(14)
                    Spacer(minLength: 48)
                }
            }
        }
    }

    private var emptyChat: some View {
        Text("What is making you want to smoke?")
            .font(.rounded(.subheadline, weight: .bold))
            .foregroundColor(QuitTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(QuitTheme.paper)
            .cornerRadius(14)
    }

    @ViewBuilder
    private var responseStatus: some View {
        if let message = store.coachResponseState.message {
            Text(message)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.cocoa)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(QuitTheme.peach.opacity(0.55))
                .cornerRadius(12)
        }
    }

    private var prompts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Common situations")
                .font(.rounded(.headline, weight: .bold))
            LazyVGrid(columns: promptColumns, alignment: .leading, spacing: 8) {
                ForEach(promptOptions) { option in
                    promptButton(option)
                }
            }
        }
        .quietCard()
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            TextField("Describe the craving or trigger...", text: $input)
                .font(.rounded(.subheadline))
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(QuitTheme.paper)
                .cornerRadius(14)
                .submitLabel(.send)
                .onSubmit(sendCurrentInput)
                .accessibilityIdentifier("coach-input-field")

            Button(action: sendCurrentInput) {
                Image(systemName: "paperplane")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(canSendInput ? QuitTheme.cocoa : QuitTheme.faint)
                    .cornerRadius(14)
            }
            .disabled(!canSendInput)
            .accessibilityLabel("Send message")
            .accessibilityIdentifier("coach-send-button")
        }
    }

    private func promptButton(_ option: CoachPromptOption) -> some View {
        Button {
            Task {
                await store.sendCoachMessage(option.message)
            }
        } label: {
            Text(option.title)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .font(.rounded(.caption, weight: .bold))
        .foregroundColor(QuitTheme.cocoa)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(QuitTheme.peach.opacity(0.7))
        .cornerRadius(18)
        .disabled(store.isCoachResponding)
        .opacity(store.isCoachResponding ? 0.55 : 1)
        .accessibilityIdentifier("coach-prompt-\(option.title)")
    }

    private func chatButton(_ chat: CoachChat) -> some View {
        let isSelected = store.selectedCoachChatID == chat.id

        return Button {
            input = ""
            store.selectCoachChat(chat.id)
        } label: {
            Text(chat.displayTitle)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(isSelected ? .white : QuitTheme.cocoa)
                .lineLimit(1)
                .padding(.vertical, 9)
                .padding(.horizontal, 12)
                .background(isSelected ? QuitTheme.cocoa : QuitTheme.peach.opacity(0.7))
                .cornerRadius(18)
        }
        .accessibilityLabel(chat.displayTitle)
        .accessibilityIdentifier("coach-chat-\(chat.id.uuidString)")
    }

    private var canSendInput: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !store.isCoachResponding
    }

    private var shouldShowPromptStarters: Bool {
        !store.coachMessages.contains { $0.isUser }
    }

    private func sendCurrentInput() {
        let message = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !store.isCoachResponding else { return }
        input = ""
        Task {
            await store.sendCoachMessage(message)
        }
    }
}

private struct CoachPromptOption: Identifiable {
    let title: String
    let message: String

    var id: String { title }
}

private struct CoachMessageBubble: View {
    let message: CoachMessage

    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 48)
            }

            CoachMessageContent(message: message)
                .lineSpacing(3)
                .padding(12)
                .background(message.isUser ? QuitTheme.cocoa : QuitTheme.paper)
                .cornerRadius(14)
                .fixedSize(horizontal: false, vertical: true)

            if !message.isUser {
                Spacer(minLength: 48)
            }
        }
    }
}

private struct CoachMessageContent: View {
    let message: CoachMessage

    var body: some View {
        if message.isUser {
            Text(message.text)
                .font(.rounded(.subheadline))
                .foregroundColor(.white)
        } else {
            CoachMarkdownText(text: message.text)
                .foregroundColor(QuitTheme.ink)
        }
    }
}

private struct CoachMarkdownText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(blocks) { block in
                blockView(block)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case .paragraph:
            Text(inlineMarkdown(block.text))
                .font(.rounded(.subheadline))
        case .heading:
            Text(inlineMarkdown(block.text))
                .font(.rounded(.subheadline, weight: .bold))
        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("-")
                    .font(.rounded(.subheadline, weight: .bold))
                Text(inlineMarkdown(block.text))
                    .font(.rounded(.subheadline))
            }
        case .numbered:
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("\(block.marker ?? 1).")
                    .font(.rounded(.subheadline, weight: .bold))
                Text(inlineMarkdown(block.text))
                    .font(.rounded(.subheadline))
            }
        }
    }

    private var blocks: [MarkdownBlock] {
        var parsed: [MarkdownBlock] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            parsed.append(MarkdownBlock(
                id: parsed.count,
                kind: .paragraph,
                marker: nil,
                text: paragraphLines.joined(separator: " ")
            ))
            paragraphLines = []
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushParagraph()
            } else if let headingText = headingText(in: line) {
                flushParagraph()
                parsed.append(MarkdownBlock(
                    id: parsed.count,
                    kind: .heading,
                    marker: nil,
                    text: headingText
                ))
            } else if let bulletText = bulletText(in: line) {
                flushParagraph()
                parsed.append(MarkdownBlock(
                    id: parsed.count,
                    kind: .bullet,
                    marker: nil,
                    text: bulletText
                ))
            } else if let numberedItem = numberedItem(in: line) {
                flushParagraph()
                parsed.append(MarkdownBlock(
                    id: parsed.count,
                    kind: .numbered,
                    marker: numberedItem.number,
                    text: numberedItem.text
                ))
            } else {
                paragraphLines.append(line)
            }
        }

        flushParagraph()
        return parsed.isEmpty
            ? [MarkdownBlock(id: 0, kind: .paragraph, marker: nil, text: text)]
            : parsed
    }

    private func inlineMarkdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: text, options: options))
            ?? AttributedString(text)
    }

    private func headingText(in line: String) -> String? {
        let markerCount = line.prefix(while: { $0 == "#" }).count
        guard (1...3).contains(markerCount) else { return nil }

        let textStart = line.index(line.startIndex, offsetBy: markerCount)
        guard textStart < line.endIndex, line[textStart] == " " else { return nil }

        return String(line[line.index(after: textStart)...])
    }

    private func bulletText(in line: String) -> String? {
        guard line.hasPrefix("- ") || line.hasPrefix("* ") else { return nil }
        return String(line.dropFirst(2))
    }

    private func numberedItem(in line: String) -> (number: Int, text: String)? {
        guard let dotIndex = line.firstIndex(of: ".") else { return nil }

        let numberText = String(line[..<dotIndex])
        guard let number = Int(numberText) else { return nil }

        let textStart = line.index(after: dotIndex)
        guard textStart < line.endIndex, line[textStart] == " " else { return nil }

        return (number, String(line[line.index(after: textStart)...]))
    }
}

private struct MarkdownBlock: Identifiable {
    enum Kind {
        case paragraph
        case heading
        case bullet
        case numbered
    }

    let id: Int
    let kind: Kind
    let marker: Int?
    let text: String
}
