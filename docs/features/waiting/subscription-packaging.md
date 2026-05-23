# Subscription Packaging

## Goal

Define TeoPateo as a subscription quit companion, with the most valuable relapse-prevention tools in the paid package.

The app should feel like ongoing support through cravings, slips, restarts, and relapse prevention, not a fixed challenge that the user can fail.

## Packaging Principle

Craving mode belongs in the paid package because it is the clearest expression of the product promise: help at the exact moment the user is about to smoke.

Free users should still receive basic quit support and trustworthy external resources. The app should not use shame, panic, or emergency pressure to force conversion.

## Free Tier

- Basic onboarding.
- Basic quit plan.
- Daily check-in.
- Basic progress dashboard.
- Quitline and professional support prompts.

## Paid Package

- Full craving emergency mode.
- Adaptive slip recovery after a smoked craving.
- Personalized trigger insights.
- Risky-window reminders.
- AI coach for craving support and plan refinement.
- Support-circle actions and preset messages.
- Motivation vault.
- Full craving, slip, and check-in history.

## Craving Mode Gate

Free users should see the craving-mode entry point so the product value is clear, but opening the full guided rescue should require an active subscription.

The free-state screen should:

- Explain that craving mode is part of the paid quit support package.
- Avoid implying the user failed or waited too long.
- Offer a clear upgrade action.
- Keep quitline and professional support resources accessible.
- Allow the user to return to the basic quit plan or check-in.

Paid users should enter craving mode directly from the dashboard.

## Copy Direction

Use journey-based language:

- "Stay supported through cravings, slips, and restarts."
- "Your plan adapts when life happens."
- "Get guided support before the craving wins."

Avoid challenge-based language:

- "Complete 30 days."
- "Do not break your streak."
- "Start over."
- "You failed."

## Implementation Notes

Add an entitlement model before building payment flows:

- `SubscriptionStatus`
- `Entitlement`
- `isCravingModeUnlocked`

During prototype work, this can be controlled by local state. Production payment implementation should use StoreKit and server-verified entitlement state before real launch.

## Acceptance Criteria

- Free and paid tiers are visible in the product documentation.
- Full craving mode is treated as a paid feature.
- Free users have a non-shaming locked-state path from the craving entry point.
- Quitline and professional support prompts remain available without payment.
- A slip during paid use updates the quit journey instead of making the subscription feel wasted.
