# Architecture and roadmap

## Version 0.4

Haven is a Flutter client with separate Dart economy rules and a single local store. Android is the first target, Linux is second, and iOS is third. The app runs with a guest save from first launch. Three sample tasks demonstrate rewards, and the town starts with a cottage and zero spendable resources.

A transaction computes the next immutable state, flushes it to a temporary file in the same app support directory, and atomically renames it over the previous save. Changes are queued per running app. Each task occurrence has a stable ledger ID, and purchasing a building saves the cost and plot together. Finance records use integer euro cents. Practice of at least 10 minutes grants a small independent reward subject to the shared daily cap of 60 wood, 30 stone, 20 seeds and 36 town coins. The current save has a version field and no migration yet.

Snapshot storage keeps the offline starter small and easy to inspect. It rewrites the entire save, so operation logging, paged views and SQLite should land before cloud sync or large histories. The current map uses one fixed-size bitmap with depth-ordered building sprites. Larger worlds will need chunk loading and a renderer benchmark before adopting Flame or extending the existing renderer.

## Screens and design

| Screen | Contents |
| --- | --- |
| Town | Original oblique pixel-art mountain valley, pan and zoom, resource totals, today’s tasks, build catalog and confirmed plot placement |
| Tasks | Today, Upcoming, Completed, task editor and archive |
| Planner | Week strip, date picker, due and recurring tasks |
| Money | Month selector, EUR cash flow, spending categories, budget and manual transactions |
| More | Hobbies, weekly minutes, session history, town name, appearance and save status |

Mobile uses a bottom navigation bar. Wide windows use a left rail and a two-column Town view. The map projects existing plot coordinates onto diagonal valley parcels and uses nearest-neighbor scaling. DM Sans sits on silver-gray or graphite panels with mint-gray selection. Dart and the terrain generator use the same oblique grid transform. The main forms and plot picker support keyboard focus and semantics through standard Flutter controls. Screen-reader and high-text-scale testing are still needed on physical phones.

## Version 1 local save

| Record | Fields and invariants |
| --- | --- |
| Save | `version` (1), `townName`, `theme`, and the collections below |
| Task | UUID, title, due date, category, effort, recurrence, notes, archived flag |
| Ledger entry | Operation key, kind, source ID, local day, UTC timestamp, signed wood/stone/seed/coin deltas |
| Building | ID, building definition, district, plot column and row. Older placements default to District 1. The starter home uses the reserved ID `starter-home`. |
| Expansion | Last processed local Monday, total unlocked districts and the last week’s construction report. Older saves start the construction schedule in the week they first open Haven 0.4. |
| Money entry | UUID, description, category, positive cents, income/expense type, transaction date |
| Budget | Month (`YYYY-MM`) → positive cents |
| Hobby | UUID, name, weekly target minutes, archived flag |
| Practice session | UUID, hobby ID, duration minutes, notes, UTC timestamp |

Task grants use `task/{id}/once` for one-off tasks and `task/{id}/{local-date}` for recurring tasks. Hobby grants use the session UUID. One slot per district can hold one building. At each local Monday boundary, Haven calculates the completed share of the preceding week's planned occurrences. Each recurring occurrence counts separately. One-off tasks carry over until completed, and a recorded completion stays in its week if a task is edited or archived. The nonzero share earns one to five buildings, rounded up to the next 20-point band. The app fills vacant land before opening a district, and atomically persists the buildings and last processed Monday together. Earlier weeks with completions are processed at the next launch. The server must use account timezone and server-side rules when cloud sync is added.

## Release updates

The optional HTTPS feed provides a version number, monotonic build number, and SHA-256 with exact byte length for each platform package. Configure only feeds you control or trust. Haven checks on launch, while it is open, and on demand. The updater never reads the game save. Linux stages the verified archive into the next launcher version using a private temporary directory and a version lock. Only after extraction and bundle metadata checks succeed does it atomically replace the launcher pointer. Android verifies the candidate APK's package identity, higher version code and matching signer before opening the system installer.

## Proposed cloud schema

All user-owned rows below carry a stable ID, owner UID, schema version, server revision, created/updated UTC timestamps and an optional deletion stamp where appropriate. Money and AI consent use separate data categories. These rows are a design for the next phase.

| Entity | Additional fields |
| --- | --- |
| UserProfile | displayName, locale, timezone, guestLinkId |
| Preferences | theme, textScale, reducedMotion, defaultCurrency |
| TownSave | name, mapSeed, definitionVersion, activeDistrict, placementRevision |
| Tile | x, y, biomeId, terrainId, districtId |
| BuildingDefinition | catalogVersion, identifier, footprint, cost vector, prerequisites, spriteId |
| PlacedBuilding | definitionId, x, y, upgradeLevel, cosmeticId |
| Unlock | unlockId, sourceOperationId, earnedAt |
| ResourceLedgerEntry | operationId, sourceId, sourceType, localDay, signed resource vector |
| Task | title, notes, effort, category, due date, priority, duration, parentTaskId, projectId, tags, status |
| TaskCompletion | taskId, occurrenceKey, selfReportedAt, evidenceType, rewardOperationId |
| RecurrenceRule | taskId, frequency, interval, weekdays, timezone, until |
| Habit | title, period, target, checkInIds, pausedUntil |
| FocusSession | taskId, startedAt, endedAt, breakMinutes |
| CalendarEvent | title, startsAt, endsAt, timezone, allDay, externalSourceId |
| FinanceAccount | label, currency, openingMinorUnits |
| Transaction | accountId, positiveMinorUnits, currency, direction, category, note, date, recurrenceId |
| Budget | period, category, currency, limitMinorUnits |
| SavingsGoal | name, currency, targetMinorUnits, contributions, dueDate |
| Debt | label, currency, initialMinorUnits, paymentIds |
| Hobby | label, weeklyMinutes, goals, milestoneIds |
| PracticeSession | hobbyId, durationMinutes, notes, attachmentIds, startedAt |
| Project | title, status, position, milestoneIds |
| Milestone | projectId or hobbyId, label, targetDate, completedAt |
| AIConversation | provider, consentVersion, message IDs, expiresAt |
| ConsentRecord | dataCategory, scope, grantedAt, revokedAt, policyVersion |
| SyncOperation | operationId, deviceId, kind, entityId, baseRevision, payloadVersion, payload, outcome |
| NotificationPreference | enabled channels, quiet hours, per-category preferences |

Use Firebase Auth, Firestore and a callable service or Cloud Run gateway. Keep a durable client queue and assign one immutable operation ID per intent. Within a server transaction, deduplicate operation IDs, check account ownership, validate the catalog price, and update the resource ledger and occupancy together. Keep balances derived from the ledger and use separate version checks for editable records. Finish guest-account linking before allowing a second device to submit economic operations. Evaluate Firebase client support on Linux and use a typed HTTPS gateway where a native SDK is unavailable.

`firebase/firestore.rules` denies direct access in this local-only release. Any future Firestore grants must be covered by emulator tests for owner isolation; the economic ledger is server-controlled. Keep app credentials in platform secure storage and service credentials server-side. The local snapshot stores manual finance data in the app’s private directory as JSON. Database-level encryption, export and account deletion are future work.

The AI gateway should be provider-neutral and opt-in, with explicit consent per data category and finance off by default. A response may contain proposed edits with expected revisions. The user sees the proposed actions and confirms before the app submits any mutations. The AI service receives no generic database write endpoint. Budget spending and device sync should continue independently if the AI service is disabled.

## Prioritized backlog

| Order | Work | Acceptance |
| --- | --- | --- |
| 1 | Android device testing, data export and higher text scale | Complete a task and place a building on a device. Force-close, relaunch and see both records. Test TalkBack and keyboard focus. |
| 2 | Linux distribution and desktop input polish | Open the x64 bundle on Arch and Debian. Verify scrolling, keyboard navigation and mouse placement. |
| 3 | iOS toolchain, App Store signing and platform testing | Build unsigned on CI, then sign and validate on a physical iPhone with VoiceOver. |
| 4 | SQLite migration, accounts, sync and cloud backup | Import guest progress; assert two-device retries don’t duplicate rewards, purchases or ledger deltas. Test offline conflicts, backup restore and deletion. |
| 5 | AI, notifications, goals, richer town and planning | Verify consent and confirmation before AI writes, then add reminders, richer estimates, more biomes and projects. |
