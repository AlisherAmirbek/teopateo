import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var store: TeoPateoStore

    @State private var newTrigger = ""
    @State private var newAction = ""
    @State private var editingRuleID: UUID?
    @State private var editTrigger = ""
    @State private var editAction = ""
    @State private var editRuleEnabled = true

    @State private var newReason = ""
    @State private var editingReasonID: UUID?
    @State private var editReason = ""

    @State private var newActivityTitle = ""
    @State private var newActivityInstruction = ""
    @State private var newActivityLinkedTrigger = ""
    @State private var newActivityCategory: ReplacementActivityCategory = .distraction
    @State private var editingActivityID: UUID?
    @State private var editActivityTitle = ""
    @State private var editActivityInstruction = ""
    @State private var editActivityLinkedTrigger = ""
    @State private var editActivityCategory: ReplacementActivityCategory = .distraction
    @State private var editActivityEnabled = true

    @State private var newRiskTitle = ""
    @State private var newRiskContext = ""
    @State private var newRiskPlan = ""
    @State private var newRiskBackup = ""
    @State private var editingRiskID: UUID?
    @State private var editRiskTitle = ""
    @State private var editRiskContext = ""
    @State private var editRiskPlan = ""
    @State private var editRiskBackup = ""
    @State private var editRiskEnabled = true

    @State private var medicationDraft = ""
    @State private var isNotificationsPresented = false

    var body: some View {
        RootScreen {
            ScreenHeader(eyebrow: "Quit plan", title: "Your plan stays specific.")
            StatusBanner(status: store.lastSaveStatus, persistenceError: store.persistenceError)

            quitDate
            progressBaseline
            approach
            rules
            reasons
            replacementActivities
            riskySituations
            notifications
            medicationNote
        }
        .sheet(isPresented: $isNotificationsPresented) {
            NotificationSettingsView()
                .environmentObject(store)
        }
        .onAppear(perform: syncMedicationDraft)
        .onChange(of: store.currentQuitPlan.medicationNote) { _ in
            syncMedicationDraft()
        }
    }

    private var quitDate: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quit date")
                .font(.rounded(.headline, weight: .bold))

            DatePicker(
                "Target date",
                selection: Binding(
                    get: { store.currentQuitPlan.quitDate },
                    set: { store.updateQuitDate($0) }
                ),
                displayedComponents: .date
            )
            .font(.rounded(.subheadline))

            Text(quitDateSummary)
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
        }
        .quietCard()
    }

    private var progressBaseline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress baseline")
                .font(.rounded(.headline, weight: .bold))

            Stepper(
                "Baseline \(Int(store.currentQuitPlan.baselineCigarettesPerDay)) cigarettes/day",
                value: Binding(
                    get: { Int(store.currentQuitPlan.baselineCigarettesPerDay) },
                    set: {
                        store.updateProgressBaseline(
                            cigarettesPerDay: Double($0),
                            costPerPack: store.currentQuitPlan.costPerPack,
                            cigarettesPerPack: store.currentQuitPlan.cigarettesPerPack
                        )
                    }
                ),
                in: 0...80
            )

            Stepper(
                "Pack cost \(currency(store.currentQuitPlan.costPerPack))",
                value: Binding(
                    get: { store.currentQuitPlan.costPerPack },
                    set: {
                        store.updateProgressBaseline(
                            cigarettesPerDay: store.currentQuitPlan.baselineCigarettesPerDay,
                            costPerPack: $0,
                            cigarettesPerPack: store.currentQuitPlan.cigarettesPerPack
                        )
                    }
                ),
                in: 0...50,
                step: 0.5
            )
        }
        .font(.rounded(.subheadline))
        .quietCard()
    }

    private var approach: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Approach")
                .font(.rounded(.headline, weight: .bold))
            Picker("Approach", selection: $store.quitMode) {
                Text("Taper").tag("Taper")
                Text("Cold turkey").tag("Cold turkey")
            }
            .pickerStyle(.segmented)

            if store.quitMode == "Taper" {
                taperControls
                taperPreview
            } else {
                Text("Prepare substitutes before the quit date.")
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
            }
        }
        .quietCard()
    }

    private var taperControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stepper(
                "Current target \(Int(store.currentQuitPlan.taperTargetCigarettesPerDay)) cigarettes/day",
                value: Binding(
                    get: { Int(store.currentQuitPlan.taperTargetCigarettesPerDay) },
                    set: {
                        store.updateTaperSettings(
                            targetCigarettesPerDay: Double($0),
                            reductionStep: store.currentQuitPlan.taperReductionStep,
                            reductionIntervalDays: store.currentQuitPlan.taperReductionIntervalDays
                        )
                    }
                ),
                in: 0...80
            )

            Stepper(
                "Reduce by \(Int(store.currentQuitPlan.taperReductionStep))",
                value: Binding(
                    get: { Int(store.currentQuitPlan.taperReductionStep) },
                    set: {
                        store.updateTaperSettings(
                            targetCigarettesPerDay: store.currentQuitPlan.taperTargetCigarettesPerDay,
                            reductionStep: Double($0),
                            reductionIntervalDays: store.currentQuitPlan.taperReductionIntervalDays
                        )
                    }
                ),
                in: 0...20
            )

            Stepper(
                "Every \(store.currentQuitPlan.taperReductionIntervalDays) days",
                value: Binding(
                    get: { store.currentQuitPlan.taperReductionIntervalDays },
                    set: {
                        store.updateTaperSettings(
                            targetCigarettesPerDay: store.currentQuitPlan.taperTargetCigarettesPerDay,
                            reductionStep: store.currentQuitPlan.taperReductionStep,
                            reductionIntervalDays: $0
                        )
                    }
                ),
                in: 1...30
            )
        }
        .font(.rounded(.subheadline))
    }

    private var taperPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upcoming targets")
                .font(.rounded(.subheadline, weight: .bold))

            ForEach(store.taperSchedule(days: 5)) { day in
                HStack {
                    Text(day.isToday ? "Today" : dayLabel(day.date))
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundColor(day.isToday ? QuitTheme.cocoa : QuitTheme.muted)
                    Spacer()
                    Text("\(Int(day.targetCigarettes)) cigarettes")
                        .font(.rounded(.caption, weight: .bold))
                }
            }
        }
        .padding(.top, 4)
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Trigger rules")
                .font(.rounded(.headline, weight: .bold))

            ForEach(store.triggerRules) { rule in
                ruleRow(rule, index: index(of: rule.id, in: store.triggerRules))
            }

            Divider()
            TextField("Trigger", text: $newTrigger)
                .textFieldStyle(.roundedBorder)
            TextField("What I'll do instead", text: $newAction)
                .textFieldStyle(.roundedBorder)
            Button("Add trigger rule") {
                store.addTriggerRule(trigger: newTrigger, action: newAction)
                newTrigger = ""
                newAction = ""
            }
            .buttonStyle(QuietButtonStyle())
        }
        .quietCard()
    }

    @ViewBuilder
    private func ruleRow(_ rule: TriggerRule, index: Int) -> some View {
        if editingRuleID == rule.id {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Trigger", text: $editTrigger)
                    .textFieldStyle(.roundedBorder)
                TextField("What I'll do instead", text: $editAction)
                    .textFieldStyle(.roundedBorder)
                Toggle("Enabled", isOn: $editRuleEnabled)
                    .font(.rounded(.caption, weight: .bold))
                editButtons(
                    saveTitle: "Save rule",
                    save: {
                        store.updateTriggerRule(
                            id: rule.id,
                            trigger: editTrigger,
                            action: editAction,
                            isEnabled: editRuleEnabled
                        )
                        editingRuleID = nil
                    },
                    cancel: { editingRuleID = nil }
                )
            }
            .padding(.vertical, 6)
        } else {
            managedRow(
                title: rule.trigger,
                detail: rule.action,
                isEnabled: rule.isEnabled,
                index: index,
                count: store.triggerRules.count,
                edit: { beginRuleEdit(rule) },
                toggle: { store.setTriggerRuleEnabled(rule.id, isEnabled: !rule.isEnabled) },
                delete: { store.deleteTriggerRule(rule.id) },
                moveUp: { store.moveTriggerRule(rule.id, direction: -1) },
                moveDown: { store.moveTriggerRule(rule.id, direction: 1) }
            )
        }
    }

    private var reasons: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reasons")
                .font(.rounded(.headline, weight: .bold))

            ForEach(store.userReasons) { reason in
                reasonRow(reason, index: index(of: reason.id, in: store.userReasons))
            }

            Divider()
            TextField("Reason for quitting", text: $newReason)
                .textFieldStyle(.roundedBorder)
            Button("Add reason") {
                store.addUserReason(newReason, isPrimary: store.userReasons.isEmpty)
                newReason = ""
            }
            .buttonStyle(QuietButtonStyle())
        }
        .quietCard()
    }

    @ViewBuilder
    private func reasonRow(_ reason: UserReason, index: Int) -> some View {
        if editingReasonID == reason.id {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Reason", text: $editReason)
                    .textFieldStyle(.roundedBorder)
                editButtons(
                    saveTitle: "Save reason",
                    save: {
                        store.updateUserReason(reason.id, text: editReason)
                        editingReasonID = nil
                    },
                    cancel: { editingReasonID = nil }
                )
            }
            .padding(.vertical, 6)
        } else {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reason.text)
                        .font(.rounded(.subheadline, weight: .bold))
                    if reason.isPrimary {
                        Text("Primary reason")
                            .font(.rounded(.caption, weight: .bold))
                            .foregroundColor(QuitTheme.muted)
                    }
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
                actionButton(systemName: "pencil", title: "Edit reason") {
                    editingReasonID = reason.id
                    editReason = reason.text
                }
                actionButton(systemName: "trash", title: "Remove reason") {
                    store.deleteUserReason(reason.id)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var replacementActivities: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Replacement activities")
                .font(.rounded(.headline, weight: .bold))

            ForEach(store.replacementActivities) { activity in
                activityRow(activity, index: index(of: activity.id, in: store.replacementActivities))
            }

            Divider()
            TextField("Activity", text: $newActivityTitle)
                .textFieldStyle(.roundedBorder)
            TextField("Instruction", text: $newActivityInstruction)
                .textFieldStyle(.roundedBorder)
            TextField("Linked trigger, optional", text: $newActivityLinkedTrigger)
                .textFieldStyle(.roundedBorder)
            Picker("Category", selection: $newActivityCategory) {
                ForEach(ReplacementActivityCategory.allCases, id: \.self) { category in
                    Text(category.title).tag(category)
                }
            }
            .pickerStyle(.menu)
            Button("Add activity") {
                store.addReplacementActivity(
                    title: newActivityTitle,
                    instruction: newActivityInstruction,
                    category: newActivityCategory,
                    linkedTrigger: newActivityLinkedTrigger
                )
                newActivityTitle = ""
                newActivityInstruction = ""
                newActivityLinkedTrigger = ""
            }
            .buttonStyle(QuietButtonStyle())
        }
        .quietCard()
    }

    @ViewBuilder
    private func activityRow(_ activity: ReplacementActivity, index: Int) -> some View {
        if editingActivityID == activity.id {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Activity", text: $editActivityTitle)
                    .textFieldStyle(.roundedBorder)
                TextField("Instruction", text: $editActivityInstruction)
                    .textFieldStyle(.roundedBorder)
                TextField("Linked trigger, optional", text: $editActivityLinkedTrigger)
                    .textFieldStyle(.roundedBorder)
                Picker("Category", selection: $editActivityCategory) {
                    ForEach(ReplacementActivityCategory.allCases, id: \.self) { category in
                        Text(category.title).tag(category)
                    }
                }
                .pickerStyle(.menu)
                Toggle("Enabled", isOn: $editActivityEnabled)
                    .font(.rounded(.caption, weight: .bold))
                editButtons(
                    saveTitle: "Save activity",
                    save: {
                        store.updateReplacementActivity(
                            id: activity.id,
                            title: editActivityTitle,
                            instruction: editActivityInstruction,
                            category: editActivityCategory,
                            linkedTrigger: editActivityLinkedTrigger,
                            isEnabled: editActivityEnabled
                        )
                        editingActivityID = nil
                    },
                    cancel: { editingActivityID = nil }
                )
            }
            .padding(.vertical, 6)
        } else {
            let detail = activity.linkedTrigger.isEmpty
                ? activity.instruction
                : "\(activity.instruction) Linked to \(activity.linkedTrigger)."
            managedRow(
                title: activity.title,
                detail: detail,
                isEnabled: activity.isEnabled,
                index: index,
                count: store.replacementActivities.count,
                edit: { beginActivityEdit(activity) },
                toggle: { store.setReplacementActivityEnabled(activity.id, isEnabled: !activity.isEnabled) },
                delete: { store.deleteReplacementActivity(activity.id) },
                moveUp: { store.moveReplacementActivity(activity.id, direction: -1) },
                moveDown: { store.moveReplacementActivity(activity.id, direction: 1) }
            )
        }
    }

    private var riskySituations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Risky situations")
                .font(.rounded(.headline, weight: .bold))

            if store.riskySituations.isEmpty {
                Text("Add planned situations like a stressful workday, drinks with friends, or a long drive.")
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
            } else {
                ForEach(store.riskySituations) { situation in
                    riskySituationRow(situation)
                }
            }

            Divider()
            TextField("Situation", text: $newRiskTitle)
                .textFieldStyle(.roundedBorder)
            TextField("Expected context or time", text: $newRiskContext)
                .textFieldStyle(.roundedBorder)
            TextField("Prevention plan", text: $newRiskPlan)
                .textFieldStyle(.roundedBorder)
            TextField("Backup action", text: $newRiskBackup)
                .textFieldStyle(.roundedBorder)
            Button("Add risky situation") {
                store.addRiskySituation(
                    title: newRiskTitle,
                    expectedContext: newRiskContext,
                    preventionPlan: newRiskPlan,
                    backupAction: newRiskBackup
                )
                newRiskTitle = ""
                newRiskContext = ""
                newRiskPlan = ""
                newRiskBackup = ""
            }
            .buttonStyle(QuietButtonStyle())
        }
        .quietCard()
    }

    @ViewBuilder
    private func riskySituationRow(_ situation: RiskySituation) -> some View {
        if editingRiskID == situation.id {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Situation", text: $editRiskTitle)
                    .textFieldStyle(.roundedBorder)
                TextField("Expected context or time", text: $editRiskContext)
                    .textFieldStyle(.roundedBorder)
                TextField("Prevention plan", text: $editRiskPlan)
                    .textFieldStyle(.roundedBorder)
                TextField("Backup action", text: $editRiskBackup)
                    .textFieldStyle(.roundedBorder)
                Toggle("Enabled", isOn: $editRiskEnabled)
                    .font(.rounded(.caption, weight: .bold))
                editButtons(
                    saveTitle: "Save situation",
                    save: {
                        store.updateRiskySituation(
                            id: situation.id,
                            title: editRiskTitle,
                            expectedContext: editRiskContext,
                            preventionPlan: editRiskPlan,
                            backupAction: editRiskBackup,
                            isEnabled: editRiskEnabled
                        )
                        editingRiskID = nil
                    },
                    cancel: { editingRiskID = nil }
                )
            }
            .padding(.vertical, 6)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(situation.title)
                            .font(.rounded(.subheadline, weight: .bold))
                        Text(situation.preventionPlan)
                            .font(.rounded(.caption))
                            .foregroundColor(QuitTheme.muted)
                        if !situation.expectedContext.isEmpty || !situation.backupAction.isEmpty {
                            Text([situation.expectedContext, situation.backupAction].filter { !$0.isEmpty }.joined(separator: " | "))
                                .font(.rounded(.caption))
                                .foregroundColor(QuitTheme.muted)
                        }
                    }
                    .opacity(situation.isEnabled ? 1 : 0.48)
                    Spacer()
                    actionButton(systemName: situation.isEnabled ? "pause" : "play", title: situation.isEnabled ? "Disable situation" : "Enable situation") {
                        store.setRiskySituationEnabled(situation.id, isEnabled: !situation.isEnabled)
                    }
                    actionButton(systemName: "pencil", title: "Edit situation") {
                        beginRiskEdit(situation)
                    }
                    actionButton(systemName: "trash", title: "Remove situation") {
                        store.deleteRiskySituation(situation.id)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var medicationNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Medication note")
                .font(.rounded(.headline, weight: .bold))
            TextEditor(text: $medicationDraft)
                .frame(height: 92)
                .padding(8)
                .background(QuitTheme.background)
                .cornerRadius(12)
            Button("Save medication note") {
                store.updateMedicationNote(medicationDraft)
            }
            .buttonStyle(QuietButtonStyle())
        }
        .quietCard()
    }

    private var notifications: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: store.notificationSettings.hasEnabledReminders ? "bell.badge.fill" : "bell")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                    .frame(width: 34, height: 34)
                    .background(QuitTheme.peach.opacity(0.74))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Notifications")
                        .font(.rounded(.headline, weight: .bold))
                    Text(notificationSummary)
                        .font(.rounded(.caption))
                        .foregroundColor(QuitTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button("Manage reminders") {
                isNotificationsPresented = true
            }
            .buttonStyle(QuietButtonStyle())
        }
        .quietCard()
    }

    private func managedRow(
        title: String,
        detail: String,
        isEnabled: Bool,
        index: Int,
        count: Int,
        edit: @escaping () -> Void,
        toggle: @escaping () -> Void,
        delete: @escaping () -> Void,
        moveUp: @escaping () -> Void,
        moveDown: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.rounded(.subheadline, weight: .bold))
                Text(detail)
                    .font(.rounded(.caption))
                    .foregroundColor(QuitTheme.muted)
            }
            .opacity(isEnabled ? 1 : 0.48)
            Spacer()
            priorityButtons(index: index, count: count, moveUp: moveUp, moveDown: moveDown)
            actionButton(systemName: isEnabled ? "pause" : "play", title: isEnabled ? "Disable" : "Enable", action: toggle)
            actionButton(systemName: "pencil", title: "Edit", action: edit)
            actionButton(systemName: "trash", title: "Remove", action: delete)
        }
        .padding(.vertical, 4)
    }

    private func priorityButtons(
        index: Int,
        count: Int,
        moveUp: @escaping () -> Void,
        moveDown: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 4) {
            actionButton(systemName: "chevron.up", title: "Move up", action: moveUp)
                .disabled(index <= 0)
                .opacity(index <= 0 ? 0.38 : 1)
            actionButton(systemName: "chevron.down", title: "Move down", action: moveDown)
                .disabled(index >= count - 1)
                .opacity(index >= count - 1 ? 0.38 : 1)
        }
    }

    private func actionButton(
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

    private func editButtons(
        saveTitle: String,
        save: @escaping () -> Void,
        cancel: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Button(saveTitle, action: save)
                .buttonStyle(QuietButtonStyle())
            Button("Cancel", action: cancel)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.muted)
        }
    }

    private func beginRuleEdit(_ rule: TriggerRule) {
        editingRuleID = rule.id
        editTrigger = rule.trigger
        editAction = rule.action
        editRuleEnabled = rule.isEnabled
    }

    private func beginActivityEdit(_ activity: ReplacementActivity) {
        editingActivityID = activity.id
        editActivityTitle = activity.title
        editActivityInstruction = activity.instruction
        editActivityLinkedTrigger = activity.linkedTrigger
        editActivityCategory = activity.category
        editActivityEnabled = activity.isEnabled
    }

    private func beginRiskEdit(_ situation: RiskySituation) {
        editingRiskID = situation.id
        editRiskTitle = situation.title
        editRiskContext = situation.expectedContext
        editRiskPlan = situation.preventionPlan
        editRiskBackup = situation.backupAction
        editRiskEnabled = situation.isEnabled
    }

    private func syncMedicationDraft() {
        medicationDraft = store.currentQuitPlan.medicationNote
    }

    private func index<T: Identifiable>(of id: T.ID, in values: [T]) -> Int {
        values.firstIndex { $0.id == id } ?? 0
    }

    private var notificationSummary: String {
        if store.plannedNotificationItems.isEmpty {
            return store.notificationSettings.riskyWindowEnabled
                ? "Risk-window alerts are waiting for more craving history."
                : "Add opt-in reminders for morning plans, risky windows, meals, and evening check-ins."
        }

        let first = store.plannedNotificationItems[0]
        if store.plannedNotificationItems.count == 1 {
            return "\(first.title) at \(first.time.displayLabel)."
        }

        return "\(store.plannedNotificationItems.count) reminders scheduled. Next saved time: \(first.time.displayLabel)."
    }

    private var quitDateSummary: String {
        let today = Calendar.current.startOfDay(for: Date())
        let quitDate = Calendar.current.startOfDay(for: store.currentQuitPlan.quitDate)
        let days = Calendar.current.dateComponents([.day], from: today, to: quitDate).day ?? 0
        if days == 0 {
            return "Quit date is today. Keep the rescue plan close."
        }
        if days > 0 {
            return days == 1 ? "1 day away." : "\(days) days away."
        }
        return "Quit date has passed. Keep the attempt alive or choose a new date."
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = value.rounded() == value ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}
