# Personalized Quit Plan Generation

## Goal

Make `QuitPlan` meaningfully personalized from the expanded onboarding profile and survey data.

The current plan is useful but simple: quit date, taper/cold-turkey mode, baseline, trigger rules, reasons, replacement activities, and reminders. The next version should feel more like a tailored relapse-prevention plan that understands the user's quit stage, smoking background, past attempts, main challenge, triggers, routines, confidence, savings motivation, and real logged behavior over time.

The plan should answer:

- Where is this user in the quit journey?
- What kind of support do they need first?
- What are their highest-risk situations?
- What should they do before, during, and after cravings?
- What should happen if they smoke?
- What daily plan should they follow this week?
- What progress should matter most to them?
- What should change after the app learns from cravings, slips, and check-ins?

## Product Principle

Use the gathered profile data to create a practical plan, not a long report.

The plan should be specific enough to guide the next action and simple enough to use during a craving.

The plan should be adaptive, but not silently rewritten. TeoPateo can suggest updates based on logs, but the user should approve, edit, or dismiss meaningful plan changes.

## Inputs

From expanded onboarding:

- Name or nickname.
- Age.
- Quit status:
  - Already quit.
  - Ready to quit.
  - Cutting down.
  - Thinking about it.
  - Unsure.
- Main reason for quitting.
- Confidence level.
- App-opening reason.
- Age started smoking or years smoking.
- Cigarettes per day.
- First cigarette timing.
- Previous quit attempts.
- Longest previous quit attempt.
- Main challenge.
- Common smoking times.
- Emotional triggers.
- Situational triggers.
- Quit date preference.
- Taper/cold-turkey/unsure preference.
- Replacement actions the user is willing to try.
- Cost per pack.
- Cigarettes per pack.
- Savings goal.

From user logs:

- Craving events.
- Craving outcomes.
- Selected craving triggers.
- Initial and final craving intensity.
- Replacement activities that helped.
- Dismissed craving sessions.
- Slip events.
- Slip triggers.
- Slip notes.
- Recovery actions.
- Daily check-ins.
- Mood, stress, and confidence trends.
- Cigarettes smoked on check-in days.
- Taper target adherence.
- Notification interactions when available.

## Generated Plan Structure

### 1. Plan Summary

A short, user-facing summary of the plan.

Example:

> You smoke most after meals and during work stress. Your first goal is to interrupt those two moments before autopilot starts. This week, keep the 10-minute rescue close after lunch and after work. If you slip, log what happened and keep the quit attempt alive.

Fields:

- title
- summary
- planStartDate
- quitDate
- quitStatus
- readinessStage
- mainReason
- confidenceLevel

### 2. Quit Strategy

Use quit status and confidence to choose the first strategy.

Rules:

- Already quit: default to relapse-prevention mode.
- Ready to quit: default to quit-date preparation and rescue setup.
- Cutting down: default to taper mode unless user explicitly chooses cold turkey.
- Thinking about it: default to preparation mode with low-pressure daily focus.
- Unsure: default to awareness mode, motivation, cost, and trigger mapping.

Strategy outputs:

- `quitMode`: taper, cold turkey, relapse prevention, preparation, or awareness.
- `quitDate`.
- `firstWeekGoal`.
- `dailyFocus`.
- `nextBestAction`.

### 3. Taper Plan

Make taper more nuanced than "reduce by 2 every 3 days."

Inputs:

- Cigarettes per day.
- Confidence level.
- First cigarette timing.
- Previous quit attempts.
- Main challenge.
- Quit date.

Suggested taper logic:

- Low baseline, high confidence: faster taper.
- High baseline, low confidence: slower taper.
- First cigarette within 30 minutes: avoid overly aggressive taper by default.
- Multiple previous attempts or short longest quit: add more preparation days and rescue prompts.
- Main challenge stress or withdrawal: use smaller reduction steps and more replacement activities.

Example taper outputs:

- Starting target.
- Reduction step.
- Reduction interval.
- Protected cigarettes to target first, such as after-meal or boredom cigarettes.
- First cigarette delay goal.
- Daily maximum for the next 7 days.

### 4. Trigger Rules

Generate richer trigger rules from smoking times, emotional triggers, situational triggers, and main challenge.

Rule format:

- Trigger.
- Warning sign.
- Replacement action.
- Backup action.
- Craving-mode prompt.
- Optional reminder timing.

Example:

- Trigger: After lunch.
- Warning sign: Reaching for phone or heading outside.
- Replacement action: Brush teeth or chew gum immediately.
- Backup action: Start 10-minute rescue before leaving the building.
- Prompt: "Delay the outside trip by 10 minutes."

### 5. Craving Rescue Plan

Personalize craving mode before the first craving is logged.

Outputs:

- Primary rescue script.
- Top 3 replacement activities.
- Main reason to show first.
- Activity order based on willingness and trigger match.
- Support fallback.
- Slip recovery prompt.

Example:

> If the urge appears after coffee, drink cold water first, then start the 10-minute timer. If the urge is still high after 3 minutes, switch to walking or box breathing.

### 6. Slip Recovery Plan

Generate a non-shaming recovery plan before a slip happens.

Inputs:

- Previous quit attempts.
- Longest previous quit attempt.
- Main challenge.
- Confidence level.

Outputs:

- Recovery message.
- Slip logging questions.
- Rule update recommendation.
- Whether to preserve quit attempt by default.
- Suggested support action.

Example:

> If you smoke, do not restart the whole plan automatically. Log the trigger, choose the next protected moment, and keep today's next choice small.

### 7. First-Week Daily Plan

Generate seven lightweight daily focuses.

Examples:

- Day 1: Protect the first cigarette after coffee.
- Day 2: Practice one replacement activity before a craving.
- Day 3: Delay the first cigarette by 10 minutes.
- Day 4: Prepare after-meal plan.
- Day 5: Review highest-risk time.
- Day 6: Add one support contact or quitline fallback.
- Day 7: Review what worked and adjust.

The daily plan should vary by quit status:

- Already quit: risk review and relapse prevention.
- Ready to quit: preparation and rescue rehearsal.
- Cutting down: taper target and protected moments.
- Thinking/unsure: motivation and awareness.

### 8. Progress And Savings Plan

Use cost and savings goal to make progress personally meaningful.

Outputs:

- Money saved baseline.
- Cigarettes avoided baseline.
- Savings goal message.
- First savings milestone.
- Dashboard copy.

Example:

> At your current baseline, every smoke-free week puts about $35 toward your trip fund.

### 9. Coach Context

Create a compact plan context that the AI coach can use.

Context should include:

- Quit status.
- Strategy.
- Main reason.
- Confidence.
- Main challenge.
- Top triggers.
- Trigger rules.
- Replacement activities.
- Taper target.
- Slip recovery preference.
- Savings goal.

The coach should use this context to give short, practical responses rather than generic quitting advice.

### 10. Adaptive Plan Updates

After the user starts logging cravings, slips, and check-ins, TeoPateo should generate plan adjustment suggestions.

The app should not automatically rewrite the user's plan without consent. Instead, it should surface specific, evidence-backed suggestions with an action:

> Work stress has appeared in 4 of your last 6 cravings. Add an after-work rule to your plan?

Suggestion types:

- Add trigger rule.
- Update trigger rule.
- Reorder trigger rules by risk.
- Add replacement activity.
- Reorder replacement activities based on what helped.
- Adjust taper pace.
- Add or update risky-window reminder.
- Change today's focus.
- Add slip recovery backup action.
- Add support or quitline prompt.

Each suggestion should include:

- title
- explanation
- evidence summary
- suggested action
- affected plan area
- confidence level
- createdAt
- status:
  - pending
  - accepted
  - edited
  - dismissed

Example suggestions:

- Trigger rule: "Coffee is now your top trigger. Add: drink water, wait 10 minutes, then decide."
- Risk window: "Most cravings happen between 8 PM and 10 PM. Turn on an evening reminder?"
- Taper: "You exceeded your target 3 days this week. Slow reductions from every 3 days to every 5 days?"
- Activity order: "Walking helped in 2 recent rescues. Move it to the top of craving mode?"
- Slip recovery: "Slips are happening after alcohol. Add a weekend backup plan?"
- Daily focus: "Today: protect the after-lunch cigarette."

## Data Model Impact

The current `QuitPlan` can be extended or wrapped with new plan-detail models.

Recommended models:

- `PersonalizedQuitPlan`
  - id
  - quitPlanID
  - readinessStage
  - planSummary
  - firstWeekGoal
  - nextBestAction
  - slipRecoveryDefault
  - generatedAt
  - updatedAt
- `QuitStrategyPlan`
  - strategyType
  - rationale
  - quitDate
  - taperTarget
  - taperStep
  - taperIntervalDays
  - firstCigaretteDelayGoal
- `GeneratedTriggerRule`
  - trigger
  - warningSign
  - replacementAction
  - backupAction
  - reminderHint
  - priority
- `CravingRescuePlan`
  - primaryScript
  - primaryReasonID
  - prioritizedActivityIDs
  - backupAction
- `SlipRecoveryPlan`
  - message
  - reflectionQuestions
  - defaultRecoveryAction
  - preserveQuitAttemptByDefault
- `DailyFocusPlan`
  - dayIndex
  - title
  - action
  - relatedTrigger
- `SavingsPlan`
  - costPerPack
  - cigarettesPerPack
  - savingsGoal
  - firstMilestoneAmount
  - dashboardMessage
- `PlanAdjustmentSuggestion`
  - id
  - planID
  - type
  - title
  - explanation
  - evidenceSummary
  - suggestedAction
  - affectedPlanArea
  - confidence
  - status
  - createdAt
  - updatedAt

Alternative simpler MVP:

- Extend `QuitPlan` with:
  - quitStatus
  - readinessStage
  - planSummary
  - firstWeekGoal
  - nextBestAction
  - firstCigaretteDelayGoal
  - slipRecoveryDefault
  - savingsGoal
  - pendingPlanSuggestions
- Keep generated trigger rules and replacement activities in existing models.

## Generation Rules

The first version can be deterministic and testable. AI can later refine copy, but the plan should not depend on AI to function.

Recommended deterministic logic:

- Rank triggers by:
  - selected smoking time
  - selected emotional trigger
  - selected situational trigger
  - main challenge match
- Pick top 3 trigger rules.
- Pick top 4 replacement activities based on willingness and trigger fit.
- Choose taper speed from baseline, confidence, and dependence proxy.
- Generate daily focus from quit status.
- Generate slip recovery plan from past attempts and main challenge.
- Generate savings milestone from weekly savings estimate.

## Dynamic Adaptation Rules

Add a deterministic `PlanAdjustmentEngine` that runs after meaningful log changes.

Recommended triggers:

- After a craving is saved.
- After a slip is saved.
- After a daily check-in is saved.
- After insights are recalculated.
- When enough new data exists since the last suggestion.

Recommended thresholds:

- Fewer than 3 cravings: avoid strong claims; suggest logging more.
- 3-7 cravings: generate "early pattern" suggestions.
- 8+ cravings: generate stronger trigger and risk-window suggestions.
- 2+ slips with same trigger: suggest a specific slip recovery update.
- 3+ days over taper target in 7 days: suggest slowing taper.
- 2+ successful rescues with same activity: suggest prioritizing that activity.
- Stress 7+ with repeated cravings: suggest stress-specific replacement actions.

Suggested adjustment logic:

- Top repeated trigger without a rule -> suggest adding a rule.
- Top repeated trigger with weak or disabled rule -> suggest updating or enabling it.
- Highest-risk time window with no reminder -> suggest a risky-window reminder.
- Replacement activity repeatedly selected as helpful -> move it higher in craving mode.
- Repeated dismissed craving sessions -> simplify rescue flow or suggest a shorter first action.
- Repeated slips after the same situation -> add a backup action and slip recovery prompt.
- Taper target repeatedly missed -> slow reduction interval or hold current target.
- Confidence trending down -> make daily focus smaller and suggest coach/check-in support.

User approval:

- Suggestions should appear in Today, Insights, or Plan.
- Each suggestion should offer accept, edit, or dismiss.
- Accepted suggestions update the relevant plan model.
- Edited suggestions let the user adjust copy, timing, activity, or taper settings first.
- Dismissed suggestions should not immediately reappear unless the evidence changes.

AI can be used later for:

- Better natural-language plan summaries.
- Personalized coach phrasing.
- Weekly plan adjustment suggestions.

## App Impact

- `OnboardingView` should show a generated plan preview before completion.
- `TeoPateoStore.completeOnboarding` should call a plan-generation service.
- Add a dedicated `QuitPlanGenerator` or `PlanPersonalizationService`.
- Add a dedicated `PlanAdjustmentEngine` for log-driven plan suggestions.
- `PlanView` should render the plan as sections, not just editable settings.
- `TodayView` should show `nextBestAction` and first-week daily focus.
- `TodayView` can show the highest-priority pending plan suggestion.
- `CravingModeView` should use `CravingRescuePlan`.
- `CheckInView` should compare the day against `DailyFocusPlan`.
- `InsightsView` should explain why plan updates are suggested.
- `CoachView` should receive the personalized plan context.

## PlanView UX

The Plan tab should become more than settings.

Suggested sections:

- Plan summary.
- Today's focus.
- Quit strategy.
- High-risk moments.
- Craving rescue plan.
- Slip recovery plan.
- Progress and savings.
- Suggested adjustments.
- Editable settings.

Each section should have an "Adjust" path so the user can correct bad assumptions.

Suggested adjustment cards should show:

- What TeoPateo noticed.
- Why it matters.
- What will change if accepted.
- Accept, edit, and dismiss actions.

## Acceptance Criteria

- Completing expanded onboarding generates a personalized plan summary.
- Plan generation uses quit status, confidence, smoking background, previous attempts, main challenge, triggers, replacement preferences, and cost data.
- Taper settings vary based on user data instead of always using the same defaults.
- At least three prioritized trigger rules are generated when enough trigger data exists.
- Craving mode receives a prioritized rescue plan.
- Slip recovery plan is generated before any slip occurs.
- Today shows a next best action from the personalized plan.
- User logs can generate plan adjustment suggestions.
- Plan adjustment suggestions are evidence-backed and user-approved.
- The app does not silently rewrite meaningful plan settings.
- Accepted suggestions can update trigger rules, replacement activity order, taper settings, reminders, daily focus, or slip recovery plan.
- Dismissed suggestions do not immediately reappear without new evidence.
- Plan tab shows the generated plan in user-facing sections.
- User can edit generated plan assumptions after onboarding.
- The system has deterministic tests for at least:
  - already quit
  - ready to quit
  - cutting down
  - thinking/unsure
  - low baseline/high confidence
  - high baseline/low confidence
  - multiple previous attempts
  - repeated top craving trigger
  - repeated slip trigger
  - repeatedly missed taper target
  - repeatedly successful replacement activity
- Tone remains calm, specific, and non-shaming.
