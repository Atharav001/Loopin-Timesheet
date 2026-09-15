# Loopin — Timesheet & Logbook Module — DESIGN.md

Companion to PRD.md. Covers screens, visual language, and the premium animation system — written so a coding agent can implement without guessing at feel.

## 1. Design principles
- **Native, not web-wrapped.** Every effect in this doc assumes Core Animation/SwiftUI on macOS and Jetpack Compose on Android — no Electron, no WebView-hosted UI. This is a hard constraint, not a preference: the overlay/always-on-top/glow effects specified below are not achievable well in a wrapped web app.
- **Calm by default, alive on completion.** The app should not pulse or glow constantly — that reads as anxious, not premium. Motion is reserved for moments that deserve attention: a completed Pomodoro, a saved log entry, a streak milestone, an incoming interval prompt.
- **One motion vocabulary, reused everywhere.** Three effects, used consistently, beat ten effects used once each: **breathing glow**, **ripple confirm**, **edge-slide nudge**.

## 2. Motion vocabulary

### 2.1 Breathing glow
- Used for: the menu-bar icon while a Pomodoro/focus session is active; the logging panel's border while waiting for input.
- Spec: a soft outer glow (blur radius 12–20pt, opacity 0.25–0.55) on a 2.4–3.0s ease-in-out loop, scaling opacity not size (scaling size reads as "loading," not "alive").
- Color: accent color at rest; shifts toward a warm amber when a logging interval is overdue (missed-log state), signaling urgency without an alarming red.

### 2.2 Ripple confirm
- Used for: task completion checkmark, saved log entry, habit/streak check-in.
- Spec: a single expanding ring from the interaction point, 300–400ms, ease-out, fading opacity to 0 as it expands — not a repeating effect, fires once per action.

### 2.3 Edge-slide nudge
- Used for: the "catch attention even when not looking" requirement — a slim glow bar sliding in from a screen edge with a one-line message, auto-dismissing after 4–6s or on click.
- Spec: slides in over 250ms ease-out, holds, slides out over 200ms ease-in. Must render above full-screen apps (see PRD/architecture doc for the window-level requirement this implies on macOS, and the "draw over other apps" permission this implies on Android).

## 3. Screens

### 3.1 Menu-bar popover (macOS) / home screen (Android)
- Today's planned blocks vs. logged blocks, shown as two thin parallel timeline rails (planned above, logged below) so gaps and mismatches are visually obvious at a glance — this is the single most important view in the app.
- Quick-add field with natural-language parsing ("tomorrow 3pm gym").

### 3.2 Logging prompt panel
- Appears at each interval. Text field (autofocused), mic button, Skip button.
- Breathing glow on the panel border while unanswered; glow shifts to ripple-confirm on submit, then the panel dismisses.
- On skip: a muted, non-judgmental dismiss animation (fade, no ripple) — skipping isn't a failure state and shouldn't be styled like one.

### 3.3 Calendar/timeline view
- Week view with planned and logged blocks overlaid in the same lane, distinguished by fill style (solid = logged, outlined = planned) rather than by two separate lanes, so overlap/mismatch is directly visible.
- Category color-coding consistent with the Section 4 palette below.

### 3.4 Reports view
- Daily/weekly totals, category breakdown (bar), productive vs. wasteful ratio (single stacked bar, not a pie — easier to compare day to day).
- No AI-generated prose in this version — numbers and breakdowns only, per the PRD's "no LLM per entry" scope. Leave a clearly separated space in the layout for a future AI-brief feature without building it now.

### 3.5 Focus/Pomodoro (existing, extended)
- Floating always-on-top timer window (already speced in Phase 10–16) gains the breathing-glow treatment during active sessions and a ripple on completion.

## 4. Visual system
- **Color:** one accent hue for "productive/on-track," a second muted hue for "neutral," a third warm (not red) hue for "wasteful/overdue" — avoid red entirely for wasteful-time framing; this is meant to inform, not shame.
- **Typography:** one display weight for timers/counts, one body weight for everything else — matches the existing Loopin type system from Phase 0–9.
- **Icon-forward rows** for tasks (per the existing Memorigi-style redesign from Phase 10–16) extended to logbook entries: a small category icon precedes each logged entry in list views.

## 5. Accessibility & restraint checks
- Every animated element must have a `prefers-reduced-motion`-equivalent fallback (respect macOS "Reduce Motion" and Android's equivalent system setting) — glow becomes a static highlight, ripple becomes an instant checkmark, edge-slide becomes a static banner.
- No looping animation should run indefinitely in the background when the app is idle and no session is active — battery/CPU cost matters more than ambient polish.

## 6. What NOT to build (scope guard)
- No constant ambient glow across the whole UI — reserve motion for the moments listed above.
- No skeuomorphic effects (no fake paper, no drop-shadow-heavy cards) — flat, calm surfaces with motion doing the "premium" work, not texture.
