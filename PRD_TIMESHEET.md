# Loopin — Timesheet & Logbook Module — PRD

Phases 17+ of the Loopin project (continues the macOS menu-bar todo + Pomodoro app already built in Phases 0–16). This module adds: dual timesheets (planned vs. logged), interval-based logging prompts, local activity classification, Google Calendar two-way sync, and cross-device sync (macOS → Android → future web) under one account.

## 1. Problem statement
The user wants to know, honestly, where their time actually goes — not just what they planned to do. Existing tools force a choice: rich time-tracking (Clockify) with no personal-honesty layer, minimal task tools (Google Tasks) with no time dimension, or an all-in-one (TickTick) that never tells you if your day was actually productive. Tocklog gets the honesty layer right (log-after-the-fact, notification-driven) but has no task/calendar integration and leans on paid AI scoring. Loopin's Timesheet module pools the parts that work.

## 2. Users
Single user (the builder) for v1–v2. Designed so the account/sync layer can support additional users later without a rearchitecture, but v1 ships with zero multi-user features (no sharing, no teams).

## 3. Core concepts

### 3.1 Two timesheets, one schema
- **Planned timesheet**: entries created ahead of time (typically at the desk, on macOS), representing intent for a future time block.
- **Logged timesheet**: entries created retroactively, in response to an interval notification, representing what actually happened.
- Both are rows in the same `TimesheetEntry` table, distinguished by `kind`. The calendar view overlays both so planned-vs-actual is visible at a glance.

### 3.2 Interval logging prompts
- User sets a logging interval (2/3/5/10/15/20/25 min — reuses the existing Focus Interval Alarm feature's interval picker).
- On macOS: a native always-on-top panel appears at each interval with a text field, a mic button (on-device speech-to-text), and a Skip button. Stays visible until answered.
- On Android: an ongoing (foreground-service-backed) notification with inline reply (`RemoteInput`), a voice-capture action, and a Skip action.
- Skipping still writes a `skipped` entry (no text) so gaps are visible, never silently missing.

### 3.3 Local activity classification (no per-entry LLM call)
- A local keyword/phrase dictionary maps raw logged text to a category and a productivity label (`productive` / `neutral` / `wasteful`).
- Starter taxonomy:
  | Productive | Neutral | Wasteful |
  |---|---|---|
  | Deep work, Meetings, Learning, Admin, Exercise | Meals, Commute, Rest | Social scrolling, Binge watching, Movie watching, YouTube watching, Gaming, Other unproductive |
- User corrections persist to a personal dictionary override (per-user learning without any model training).
- Unmatched text → `Uncategorized`, editable by the user; never silently mis-filed.

### 3.4 Google Calendar two-way sync
- Two dedicated calendars created via the Calendar API on first connect: **"Loopin Planned"** and **"Loopin Logged"**.
- App writes → push immediately to the matching calendar.
- Edits made directly in Google Calendar → pulled back via `syncToken` incremental sync plus a push-notification webhook (no polling).
- Designed so the existing Google Calendar widget on the user's phone shows both planned and logged blocks without any extra app open.

### 3.5 Cross-device sync
- Central backend (Postgres-based, e.g. Supabase) is the source of truth once more than one device is in use.
- Each client (macOS now, Android/web later) keeps a local SQLite cache for offline-first reads/writes.
- Conflict resolution: last-write-wins on `updatedAt`, per row. Acceptable for a single-user, few-device setup; explicitly not a CRDT system (see architecture research doc for why that tradeoff is fine here).

## 4. Features carried over from competitor research (see prior research doc)
- **From Clockify**: timeline/calendar view of tracked time, timesheet grid, idle detection, reports (daily/weekly totals, category breakdown).
- **From TickTick**: Pomodoro timer, countdown, calendar overlay, desktop widgets, sticky-note-style pinned tasks.
- **From Tocklog**: interval notification logging with type/voice/skip, missed-log flagging, peak-hours-style aggregation (computed locally, not AI-scored, per this iteration's explicit "no LLM per entry" requirement).
- **Explicitly deprioritized**: Clockify's project/client/billing hierarchy, invoicing, team features. Google Tasks contributes only the "keep the schema boring" principle, not distinct features.

## 5. Data model
```
TimesheetEntry {
  id, kind: planned | logged,
  startAt, endAt,
  rawText, inputMethod: typed | voice | skipped,
  category, subcategory,
  productivity: productive | neutral | wasteful,
  gcalEventId?, updatedAt, deviceId
}
ClassificationRule { id, phrase, category, productivity, userDefined: bool }
CalendarLink { provider: google, calendarIdPlanned, calendarIdLogged, syncToken, accountId }
```

## 6. Non-functional requirements
- Offline-first on every client — logging must never block on network.
- No audio leaves the device without explicit user awareness (on-device STT preferred; document clearly if a cloud fallback is ever used).
- No per-entry LLM/API call for classification — local dictionary only, as specified.
- Backend access rules (Row-Level Security or equivalent) must be manually reviewed before any data beyond the builder's own account touches the system.

## 7. Out of scope for v1
- Multi-user sharing/collaboration.
- AI-generated daily briefs/A–F scoring (explicitly rejected by the user for this iteration — logs are classified by script, not LLM).
- Web client (planned after Android, not in this phase set).
- Outlook/other calendar providers (Google Calendar only for v1).

## 8. Known external dependencies / lead-time risks
- Google OAuth app verification for Calendar write scope (days–weeks lead time — start early, independent of build phases).
- Apple Developer Program enrollment (macOS notarization) and Google Play Console enrollment (Android publishing).
- Manual security review of backend access rules before multi-device use.

## 9. Success criteria
- A full day can be planned on macOS in the morning and logged via interval prompts without opening a laptop.
- Planned vs. logged blocks are visible together on the existing Google Calendar phone widget with zero extra taps.
- Classification accuracy on the user's own vocabulary improves visibly within the first week of corrections.
- No logged interval is ever silently lost — every interval produces either a real entry or a visible `skipped` marker.
