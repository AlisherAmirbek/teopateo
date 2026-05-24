# Progress Tracking

## Goal

Make progress metrics accurate, mature, and tied to the user's quit attempt.

Progress should reinforce useful momentum without making slips feel like total failure.

## Current Gaps

- Smoke-free days are calculated only from daily check-ins.
- There is no explicit quit-attempt model.
- Cigarettes avoided does not use baseline cigarettes per day.
- Money saved uses a fixed cost per cigarette.
- Health milestones are missing.
- Personal goals are missing.
- Achievements are missing.
- Taper progress is not tracked.
- Slips do not affect progress in a nuanced way.

## MVP Scope

### Quit Attempt Progress

Track an active quit attempt:

- Quit date.
- Started-at date.
- Current status.
- Restart history if the user intentionally restarts.

Smoke-free progress should be based on quit attempt plus daily check-ins/slips, not only consecutive no-smoke check-ins.

### Baseline-Based Metrics

Use user-specific baseline values:

- Cigarettes per day before quitting.
- Cost per pack or cost per cigarette.

Calculate:

- Cigarettes avoided.
- Money saved.
- Smoke-free days.
- Cravings handled.

### Taper Progress

If taper mode is active:

- Show today's target.
- Track whether the user stayed within target.
- Show reduction progress toward quit date.

Avoid punitive copy when targets are missed.

### Mature Achievements

Recognize meaningful milestones:

- First craving handled.
- First smoke-free day.
- First slip recovery.
- First week.
- Money saved threshold.
- Repeated use of the rescue plan.

Achievements should be quiet and adult, not game-like.

## Data Model Changes

Add or extend:

- `QuitAttempt`
- `ProgressBaseline`
- `ProgressMilestone`
- `TaperDayTarget`

Possible fields:

- `baselineCigarettesPerDay`
- `costPerPack`
- `cigarettesPerPack`
- `activeQuitAttemptID`

## Store And Persistence

Recommended store methods:

- `activeQuitAttempt`
- `progressSummary`
- `updateProgressBaseline(...)`
- `todayTaperTarget`
- `recordTaperResult(...)`
- `earnedMilestones`

Progress calculations should be unit-tested against no-history, smoke-free, slip, and taper scenarios.

## App Impact

- `TodayView` shows accurate progress facts.
- `InsightsView` shows progress trends and milestone context.
- `CheckInView` can capture cigarettes smoked or taper result.
- `PlanView` provides baseline settings until onboarding exists.

## Acceptance Criteria

- User-specific baseline drives cigarettes avoided and money saved.
- Progress survives app restarts.
- Slips do not automatically erase the active quit attempt.
- Taper mode shows and tracks daily targets.
- At least three mature milestones can be earned from real history.
- Progress calculations are covered by unit tests.
