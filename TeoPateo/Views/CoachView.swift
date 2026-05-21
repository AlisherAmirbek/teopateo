import SwiftUI

struct CoachView: View {
    @EnvironmentObject private var store: TeoPateoStore
    @State private var input = ""

    var body: some View {
        RootScreen {
            ScreenHeader(eyebrow: "AI coach", title: "Ask for the next move.")

            messages
            prompts
            inputRow
        }
    }

    private var messages: some View {
        VStack(spacing: 10) {
            ForEach(store.coachMessages) { message in
                HStack {
                    if message.isUser {
                        Spacer(minLength: 48)
                    }
                    Text(message.text)
                        .font(.rounded(.subheadline))
                        .foregroundColor(message.isUser ? .white : QuitTheme.ink)
                        .padding(12)
                        .background(message.isUser ? QuitTheme.cocoa : QuitTheme.paper)
                        .cornerRadius(14)
                    if !message.isUser {
                        Spacer(minLength: 48)
                    }
                }
            }
        }
    }

    private var prompts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick prompts")
                .font(.rounded(.headline, weight: .bold))
            HStack {
                promptButton("After work")
                promptButton("Craving script")
                promptButton("Slip recovery")
            }
        }
        .quietCard()
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            TextField("Type what is happening...", text: $input)
                .font(.rounded(.subheadline))
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(QuitTheme.paper)
                .cornerRadius(14)

            Button {
                store.sendCoachMessage(input)
                input = ""
            } label: {
                Image(systemName: "paperplane")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(QuitTheme.cocoa)
                    .cornerRadius(14)
            }
            .accessibilityLabel("Send message")
        }
    }

    private func promptButton(_ title: String) -> some View {
        Button(title) {
            store.sendCoachMessage(title)
        }
        .font(.rounded(.caption, weight: .bold))
        .foregroundColor(QuitTheme.cocoa)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(QuitTheme.peach.opacity(0.7))
        .cornerRadius(18)
    }
}
