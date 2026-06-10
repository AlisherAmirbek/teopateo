# Minimalist UI and Experience Refinement

## Goal

TeoPateo's visual direction is intentional minimalism — a calm, quiet, non-shaming
companion (see `docs/CORE_IDEA.md`). The problem today is not the direction; it is the
execution. The app is not yet *minimal*, it is *plain*: ornament has been removed, but
density, weak hierarchy, and clutter remain. The result reads as an unfinished prototype
rather than a restrained, premium product.

This doc captures a UI/UX assessment of the current SwiftUI app and the highest-leverage
work to make it feel deliberately minimal and reliably finished — without adding
decoration. It is a refinement track, not a feature expansion.

## Design Principle: Minimal, Not Plain

This distinction is the spine of the work.

- **Minimal** = remove until only the essential remains, then make the essentials exact.
  Hierarchy comes from **type, weight, and negative space** — not from borders, shadows,
  or extra color.
- **Plain** = keep every element but strip its visual weight. Looks sparse, still feels
  busy.
- Minimalism is the *harder* target: with fewer elements there is nowhere to hide, so
  every type size, spacing value, and alignment becomes load-bearing.
- Calibration targets: Things 3, Bear, Oak, I.A. Writer — premium with almost no
  ornament, carried entirely by type and space.

The current app is roughly 40% of the way: ornament is gone, but the discipline that makes
minimalism feel expensive instead of empty is not in place yet.

## Current Assessment

A snapshot, recalibrated to the minimalist goal. Overall: **B− / C+** — a coherent,
well-built MVP that feels like a working prototype, not a product.

| Dimension | Grade | Note |
|---|---|---|
| Accessibility | A− | Labels, identifiers, traits, Reduce Motion — genuinely strong. Keep. |
| Design-system discipline | B+ | Real components and consistent buttons/cards/spacing. |
| Brand & tone | B | Lovely mascot and non-shaming copy, badly underused. |
| Core craving flow | B− | Well-conceived, correct wall-clock timer — overloaded in the moment. |
| Visual minimalism | C+ | Right direction, not committed. Plain, not minimal. |
| Information architecture | C | Five overlapping tabs; the hero action is buried. |
| Onboarding | C | Thorough but seven heavy steps before any value. |
| Motion / feedback / haptics | D | Essentially none — quiet is fine, absent is not. |

## Current Gaps

### Typography has no working hierarchy

In minimalism, type *is* the design, and this is the weakest link. `ScreenHeader` titles
are 31pt heavy (`Components.swift`), card titles are `.headline` bold (~17pt), and body is
`.subheadline` (~15pt) in `QuitTheme.muted` brown. Title and body sit ~2pt apart and both
read low-contrast, so every card repeats the same "bold title / muted caption" texture.
Body text defaulting to `muted` on near-white looks washed out. There is no deliberate
scale and almost no line-spacing intent (`Theme.swift`, and every view).

### Surfaces are "half-cards"

`quietCard()` paints `QuitTheme.paper` on `QuitTheme.background` — a ~1–2% luminance
difference with no border and no shadow (`Theme.swift:22`). It signals "this is a card"
without actually separating anything, which is the muddiness that reads as unfinished. The
design has not committed to either no-card (whitespace + hairlines) or one crisp surface;
it sits in the worst middle.

### Density and weak negative space

Minimalism is defined by what is *not* on screen. Today stacks ~8 cards
(`TodayView.swift`), craving mode shows 6 panels in `rescueContent`
(`CravingModeView.swift`), and onboarding step 2 alone has a segmented picker, two
steppers, and four option sections (`OnboardingView.swift`). Tight padding between many
blocks gives content no room to breathe.

### Information architecture overlaps

Five tabs (`ContentView.swift`): Today, Plan, Check-in, Insights, Coach. "Risk" and
"rescue" are repeated across Today, Plan, and Insights. Check-in is a once-daily action
masquerading as a destination. The single most important action — "I want to smoke" — is
mid-scroll below the mascot (`TodayView.swift:155`) and competes with a second "Start
rescue" button in the risk card.

### Onboarding gates the value

Seven steps (0–6) of steppers, pickers, and tag grids before the user reaches craving
rescue, which is the actual hook (`OnboardingView.swift`). "Skip for now" exists, but Today
then nags with "Finish your quit plan."

### Craving mode is overloaded in the moment

During the acute 10-minute window the rescue screen shows timer + rescue script +
motivation + intensity slider + activity picker + trigger tags, then *another*
slider/picker/tags on recovery. Logging is interleaved with the intervention instead of
following it (`CravingModeView.swift`).

### Feedback is silent (quiet is the goal, not absent)

No haptics on the rescue button, timer start, outcome selection, or save. Beating a craving
— the emotional payoff of the whole product — just dismisses the sheet
(`CravingModeView.swift:550`). Save status is a plain text banner. Minimal feedback should
be *quiet* (subtle motion, a calm state change, the mascot, a success haptic), not absent
and not loud.

### Supporting gaps

- **No dark mode.** The theme is fixed light values. See
  `accessibility-dark-mode-and-localization`.
- **Stock inputs break the aesthetic.** `.roundedBorder` text fields and a hand-built
  `TextEditor` background appear in onboarding, coach, and check-in.
- **Thin empty states.** First-run Insights/Coach are single muted sentences. See
  `ux-feedback-and-error-handling`.
- **Mascot underused.** Seven poses in `images/additional/` are unused; the mascot is
  static furniture on Today and absent from the craving win moment.

## Highest-Leverage Fixes

Ordered by impact per effort.

1. **Establish a type and spacing scale first.** Extend `Theme.swift` from colors-only into
   real tokens.
   - Four type roles with *big* jumps: Display (one per screen, ~28–32 heavy), Section
     (~20 bold, clearly larger than body), Body (~16 regular, `ink` not `muted`), Label
     (~13 faint/tracked). Add deliberate `lineSpacing`. Demote `muted` to genuinely
     secondary text only.
   - 8pt spacing tokens (4 / 8 / 16 / 24 / 32). Big gaps between sections (24–32), tight
     within (8–12). Replace ad-hoc `.padding(.top, 14)` and `spacing: 18` magic numbers.
   - This single step removes most of the "plain" feeling.

2. **Decide surfaces once.** Pick card or no-card and apply it everywhere. Recommended for
   minimalism: drop most card fills, group with whitespace plus the occasional
   `QuitTheme.line` hairline, and reserve a single surface only for truly interactive
   blocks. Update `quietCard()` to encode the decision.

3. **Cut the home screen and the tab count.** Reduce Today to two or three elements
   (greeting/streak, the one next action, the rescue entry). Collapse five tabs to three
   (Today / Plan / Coach); fold Check-in into a Today card and Insights into Plan or Today.
   Remove the duplicated risk/rescue surfaces.

4. **Pin the rescue action.** Make "I want to smoke" persistent and unmissable (e.g. a
   bottom `safeAreaInset`) instead of mid-scroll, and make it the *only* rescue entry point
   on the screen.

5. **Split craving mode into intervene then log.** The in-the-moment view shows only timer
   + one action + one reason. Move intensity, triggers, and notes into the after-the-fact
   log step; the recovered/slipped states already exist to host them.

6. **Add quiet feedback.** Success/selection haptics on rescue start, outcome, and save. A
   calm, earned acknowledgement when a craving is beaten (a subtle scale/fade and a mascot
   pose) — not confetti.

7. **Shorten onboarding's path to value.** Let the user reach craving rescue after the
   minimum (name + reason + a trigger or two) and defer the rest to progressive setup. Stop
   nagging once "Skip for now" is chosen.

8. **Bring the mascot in as a quiet system.** Use the existing poses to react to wins and
   streaks and to appear, calmly, in the craving win moment. One expressive asset, used with
   restraint.

9. **Replace stock inputs.** One minimal, theme-consistent text-field and editor style;
   remove `.roundedBorder` and the hand-built `TextEditor` background.

## Non-Goals (Protect the Minimalism)

- No shadows, elevation layers, gradients, or added ornament to manufacture hierarchy — use
  type and space.
- No loud celebration (confetti, badges, sound). Wins are acknowledged quietly.
- No new accent colors; if anything, use color *less*.
- Prefer removing UI over adding it. This track should make screens shorter, not longer.

## Acceptance Criteria

- A type scale (four roles) and spacing scale (8pt tokens) exist in `Theme.swift` and are
  used across all screens.
- Primary body text meets contrast guidance; `muted` is reserved for secondary text.
- A single surface decision (card or no-card) is applied consistently; no near-invisible
  half-cards remain.
- Today shows at most three primary elements, and the rescue action is persistent and the
  only rescue entry point on that screen.
- Tab count is reduced (target three), or the Today/Plan/Insights overlap is eliminated.
- Craving mode's in-the-moment view shows only timer + one action + one reason; logging is a
  separate step.
- Rescue start, outcome, and save provide haptic feedback, and a craving win has a quiet
  visual acknowledgement.
- Text inputs use one theme-consistent style; no `.roundedBorder` remains.
- The mascot appears in at least the craving win moment and reacts to at least one progress
  event.

## Open Questions

- Card or no-card as the canonical surface?
- Final tab set — three tabs, or keep five but de-duplicate the content?
- Light-only v1 (explicitly declared) or ship dark mode now? Coordinate with
  `accessibility-dark-mode-and-localization`.
- How much of onboarding can move to progressive setup without weakening the first
  generated quit plan?
