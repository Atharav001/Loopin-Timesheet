# Loopin — Timesheet & Logbook Module — Implementation Plan

Continues from Loopin's Phases 0–16 (core menu-bar todo + Pomodoro, already built). Phases below are numbered 17+ so they slot into the existing repo/roadmap.

Legend: 🤖 = safe to hand entirely to the coding agent · 🧑‍💻 = you will need to personally configure/click/approve this — flagged in advance so it doesn't surprise you mid-build.

---

## Phase 17 — Data model foundation (macOS only, local, no accounts yet)
- 🤖 Add `TimesheetEntry`, `ClassificationRule` tables to the existing local SQLite store.
- 🤖 Build the planned-vs-logged calendar/timeline UI (Section 3.1/3.3 of DESIGN.md) reading from local data only.
- **Exit criteria:** you can manually create planned and logged entries in-app and see them on the overlay timeline. No notifications, no classification, no sync yet.

## Phase 18 — Interval logging panel (macOS)
- 🤖 Build the always-on-top logging panel UI + breathing-glow state.
- 🧑‍💻 **Window-level/overlay-over-full-screen-apps debugging.** This is the first likely stall point — the agent's first pass at `NSWindow.Level`/Space-joining behavior often compiles but doesn't actually float over full-screen apps. Budget time to test this yourself across a couple of full-screen scenarios (video call, full-screen browser) before trusting it.
- 🧑‍💻 **Speech-to-text entitlement.** Add the `NSSpeechRecognitionUsageDescription` Info.plist key and the microphone entitlement in Xcode's signing & capabilities tab — this is a manual Xcode step, not something to leave to the agent's generated project file, since misconfigured entitlements fail silently.
- **Exit criteria:** the panel appears at your chosen interval, floats over other apps including full-screen ones, accepts typed/voice/skip input, and writes a `logged` entry.

## Phase 19 — Local classification script
- 🤖 Build the keyword-dictionary classifier + starter taxonomy from PRD.md Section 3.3.
- 🤖 Build the correction UI (tap a mis-tagged entry, reassign, persist as a `ClassificationRule` override).
- **Exit criteria:** typing "watched youtube for an hour" auto-tags as Wasteful/YouTube Watching; correcting a tag once makes the same phrase classify correctly afterward.

## Phase 20 — Reports view
- 🤖 Daily/weekly totals, category breakdown, productive-vs-wasteful stacked bar (DESIGN.md 3.4).
- **Exit criteria:** a week of local test data produces a sensible-looking breakdown.

## Phase 21 — Backend + account (enables cross-device sync)
- 🤖 Stand up the backend (Supabase or equivalent Postgres + Auth), define the schema matching `TimesheetEntry`/`ClassificationRule`/`CalendarLink`.
- 🤖 Add sync logic to the macOS client: local SQLite ↔ backend, last-write-wins on `updatedAt`.
- 🧑‍💻 **Manual security review before this phase is considered done.** Row-Level Security (or equivalent) policies must be checked by you, not just assumed correct because the agent wrote plausible-looking rules — this is the phase where a misconfiguration could leak data if you ever add a second account. Treat this as a required checkpoint, not optional polish.
- **Exit criteria:** logging out and back in on the same Mac restores all data from the backend; a second local test device (or a second local profile) reflects changes within a few seconds.

## Phase 22 — Google Calendar two-way sync
- 🧑‍💻 **Start this in parallel with Phase 21, not after** — create the Google Cloud project, request the Calendar scope, and begin the OAuth verification process now. This has the longest external lead time in the whole plan (days to weeks) and nothing else here blocks on it, so don't discover the wait late.
- 🤖 Implement OAuth flow, calendar creation ("Loopin Planned"/"Loopin Logged"), push-on-write, and `syncToken`-based pull-back with webhook notifications.
- 🧑‍💻 If Google's review requests changes to your privacy policy or consent screen copy, that's a manual back-and-forth, not something the agent can resolve — budget calendar time for it, separate from build time.
- **Exit criteria:** a planned block created in Loopin appears on your phone's Google Calendar widget; moving an event in Google Calendar directly updates Loopin within a normal sync interval.

## Phase 23 — Premium animation pass
- 🤖 Implement breathing glow, ripple confirm, and edge-slide nudge per DESIGN.md Section 2, wired to the moments listed there (session complete, log saved, streak, overdue prompt).
- 🤖 Add `prefers-reduced-motion`-equivalent fallbacks.
- **Exit criteria:** completing a Pomodoro or saving a log entry visibly (but briefly) celebrates the action; the app is calm and static when idle.

## Phase 24 — Android client, core
- 🧑‍💻 Google Play Console enrollment (one-time $25) if not already done.
- 🤖 Build the Android app against the same backend schema: local Room database, sync logic mirroring Phase 21, planned/logged timeline UI mirroring Phase 17/DESIGN.md 3.1.
- 🤖 Port the classification dictionary (export/import as JSON so both platforms share corrections).
- **Exit criteria:** logging in on Android shows the same data as macOS; a log entry made on one appears on the other.

## Phase 25 — Android interval logging
- 🤖 Build the foreground-service-backed notification with `RemoteInput` text reply, voice-capture action, and skip action.
- 🧑‍💻 **Play Console foreground-service declaration.** You'll need to fill out the justification form for the foreground service type before this can be published — required, not optional, on current Play policy.
- 🧑‍💻 **Battery optimization allowlisting.** Test on at least one aggressive-OEM device (Samsung/Xiaomi if available) — if hourly notifications get silently killed, the fix is a manual "disable battery optimization for this app" setting, not a code change. Worth knowing this going in so a missed notification reads as "expected, needs a settings toggle" rather than "the app is broken."
- **Exit criteria:** hourly prompts arrive reliably on a real Android device over a multi-hour test, including with the screen off.

## Phase 26 — Polish, edge cases, and cutover
- 🤖 Handle skipped-entry visualization, offline queue flushing after reconnect, conflict edge cases (near-simultaneous edits on two devices).
- 🧑‍💻 Final read-through of privacy policy copy (needed for both the Google OAuth verification from Phase 22 and Play Store's data-safety section) — this is user-facing legal-ish text worth writing/reviewing yourself rather than fully delegating.
- **Exit criteria:** you're comfortable using this as your daily-driver timesheet across both Mac and phone.

---

## Cross-phase notes
- Phases 17–20 can be built and used solo on macOS with zero backend/account work — deliberately sequenced so you get daily value before the harder sync/OAuth/Android phases begin.
- The two 🧑‍💻-heavy phases with real external lead time (21's security review, 22's Google verification) should be kicked off as early as their prerequisites allow, not left until "everything else is done."
