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

    @State private var selectedPlanSheet: PlanSheet?

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
            notifications
        }
        .sheet(item: $selectedPlanSheet, onDismiss: resetPlanSheetState) { sheet in
            planSheet(sheet)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Trigger rules")
                .font(.rounded(.headline, weight: .bold))

            ForEach(store.triggerRules) { rule in
                planItemButton(
                    title: rule.trigger,
                    systemName: "bolt.fill",
                    badge: rule.isEnabled ? "On" : "Off",
                    isEnabled: rule.isEnabled
                ) {
                    openPlanSheet(.triggerRule(rule.id))
                }
            }

            addPlanItemButton(title: "Add trigger rule") {
                openPlanSheet(.newTriggerRule)
            }
        }
        .quietCard()
    }

    private var reasons: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reasons")
                .font(.rounded(.headline, weight: .bold))

            ForEach(store.userReasons) { reason in
                planItemButton(
                    title: reason.text,
                    systemName: reason.isPrimary ? "star.fill" : "heart.fill",
                    badge: reason.isPrimary ? "Primary" : nil
                ) {
                    openPlanSheet(.reason(reason.id))
                }
            }

            addPlanItemButton(title: "Add reason") {
                openPlanSheet(.newReason)
            }
        }
        .quietCard()
    }

    private var replacementActivities: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Replacement activities")
                .font(.rounded(.headline, weight: .bold))

            ForEach(store.replacementActivities) { activity in
                planItemButton(
                    title: activity.title,
                    systemName: activity.category.systemImage,
                    badge: activity.isEnabled ? "On" : "Off",
                    isEnabled: activity.isEnabled
                ) {
                    openPlanSheet(.activity(activity.id))
                }
            }

            addPlanItemButton(title: "Add activity") {
                openPlanSheet(.newActivity)
            }
        }
        .quietCard()
    }

    @ViewBuilder
    private func planSheet(_ sheet: PlanSheet) -> some View {
        switch sheet {
        case .triggerRule(let id):
            triggerRuleSheet(id)
        case .newTriggerRule:
            newTriggerRuleSheet
        case .reason(let id):
            reasonSheet(id)
        case .newReason:
            newReasonSheet
        case .activity(let id):
            activitySheet(id)
        case .newActivity:
            newActivitySheet
        case .notifications:
            NotificationSettingsView()
                .environmentObject(store)
        }
    }

    private func planItemButton(
        title: String,
        systemName: String,
        badge: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                    .frame(width: 36, height: 36)
                    .background(QuitTheme.peach.opacity(0.52))
                    .clipShape(Circle())

                Text(title)
                    .font(.rounded(.headline, weight: .bold))
                    .foregroundColor(QuitTheme.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                if let badge = badge {
                    planBadge(badge, isEnabled: isEnabled)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(QuitTheme.faint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(QuitTheme.background.opacity(isEnabled ? 0.65 : 0.38))
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isEnabled ? 1 : 0.62)
    }

    private func addPlanItemButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus.circle.fill")
                .font(.rounded(.subheadline, weight: .bold))
                .foregroundColor(QuitTheme.cocoa)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(QuitTheme.peach.opacity(0.55))
                .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 2)
    }

    private func planBadge(_ text: String, isEnabled: Bool = true) -> some View {
        Text(text)
            .font(.rounded(.caption, weight: .bold))
            .foregroundColor(isEnabled ? QuitTheme.cocoa : QuitTheme.muted)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background((isEnabled ? QuitTheme.sage : QuitTheme.peach).opacity(0.42))
            .cornerRadius(10)
    }

    private func sheetShell<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            QuitTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sheetHeader(title: title, subtitle: subtitle)
                    content()
                }
                .padding(24)
            }
        }
    }

    private func sheetHeader(title: String, subtitle: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.rounded(.title2, weight: .bold))
                    .foregroundColor(QuitTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.rounded(.subheadline))
                        .foregroundColor(QuitTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Button {
                closePlanSheet()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                    .frame(width: 38, height: 38)
                    .background(QuitTheme.peach.opacity(0.7))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close")
        }
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.faint)
                .textCase(.uppercase)
            Text(value)
                .font(.rounded(.body))
                .foregroundColor(QuitTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func sheetActionButton(
        title: String,
        systemName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
        }
        .buttonStyle(QuietButtonStyle())
    }

    private func deleteActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "trash")
        }
        .font(.rounded(.headline, weight: .bold))
        .foregroundColor(QuitTheme.cocoa)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(QuitTheme.background)
        .cornerRadius(12)
    }

    @ViewBuilder
    private func triggerRuleSheet(_ id: UUID) -> some View {
        if let rule = store.triggerRules.first(where: { $0.id == id }) {
            if editingRuleID == id {
                sheetShell(title: "Edit rule") {
                    triggerRuleForm(
                        trigger: $editTrigger,
                        action: $editAction,
                        isEnabled: $editRuleEnabled,
                        saveTitle: "Save rule",
                        save: {
                            let trigger = editTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
                            let action = editAction.trimmingCharacters(in: .whitespacesAndNewlines)
                            store.updateTriggerRule(
                                id: id,
                                trigger: editTrigger,
                                action: editAction,
                                isEnabled: editRuleEnabled
                            )
                            if !trigger.isEmpty && !action.isEmpty {
                                closePlanSheet()
                            }
                        },
                        cancel: { editingRuleID = nil }
                    )
                }
            } else {
                let ruleIndex = index(of: rule.id, in: store.triggerRules)
                sheetShell(title: rule.trigger, subtitle: rule.isEnabled ? "Rule is on" : "Rule is off") {
                    detailLine("Do instead", rule.action)
                    VStack(spacing: 10) {
                        sheetActionButton(
                            title: rule.isEnabled ? "Turn off rule" : "Turn on rule",
                            systemName: rule.isEnabled ? "power" : "play"
                        ) {
                            store.setTriggerRuleEnabled(rule.id, isEnabled: !rule.isEnabled)
                        }
                        sheetActionButton(title: "Edit rule", systemName: "pencil") {
                            beginRuleEdit(rule)
                        }
                        sheetActionButton(title: "Move up", systemName: "chevron.up") {
                            store.moveTriggerRule(rule.id, direction: -1)
                        }
                        .disabled(ruleIndex <= 0)
                        .opacity(ruleIndex <= 0 ? 0.48 : 1)
                        sheetActionButton(title: "Move down", systemName: "chevron.down") {
                            store.moveTriggerRule(rule.id, direction: 1)
                        }
                        .disabled(ruleIndex >= store.triggerRules.count - 1)
                        .opacity(ruleIndex >= store.triggerRules.count - 1 ? 0.48 : 1)
                        deleteActionButton(title: "Delete rule") {
                            store.deleteTriggerRule(rule.id)
                            closePlanSheet()
                        }
                    }
                }
            }
        } else {
            missingItemSheet(title: "Rule not found")
        }
    }

    private var newTriggerRuleSheet: some View {
        sheetShell(title: "Add trigger rule") {
            triggerRuleForm(
                trigger: $newTrigger,
                action: $newAction,
                saveTitle: "Add rule",
                save: saveNewTriggerRule,
                cancel: closePlanSheet
            )
        }
    }

    private func triggerRuleForm(
        trigger: Binding<String>,
        action: Binding<String>,
        isEnabled: Binding<Bool>? = nil,
        saveTitle: String,
        save: @escaping () -> Void,
        cancel: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("When this happens", text: trigger)
                .textFieldStyle(.roundedBorder)
            TextField("Do this instead", text: action)
                .textFieldStyle(.roundedBorder)
            if let isEnabled = isEnabled {
                Toggle("Turned on", isOn: isEnabled)
                    .font(.rounded(.subheadline, weight: .bold))
            }
            editButtons(saveTitle: saveTitle, save: save, cancel: cancel)
        }
    }

    @ViewBuilder
    private func reasonSheet(_ id: UUID) -> some View {
        if let reason = store.userReasons.first(where: { $0.id == id }) {
            if editingReasonID == id {
                sheetShell(title: "Edit reason") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Reason for quitting", text: $editReason)
                            .textFieldStyle(.roundedBorder)
                        editButtons(
                            saveTitle: "Save reason",
                            save: {
                                let text = editReason.trimmingCharacters(in: .whitespacesAndNewlines)
                                store.updateUserReason(reason.id, text: editReason)
                                if !text.isEmpty {
                                    closePlanSheet()
                                }
                            },
                            cancel: { editingReasonID = nil }
                        )
                    }
                }
            } else {
                let reasonIndex = index(of: reason.id, in: store.userReasons)
                sheetShell(title: "Reason", subtitle: reason.isPrimary ? "Primary reason" : "Saved reason") {
                    detailLine("Reason", reason.text)
                    VStack(spacing: 10) {
                        if !reason.isPrimary {
                            sheetActionButton(title: "Make primary", systemName: "star") {
                                store.setPrimaryUserReason(reason.id)
                            }
                        }
                        sheetActionButton(title: "Edit reason", systemName: "pencil") {
                            editingReasonID = reason.id
                            editReason = reason.text
                        }
                        sheetActionButton(title: "Move up", systemName: "chevron.up") {
                            store.moveUserReason(reason.id, direction: -1)
                        }
                        .disabled(reasonIndex <= 0)
                        .opacity(reasonIndex <= 0 ? 0.48 : 1)
                        sheetActionButton(title: "Move down", systemName: "chevron.down") {
                            store.moveUserReason(reason.id, direction: 1)
                        }
                        .disabled(reasonIndex >= store.userReasons.count - 1)
                        .opacity(reasonIndex >= store.userReasons.count - 1 ? 0.48 : 1)
                        deleteActionButton(title: "Delete reason") {
                            store.deleteUserReason(reason.id)
                            closePlanSheet()
                        }
                    }
                }
            }
        } else {
            missingItemSheet(title: "Reason not found")
        }
    }

    private var newReasonSheet: some View {
        sheetShell(title: "Add reason") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Reason for quitting", text: $newReason)
                    .textFieldStyle(.roundedBorder)
                editButtons(
                    saveTitle: "Add reason",
                    save: saveNewReason,
                    cancel: closePlanSheet
                )
            }
        }
    }

    @ViewBuilder
    private func activitySheet(_ id: UUID) -> some View {
        if let activity = store.replacementActivities.first(where: { $0.id == id }) {
            if editingActivityID == id {
                sheetShell(title: "Edit activity") {
                    activityForm(
                        title: $editActivityTitle,
                        instruction: $editActivityInstruction,
                        linkedTrigger: $editActivityLinkedTrigger,
                        category: $editActivityCategory,
                        isEnabled: $editActivityEnabled,
                        saveTitle: "Save activity",
                        save: {
                            let title = editActivityTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            let instruction = editActivityInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
                            store.updateReplacementActivity(
                                id: activity.id,
                                title: editActivityTitle,
                                instruction: editActivityInstruction,
                                category: editActivityCategory,
                                linkedTrigger: editActivityLinkedTrigger,
                                isEnabled: editActivityEnabled
                            )
                            if !title.isEmpty && !instruction.isEmpty {
                                closePlanSheet()
                            }
                        },
                        cancel: { editingActivityID = nil }
                    )
                }
            } else {
                let activityIndex = index(of: activity.id, in: store.replacementActivities)
                sheetShell(title: activity.title, subtitle: activity.isEnabled ? "Activity is on" : "Activity is off") {
                    detailLine("Instruction", activity.instruction)
                    detailLine("Category", activity.category.title)
                    if !activity.linkedTrigger.isEmpty {
                        detailLine("For trigger", activity.linkedTrigger)
                    }
                    VStack(spacing: 10) {
                        sheetActionButton(
                            title: activity.isEnabled ? "Turn off activity" : "Turn on activity",
                            systemName: activity.isEnabled ? "power" : "play"
                        ) {
                            store.setReplacementActivityEnabled(activity.id, isEnabled: !activity.isEnabled)
                        }
                        sheetActionButton(title: "Edit activity", systemName: "pencil") {
                            beginActivityEdit(activity)
                        }
                        sheetActionButton(title: "Move up", systemName: "chevron.up") {
                            store.moveReplacementActivity(activity.id, direction: -1)
                        }
                        .disabled(activityIndex <= 0)
                        .opacity(activityIndex <= 0 ? 0.48 : 1)
                        sheetActionButton(title: "Move down", systemName: "chevron.down") {
                            store.moveReplacementActivity(activity.id, direction: 1)
                        }
                        .disabled(activityIndex >= store.replacementActivities.count - 1)
                        .opacity(activityIndex >= store.replacementActivities.count - 1 ? 0.48 : 1)
                        deleteActionButton(title: "Delete activity") {
                            store.deleteReplacementActivity(activity.id)
                            closePlanSheet()
                        }
                    }
                }
            }
        } else {
            missingItemSheet(title: "Activity not found")
        }
    }

    private var newActivitySheet: some View {
        sheetShell(title: "Add activity") {
            activityForm(
                title: $newActivityTitle,
                instruction: $newActivityInstruction,
                linkedTrigger: $newActivityLinkedTrigger,
                category: $newActivityCategory,
                saveTitle: "Add activity",
                save: saveNewActivity,
                cancel: closePlanSheet
            )
        }
    }

    private func activityForm(
        title: Binding<String>,
        instruction: Binding<String>,
        linkedTrigger: Binding<String>,
        category: Binding<ReplacementActivityCategory>,
        isEnabled: Binding<Bool>? = nil,
        saveTitle: String,
        save: @escaping () -> Void,
        cancel: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Activity", text: title)
                .textFieldStyle(.roundedBorder)
            TextField("Instruction", text: instruction)
                .textFieldStyle(.roundedBorder)
            TextField("Linked trigger, optional", text: linkedTrigger)
                .textFieldStyle(.roundedBorder)
            Picker("Category", selection: category) {
                ForEach(ReplacementActivityCategory.allCases, id: \.self) { category in
                    Text(category.title).tag(category)
                }
            }
            .pickerStyle(.menu)
            if let isEnabled = isEnabled {
                Toggle("Turned on", isOn: isEnabled)
                    .font(.rounded(.subheadline, weight: .bold))
            }
            editButtons(saveTitle: saveTitle, save: save, cancel: cancel)
        }
    }

    private func missingItemSheet(title: String) -> some View {
        sheetShell(title: title) {
            Text("This item may have been removed.")
                .font(.rounded(.body))
                .foregroundColor(QuitTheme.muted)
            sheetActionButton(title: "Close", systemName: "xmark", action: closePlanSheet)
        }
    }

    private var notifications: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notifications")
                .font(.rounded(.headline, weight: .bold))

            planItemButton(
                title: "Reminder settings",
                systemName: store.notificationSettings.hasEnabledReminders ? "bell.badge.fill" : "bell",
                badge: notificationBadge
            ) {
                openPlanSheet(.notifications)
            }
        }
        .quietCard()
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

    private func openPlanSheet(_ sheet: PlanSheet) {
        resetPlanSheetState()

        switch sheet {
        case .newTriggerRule:
            newTrigger = ""
            newAction = ""
        case .newReason:
            newReason = ""
        case .newActivity:
            newActivityTitle = ""
            newActivityInstruction = ""
            newActivityLinkedTrigger = ""
            newActivityCategory = .distraction
        default:
            break
        }

        selectedPlanSheet = sheet
    }

    private func closePlanSheet() {
        selectedPlanSheet = nil
        resetPlanSheetState()
    }

    private func resetPlanSheetState() {
        editingRuleID = nil
        editingReasonID = nil
        editingActivityID = nil
    }

    private func saveNewTriggerRule() {
        let trigger = newTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let action = newAction.trimmingCharacters(in: .whitespacesAndNewlines)
        store.addTriggerRule(trigger: newTrigger, action: newAction)
        if !trigger.isEmpty && !action.isEmpty {
            closePlanSheet()
        }
    }

    private func saveNewReason() {
        let reason = newReason.trimmingCharacters(in: .whitespacesAndNewlines)
        store.addUserReason(newReason, isPrimary: store.userReasons.isEmpty)
        if !reason.isEmpty {
            closePlanSheet()
        }
    }

    private func saveNewActivity() {
        let title = newActivityTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let instruction = newActivityInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        store.addReplacementActivity(
            title: newActivityTitle,
            instruction: newActivityInstruction,
            category: newActivityCategory,
            linkedTrigger: newActivityLinkedTrigger
        )
        if !title.isEmpty && !instruction.isEmpty {
            closePlanSheet()
        }
    }

    private func index<T: Identifiable>(of id: T.ID, in values: [T]) -> Int {
        values.firstIndex { $0.id == id } ?? 0
    }

    private var notificationBadge: String {
        let count = store.plannedNotificationItems.count
        if count > 0 {
            return count == 1 ? "1 on" : "\(count) on"
        }
        return store.notificationSettings.riskyWindowEnabled ? "Learning" : "Off"
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

private enum PlanSheet: Identifiable {
    case triggerRule(UUID)
    case newTriggerRule
    case reason(UUID)
    case newReason
    case activity(UUID)
    case newActivity
    case notifications

    var id: String {
        switch self {
        case .triggerRule(let id):
            return "trigger-rule-\(id.uuidString)"
        case .newTriggerRule:
            return "new-trigger-rule"
        case .reason(let id):
            return "reason-\(id.uuidString)"
        case .newReason:
            return "new-reason"
        case .activity(let id):
            return "activity-\(id.uuidString)"
        case .newActivity:
            return "new-activity"
        case .notifications:
            return "notifications"
        }
    }
}

private extension ReplacementActivityCategory {
    var systemImage: String {
        switch self {
        case .movement:
            return "figure.walk"
        case .breathing:
            return "wind"
        case .sensory:
            return "drop.fill"
        case .support:
            return "person.2.fill"
        case .journaling:
            return "square.and.pencil"
        case .distraction:
            return "sparkles"
        }
    }
}
