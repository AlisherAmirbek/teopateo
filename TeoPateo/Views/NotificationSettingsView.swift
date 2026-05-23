import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var store: TeoPateoStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            RootScreen {
                ScreenHeader(
                    eyebrow: "Notifications",
                    title: "Choose the moments worth interrupting."
                )
                StatusBanner(status: store.lastSaveStatus, persistenceError: store.persistenceError)
                permissionCard

                ForEach(NotificationKind.userVisibleCases, id: \.self) { kind in
                    reminderCard(kind)
                }

                schedulePreview
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(QuitTheme.cocoa)
                }
            }
        }
        .onAppear {
            store.refreshNotificationAuthorization()
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: store.notificationPermissionStatus.canScheduleNotifications ? "bell.badge.fill" : "bell.slash")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                    .frame(width: 34, height: 34)
                    .background(QuitTheme.peach.opacity(0.74))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.notificationPermissionStatus.title)
                        .font(.rounded(.headline, weight: .bold))
                    Text(permissionMessage)
                        .font(.rounded(.caption))
                        .foregroundColor(QuitTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !store.notificationPermissionStatus.canScheduleNotifications &&
                store.notificationPermissionStatus != .denied {
                Button("Allow notifications") {
                    store.requestNotificationAuthorization()
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
        .quietCard()
    }

    private func reminderCard(_ kind: NotificationKind) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(
                isOn: Binding(
                    get: { store.notificationSettings.isEnabled(kind) },
                    set: { store.setNotificationEnabled(kind, isEnabled: $0) }
                )
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(kind.title)
                        .font(.rounded(.headline, weight: .bold))
                    Text(kind.detail)
                        .font(.rounded(.caption))
                        .foregroundColor(QuitTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: QuitTheme.cocoa))

            if kind.supportsFixedTime, let time = store.notificationSettings.time(for: kind) {
                DatePicker(
                    "Time",
                    selection: timeBinding(for: kind, fallback: time),
                    displayedComponents: .hourAndMinute
                )
                .font(.rounded(.subheadline))
                .disabled(!store.notificationSettings.isEnabled(kind))
                .opacity(store.notificationSettings.isEnabled(kind) ? 1 : 0.55)
            }

            if kind == .riskyWindow {
                riskyWindowPreview
            }
        }
        .quietCard()
    }

    private var riskyWindowPreview: some View {
        let windows = store.calculatedInsights.riskWindows

        return VStack(alignment: .leading, spacing: 8) {
            Divider()
            if windows.isEmpty {
                Text("Risk-window reminders start after you log a few cravings with timestamps.")
                    .font(.rounded(.caption))
                    .foregroundColor(QuitTheme.muted)
            } else {
                ForEach(windows.prefix(3)) { window in
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(QuitTheme.faint)
                        Text("Warn 30 minutes before \(window.startLabel)")
                            .font(.rounded(.caption, weight: .bold))
                        Spacer()
                        Text(window.shareSummary)
                            .font(.rounded(.caption, weight: .bold))
                            .foregroundColor(QuitTheme.muted)
                    }
                }
            }
        }
    }

    private var schedulePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scheduled")
                .font(.rounded(.headline, weight: .bold))

            if store.plannedNotificationItems.isEmpty {
                Text(emptyScheduleMessage)
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(store.plannedNotificationItems, id: \.identifier) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Text(item.time.displayLabel)
                            .font(.rounded(.caption, weight: .bold))
                            .foregroundColor(QuitTheme.cocoa)
                            .frame(width: 76, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.rounded(.caption, weight: .bold))
                            Text(item.body)
                                .font(.rounded(.caption))
                                .foregroundColor(QuitTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .quietCard()
    }

    private var permissionMessage: String {
        switch store.notificationPermissionStatus {
        case .unknown:
            return "TeoPateo is checking whether iOS allows local reminders."
        case .notDetermined:
            return "Reminders are opt-in. iOS will ask before anything is scheduled."
        case .denied:
            return "iOS is blocking reminders for TeoPateo. Change this in Settings to schedule them."
        case .authorized, .provisional, .ephemeral:
            return "Enabled reminders will be scheduled locally on this device."
        }
    }

    private var emptyScheduleMessage: String {
        if store.notificationSettings.riskyWindowEnabled &&
            !store.notificationSettings.hasEnabledRemindersExcludingRiskWindow {
            return "Risk-window reminders are enabled, but TeoPateo needs more craving history before scheduling one."
        }
        return "Turn on a reminder above to build the local schedule."
    }

    private func timeBinding(
        for kind: NotificationKind,
        fallback: ReminderTime
    ) -> Binding<Date> {
        Binding(
            get: {
                date(for: store.notificationSettings.time(for: kind) ?? fallback)
            },
            set: { date in
                store.updateNotificationTime(kind, time: reminderTime(from: date))
            }
        )
    }

    private func date(for time: ReminderTime) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return calendar.date(
            byAdding: .minute,
            value: time.minuteOfDay,
            to: startOfDay
        ) ?? Date()
    }

    private func reminderTime(from date: Date) -> ReminderTime {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ReminderTime(
            hour: components.hour ?? 0,
            minute: components.minute ?? 0
        )
    }
}

private extension NotificationSettings {
    var hasEnabledRemindersExcludingRiskWindow: Bool {
        morningPlanEnabled ||
            postMealEnabled ||
            eveningCheckInEnabled
    }
}
