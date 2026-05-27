# Expanded Onboarding Profile And Surveys

## Goal

Replace the lightweight onboarding with a richer first-run flow that builds a more personal quit profile before generating the user's first quit plan.

The flow should help TeoPateo understand:

- Who the user is.
- Where they are in the quit journey.
- Why they want to quit.
- How smoking currently fits into their life.
- What has made quitting hard before.
- What progress and savings should mean to them.

The output should be a first quit plan that feels specific, not generic.

## Product Principle

Ask only for data that changes the plan, coach context, progress calculation, or craving-mode experience.

Do not ask for gender. It is not needed for the current product behavior and would add unnecessary sensitive profile data.

## User Flow

### 1. Profile

Capture lightweight identity and age context.

Inputs:

- Name or nickname.
- Age.

Product use:

- Personalize app copy and coach responses.
- Support adult-oriented tone and safety boundaries.
- Help frame smoking duration and quit history.

Copy direction:

- "What should TeoPateo call you?"
- "Your profile stays focused on your quit plan."

### 2. Quit Intent

Understand the user's current stage.

Inputs:

- Current status:
  - Already quit.
  - Ready to quit.
  - Cutting down.
  - Thinking about it.
  - Unsure.
- Main reason for quitting.
- Confidence level.
- Optional short note: "What made you open TeoPateo today?"

Product use:

- Adjust onboarding language.
- Choose default plan mode and next step.
- Shape the first dashboard recommendation.
- Give the coach better context.

Example outputs:

- Already quit: focus on relapse prevention and risky windows.
- Ready to quit: focus on quit date, trigger rules, and rescue setup.
- Cutting down: default toward taper planning.
- Thinking/unsure: focus on motivation, cost, and low-pressure preparation.

### 3. Smoking Background

Capture the user's smoking history and previous quit attempts.

Inputs:

- When they started smoking:
  - Age started, or approximate years smoking.
- Current cigarettes per day.
- First cigarette timing:
  - Within 5 minutes of waking.
  - Within 30 minutes.
  - Later in the morning.
  - Afternoon or evening.
- Previous quit attempts:
  - None.
  - 1.
  - 2-3.
  - 4 or more.
- Longest previous quit attempt:
  - Less than a day.
  - A few days.
  - A few weeks.
  - A few months.
  - A year or more.
- Main challenge:
  - Cravings.
  - Stress.
  - Habit or routine.
  - Alcohol.
  - Social pressure.
  - Boredom.
  - Withdrawal.
  - Weight gain.
  - Other.

Product use:

- Build more realistic trigger rules.
- Estimate quit difficulty and support intensity.
- Personalize coach context.
- Identify relapse-prevention needs early.

### 4. Trigger And Routine Survey

Go deeper than the current basic trigger selection.

Inputs:

- Common smoking times:
  - Morning.
  - After coffee.
  - After meals.
  - Work breaks.
  - Driving.
  - Evening.
  - Before bed.
- Common emotional triggers:
  - Stress.
  - Anger.
  - Anxiety.
  - Loneliness.
  - Boredom.
  - Celebration.
- Situational triggers:
  - Alcohol.
  - Friends who smoke.
  - Work pressure.
  - Being outside.
  - Phone scrolling.
  - Waiting.

Product use:

- Generate trigger rules.
- Pre-fill replacement activities.
- Schedule risky-window reminders once notifications are enabled.
- Make craving mode activity suggestions more relevant.

### 5. Quit Strategy

Turn intent into a concrete first plan.

Inputs:

- Quit date:
  - Choose date.
  - Already quit.
  - Help me choose.
- Approach:
  - Taper.
  - Cold turkey.
  - Not sure.
- Replacement actions the user is willing to try:
  - Drink water.
  - Walk.
  - Breathing.
  - Chewing gum.
  - Brush teeth.
  - Message someone.
  - Journal.
  - Short task.

Product use:

- Set `QuitPlan.quitDate`.
- Set `QuitPlan.quitMode`.
- Create initial taper target if relevant.
- Generate replacement activities.
- Choose the first daily focus.

### 6. Cost Savings

Capture the baseline for money-saved progress and make the benefit concrete.

Inputs:

- Cost per pack.
- Cigarettes per pack.
- Optional savings goal:
  - Emergency fund.
  - Trip.
  - Family.
  - Health.
  - Debt.
  - Personal reward.
  - Custom.

Product use:

- Calculate money saved accurately.
- Show cigarettes avoided and cost saved on Today.
- Add a motivation-vault item tied to the savings goal.

## Generated Plan

This onboarding flow feeds the richer plan-generation work described in `docs/features/waiting/personalized-quit-plan-generation.md`.

After onboarding, TeoPateo should create a summary such as:

> You smoke most after meals and during work stress. Your first rescue plan is: after meals, brush teeth immediately; during stress, start the 10-minute rescue before going outside. Your first taper target is 8 cigarettes/day. Your reason to protect is "I want mornings without chest tightness."

The generated plan should include:

- Quit status.
- Quit date or next decision.
- Taper/cold-turkey mode.
- Baseline cigarettes/day.
- Cost baseline.
- Primary reason.
- Top triggers.
- Trigger rules.
- Replacement activities.
- First daily focus.
- Coach context summary.

## Data Model Impact

Add or extend persisted models for:

- `UserProfile`
  - nickname
  - age
  - createdAt
  - updatedAt
- `QuitReadiness`
  - status
  - confidence
  - openedAppReason
- `SmokingBackground`
  - ageStartedSmoking or yearsSmoking
  - firstCigaretteTiming
  - previousQuitAttemptCount
  - longestQuitAttempt
  - mainChallenge
- `SavingsGoal`
  - title
  - customText

Extend existing `QuitPlan` or adjacent plan context with:

- quitStatus
- generatedDailyFocus
- readinessStage

Keep gender out of the data model.

## App Impact

- `OnboardingView` becomes a multi-section survey instead of the current short setup.
- `TeoPateoStore.completeOnboarding` should generate a richer plan from survey input.
- `TodayView` can show a more specific first daily focus.
- `CravingModeView` can prioritize activities based on selected triggers and willingness.
- `CoachView` can receive profile, quit intent, smoking background, and main challenge.
- `InsightsView` can compare current patterns against the user's stated main challenge.
- `PlanView` should allow editing core survey-derived fields after onboarding.

## UX Requirements

- Keep the flow calm and lightweight despite richer data capture.
- Use progress indicators and section titles.
- Allow users to skip optional fields.
- Save partial progress if possible.
- Explain why age and background questions are asked.
- Avoid shame-based wording around failed attempts.
- Use "previous quit attempts" instead of "failures."
- Avoid asking for gender.

## Suggested Step Count

Recommended first version:

1. Welcome.
2. Profile.
3. Quit intent.
4. Smoking background.
5. Triggers and routines.
6. Quit strategy.
7. Cost savings.
8. Review and create plan.

If this feels too long in testing, combine profile with quit intent and combine quit strategy with cost savings.

## Acceptance Criteria

- Onboarding asks for name or nickname and age.
- Onboarding does not ask for gender.
- User can identify whether they already quit, are ready to quit, are cutting down, are thinking about it, or are unsure.
- User can add a main reason for quitting.
- User can enter smoking background, including when they started, cigarettes/day, previous quit attempts, longest quit attempt, and main challenge.
- User can enter cost per pack and cigarettes per pack.
- User can optionally define a savings goal.
- Completing onboarding generates a quit plan with trigger rules and replacement activities.
- Generated plan summary is shown before or immediately after creation.
- Survey-derived plan data is persisted.
- Plan-derived data is available to Today, Craving Mode, Insights, and Coach.
- Tone remains specific, calm, and non-shaming.
