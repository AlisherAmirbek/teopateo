import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: TeoPateoStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @State private var isHistoryPresented = false

    private var insights: CalculatedInsights {
        store.calculatedInsights
    }

    var body: some View {
        if subscriptionStore.hasAccess(to: .personalizedInsights) {
            premiumInsights
        } else {
            PremiumFeaturePreview(
                feature: .personalizedInsights,
                eyebrow: "Pattern insights",
                title: "Your risk is predictable.",
                freeSupportMessage: "Keep your plan current and log how today went whenever you need to.",
                freeActions: [
                    FreeSupportAction(
                        id: "check-in",
                        title: "Log a check-in"
                    ) {
                        store.selectedTab = .checkIn
                    },
                    FreeSupportAction(
                        id: "plan",
                        title: "Review your plan"
                    ) {
                        store.selectedTab = .plan
                    }
                ]
            )
        }
    }

    private var premiumInsights: some View {
        RootScreen {
            ScreenHeader(eyebrow: "Pattern insights", title: "Your risk is predictable.")
            StatusBanner(status: store.lastSaveStatus, persistenceError: store.persistenceError)

            todayRisk
            progressSummary
            heatMap
            planAdjustment
            historyPreview
        }
        .sheet(isPresented: $isHistoryPresented) {
            HistoryTimelineView()
                .environmentObject(store)
        }
    }

    private var todayRisk: some View {
        let risk = insights.todayRisk
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's risk")
                    .font(.rounded(.headline, weight: .bold))
                Spacer()
                Text(risk.level.title)
                    .font(.rounded(.caption, weight: .bold))
                    .foregroundColor(risk.level == .high ? QuitTheme.onCocoa : QuitTheme.onSage)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(risk.level == .high ? QuitTheme.cocoa : QuitTheme.sage)
                    .cornerRadius(12)
            }
            Text(risk.summary)
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
            Text(insights.dataConfidenceSummary)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.muted)
        }
        .quietCard()
    }

    private var progressSummary: some View {
        let progress = store.progressSummary
        return VStack(alignment: .leading, spacing: 14) {
            Text("Progress from history")
                .font(.rounded(.headline, weight: .bold))

            metricRow("Smoke-free streak", insights.smokeFreeSummary)
            metricRow("Cravings handled", "\(insights.cravingsHandled) of \(insights.cravingsLogged)")
            metricRow("Cravings ending in smoking", "\(insights.slippedCravings)")
            metricRow("Cigarettes avoided", "\(insights.cigarettesAvoided)")
            metricRow("Estimated saved", insights.moneySavedSummary)

            if !progress.milestones.isEmpty {
                Divider()
                ForEach(progress.milestones, id: \.self) { milestone in
                    Text(milestone)
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundColor(QuitTheme.cocoa)
                }
            }
        }
        .quietCard()
    }

    private var heatMap: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Craving heat")
                .font(.rounded(.headline, weight: .bold))
            Text("Last 28 days")
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.muted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(insights.heatMapDays) { day in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color(for: day.level))
                        .frame(height: 34)
                        .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day())), \(day.count) logged cravings")
                }
            }
        }
        .quietCard()
    }

    private var planAdjustment: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let suggestion = store.highestPriorityPendingPlanSuggestion {
                Text(suggestion.title)
                    .font(.rounded(.headline, weight: .bold))
                Text(suggestion.evidenceSummary)
                    .font(.rounded(.caption, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                Text(suggestion.explanation)
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(suggestion.suggestedAction)
                    .font(.rounded(.caption))
                    .foregroundColor(QuitTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Accept suggestion") {
                    if store.acceptPlanSuggestion(suggestion.id) {
                        store.selectedTab = .plan
                    }
                }
                .buttonStyle(FilledButtonStyle())
                Button("Dismiss") {
                    store.dismissPlanSuggestion(suggestion.id)
                }
                .buttonStyle(QuietButtonStyle())
            } else {
                Text(insights.planAdjustment.title)
                    .font(.rounded(.headline, weight: .bold))
                Text(insights.planAdjustment.detail)
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
                if store.canApplyPlanAdjustmentSuggestion {
                    Button("Apply suggestion") {
                        if store.applyPlanAdjustmentSuggestion() {
                            store.selectedTab = .plan
                        }
                    }
                    .buttonStyle(FilledButtonStyle())
                }
                Button(insights.planAdjustment.actionTitle) {
                    store.selectedTab = .plan
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
        .quietCard()
    }

    private var historyPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent history")
                .font(.rounded(.headline, weight: .bold))

            let entries = store.historyEntries().prefix(5)
            if entries.isEmpty {
                Text("Cravings, check-ins, and slips will appear here after you save them.")
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
            } else {
                ForEach(Array(entries)) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(entry.kind.rawValue): \(entry.title)")
                            .font(.rounded(.subheadline, weight: .bold))
                        Text(entry.detail)
                            .font(.rounded(.caption))
                            .foregroundColor(QuitTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Button("Open full history") {
                isHistoryPresented = true
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityIdentifier("open-history-button")
        }
        .quietCard()
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
            Spacer(minLength: 12)
            Text(value)
                .font(.rounded(.headline, weight: .bold))
                .foregroundColor(QuitTheme.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }

    private func color(for level: Int) -> Color {
        switch level {
        case 0:
            return QuitTheme.faint.opacity(0.14)
        case 1:
            return QuitTheme.peach.opacity(0.36)
        case 2:
            return QuitTheme.peach.opacity(0.72)
        case 3:
            return QuitTheme.sage
        default:
            return QuitTheme.cocoa
        }
    }
}

private struct HistoryTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TeoPateoStore
    @State private var selectedEntry: HistoryEntry?

    private var recap: WeeklyRecap {
        store.weeklyRecap()
    }

    var body: some View {
        ZStack {
            QuitTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    StatusBanner(status: store.lastSaveStatus, persistenceError: store.persistenceError)
                    weeklyRecap
                    timeline
                }
                .padding(24)
            }
        }
        .sheet(item: $selectedEntry) { entry in
            HistoryEntryDetailView(entry: entry)
                .environmentObject(store)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            ScreenHeader(eyebrow: "History", title: "Review what actually happened.")
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
            .accessibilityLabel("Close history")
        }
    }

    private var weeklyRecap: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This week")
                .font(.rounded(.headline, weight: .bold))
            HStack(spacing: 10) {
                recapMetric("Cravings", "\(recap.cravingsLogged)")
                recapMetric("Handled", "\(recap.cravingsHandled)")
                recapMetric("No-smoke days", "\(recap.smokeFreeCheckInDays)")
            }
            metricLine("Top trigger", recap.topTrigger ?? "Not enough history yet")
            metricLine("Plan adjustment", recap.planAdjustment.title)
        }
        .quietCard()
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Timeline")
                .font(.rounded(.headline, weight: .bold))

            let groups = store.historyGroups
            if groups.isEmpty {
                Text("Saved cravings, check-ins, and slips will appear here.")
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
                    .quietCard()
            } else {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(dayTitle(group.day))
                            .font(.rounded(.caption, weight: .bold))
                            .foregroundColor(QuitTheme.muted)
                        ForEach(group.entries) { entry in
                            Button {
                                selectedEntry = entry
                            } label: {
                                historyRow(entry)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("history-row-\(entry.kind.rawValue)-\(entry.title)")
                        }
                    }
                    .quietCard()
                }
            }
        }
    }

    private func historyRow(_ entry: HistoryEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(for: entry.kind))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(QuitTheme.cocoa)
                .frame(width: 34, height: 34)
                .background(QuitTheme.peach.opacity(0.62))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.title)
                        .font(.rounded(.subheadline, weight: .bold))
                        .foregroundColor(QuitTheme.ink)
                    Spacer()
                    Text(timeTitle(entry.date))
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundColor(QuitTheme.muted)
                }
                Text(entry.detail)
                    .font(.rounded(.caption))
                    .foregroundColor(QuitTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func recapMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.rounded(.headline, weight: .bold))
                .foregroundColor(QuitTheme.ink)
            Text(label)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.muted)
            Spacer(minLength: 12)
            Text(value)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    private func icon(for kind: HistoryEntry.Kind) -> String {
        switch kind {
        case .craving:
            return "timer"
        case .checkIn:
            return "checkmark"
        case .slip:
            return "arrow.uturn.left"
        }
    }
}

private struct HistoryEntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TeoPateoStore
    let entry: HistoryEntry

    @State private var isEditing = false
    @State private var slipDraft = ""
    @State private var recoveryDraft = ""
    @State private var isDeletePresented = false

    var body: some View {
        ZStack {
            QuitTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    detailHeader
                    detailBody
                    actions
                }
                .padding(24)
            }
        }
        .onAppear(perform: syncDrafts)
        .alert("Delete this record?", isPresented: $isDeletePresented) {
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the record from history and insights.")
        }
    }

    private var detailHeader: some View {
        HStack(alignment: .top) {
            ScreenHeader(eyebrow: entry.kind.rawValue, title: entry.title)
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
            .accessibilityLabel("Close detail")
        }
    }

    @ViewBuilder
    private var detailBody: some View {
        switch entry.kind {
        case .craving:
            if let event = store.cravingEvents.first(where: { $0.id == entry.id }) {
                cravingDetail(event)
            } else {
                missingDetail
            }
        case .checkIn:
            if let checkIn = store.dailyCheckIns.first(where: { $0.id == entry.id }) {
                checkInDetail(checkIn)
            } else {
                missingDetail
            }
        case .slip:
            if let event = store.slipEvents.first(where: { $0.id == entry.id }) {
                slipDetail(event)
            } else {
                missingDetail
            }
        }
    }

    private var missingDetail: some View {
        Text("This record is no longer available.")
            .font(.rounded(.subheadline))
            .foregroundColor(QuitTheme.muted)
            .quietCard()
    }

    private func cravingDetail(_ event: CravingEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            detailLine("Time", "\(dayTitle(entry.date)) at \(timeTitle(entry.date))")
            detailLine("Duration", durationTitle(event.durationSeconds))
            detailLine("Outcome", entry.title)
            detailLine("Triggers", event.selectedTriggers.isEmpty ? "No trigger selected" : event.selectedTriggers.joined(separator: ", "))
            if let initial = event.initialIntensity {
                detailLine("Initial intensity", "\(Int(initial))")
            }
            if let final = event.finalIntensity {
                detailLine("Final intensity", "\(Int(final))")
            }
            if let activityID = event.helpedActivityID,
               let activity = store.replacementActivities.first(where: { $0.id == activityID }) {
                detailLine("Activity tried", activity.title)
            }
            if !event.reflectionNote.isEmpty {
                detailLine("Note", event.reflectionNote)
            }
        }
        .quietCard()
    }

    private func checkInDetail(_ checkIn: DailyCheckIn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            detailLine("Date", dayTitle(checkIn.date))
            detailLine("Mood", "\(Int(checkIn.mood))")
            detailLine("Stress", "\(Int(checkIn.stress))")
            detailLine("Confidence", "\(Int(checkIn.confidence))")
            detailLine("Smoking", checkIn.smokedToday == true ? "\(checkIn.cigarettesSmoked) cigarette\(checkIn.cigarettesSmoked == 1 ? "" : "s")" : "No smoke")
            if let target = checkIn.taperTargetCigarettes {
                detailLine("Taper target", "\(Int(target)) cigarette\(Int(target) == 1 ? "" : "s")")
            }

            if isEditing {
                if checkIn.smokedToday == true {
                    noteEditor("Slip note", text: $slipDraft)
                }
            } else {
                if checkIn.smokedToday == true {
                    detailLine("Slip note", checkIn.slipNote.isEmpty ? "No slip note" : checkIn.slipNote)
                }
            }
        }
        .quietCard()
    }

    private func slipDetail(_ event: SlipEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            detailLine("Time", "\(dayTitle(event.occurredAt)) at \(timeTitle(event.occurredAt))")
            detailLine("Cigarettes", "\(event.cigarettesSmoked)")
            detailLine("Triggers", event.selectedTriggers.isEmpty ? "No trigger selected" : event.selectedTriggers.joined(separator: ", "))
            if !event.context.isEmpty {
                detailLine("Context", event.context)
            }

            if isEditing {
                noteEditor("Note", text: $slipDraft)
                noteEditor("Recovery action", text: $recoveryDraft)
            } else {
                detailLine("Note", event.note.isEmpty ? "No note" : event.note)
                detailLine("Recovery action", event.recoveryAction.isEmpty ? "No recovery action" : event.recoveryAction)
            }
        }
        .quietCard()
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            if canEditNotes {
                Button(isEditing ? "Save notes" : "Edit notes") {
                    isEditing ? saveNotes() : beginEditing()
                }
                .buttonStyle(FilledButtonStyle())
                .accessibilityIdentifier("history-edit-save-notes-button")

                if isEditing {
                    Button("Cancel") {
                        isEditing = false
                        syncDrafts()
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }

            Button("Delete record", role: .destructive) {
                isDeletePresented = true
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityIdentifier("history-delete-record-button")
        }
    }

    private var canEditNotes: Bool {
        switch entry.kind {
        case .checkIn:
            return store.dailyCheckIns.first(where: { $0.id == entry.id })?.smokedToday == true
        case .slip:
            return true
        case .craving:
            return false
        }
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.muted)
            Text(value)
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func noteEditor(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.muted)
            TextEditor(text: text)
                .quietEditor(minHeight: 96)
                .accessibilityIdentifier(label == "Recovery action" ? "history-recovery-editor" : "history-note-editor")
        }
    }

    private func beginEditing() {
        syncDrafts()
        isEditing = true
    }

    private func saveNotes() {
        switch entry.kind {
        case .checkIn:
            store.updateDailyCheckInSlipNote(id: entry.id, slipNote: slipDraft)
        case .slip:
            store.updateSlipEventNotes(id: entry.id, note: slipDraft, recoveryAction: recoveryDraft)
        case .craving:
            return
        }
        isEditing = false
    }

    private func deleteEntry() {
        switch entry.kind {
        case .craving:
            store.deleteCravingEvent(entry.id)
        case .checkIn:
            store.deleteDailyCheckIn(entry.id)
        case .slip:
            store.deleteSlipEvent(entry.id)
        }
        dismiss()
    }

    private func syncDrafts() {
        switch entry.kind {
        case .checkIn:
            guard let checkIn = store.dailyCheckIns.first(where: { $0.id == entry.id }) else { return }
            slipDraft = checkIn.slipNote
        case .slip:
            guard let event = store.slipEvents.first(where: { $0.id == entry.id }) else { return }
            slipDraft = event.note
            recoveryDraft = event.recoveryAction
        case .craving:
            return
        }
    }
}

private func dayTitle(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
}

private func timeTitle(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

private func durationTitle(_ seconds: Int) -> String {
    let minutes = max(seconds, 0) / 60
    if minutes <= 0 {
        return "Under 1 minute"
    }
    return minutes == 1 ? "1 minute" : "\(minutes) minutes"
}
