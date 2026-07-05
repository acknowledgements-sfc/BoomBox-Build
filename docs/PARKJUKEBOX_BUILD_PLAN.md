# ParkJukebox — MVP Build Plan (source of truth)

- **Date:** July 5, 2026
- **Product:** iOS app. Verified people at the same park join a session; every phone plays its **own copy** of each song, scheduled to start at the same instant, so many Bluetooth speakers act as one sound system. A shared jukebox queue with voting decides what plays.
- **Working title:** ParkJukebox (final name TBD by owner)
- **Who does what:** Owner plans/verifies in Claude (model: Opus, thinking effort LOW; raise to HIGH only when auditing timing math). Cursor (model: **Auto**) implements. A separate Claude "Verifier" chat reviews every Cursor plan and every phase's git output against this file.

---

## 0. How Cursor must use this file

1. Read this entire file before writing any code. Treat every decision in §2–§4 as **locked**. Do not re-litigate.
2. Work **one task at a time**, in task-ID order, unless the owner names a different task. Announce the task ID before coding.
3. Never begin a task from a later phase while the current phase's verification gate is unmet.
4. Every commit follows §7 exactly and carries a `Task:` trailer with the task ID.
5. The project must build (`xcodebuild build`) before every commit. Unit tests must pass before any phase-closing commit.
6. When a task's description conflicts with reality discovered in code, stop and surface the conflict — do not silently improvise around a locked decision.
7. HITL tasks (human-in-the-loop) are the owner's. Prepare everything for them, then stop and hand off.

---

## 1. Non-negotiable constraints (physics + platform)

These are facts, not preferences. Any plan that violates one is wrong.

- **C1 — No audio capture.** iOS sandboxing forbids capturing audio from other apps (Spotify, Apple Music, AirPlay-in). The app only plays audio it owns: user-imported non-DRM files + the built-in catalog.
- **C2 — No streaming to many speakers.** One phone cannot drive multiple Bluetooth speakers. Sync = every phone plays a **local copy**, scheduled on a shared clock.
- **C3 — Scheduling requires AVAudioEngine.** Synced playback uses `AVAudioEngine` + `AVAudioPlayerNode.play(at:)` anchored to mach host time (`AVAudioTime(hostTime:)`). Never `AVPlayer`/`AVAudioPlayer` for synced tracks. Wall-clock time never drives playback.
- **C4 — Bluetooth output latency is estimated, then trimmed.** Base compensation = `AVAudioSession.outputLatency` + `ioBufferDuration`. Real speakers deviate ±50–150 ms, so a per-speaker manual trim slider is a permanent v1 feature, persisted per audio route. Mic-based auto-calibration is a stretch goal (Phase 5+), not MVP.
- **C5 — MultipeerConnectivity caps at 8 peers per session.** MVP session = 1 host + up to 7 guests. Larger crowds are post-MVP (relay/mesh design later).
- **C6 — The park has no internet.** The core loop (join, queue, transfer, play) must work fully offline. Internet is only required at account creation/sign-in time.
- **C7 — DRM files are rejected.** Import accepts mp3, m4a/aac (non-DRM), wav, flac. Protected files get a friendly explanation, never a crash.
- **C8 — App Review realities.** User-generated content (names, queue activity) requires block + report + community rules screen before App Store submission. Catalog tracks must have written license rights.
- **C9 — Screen-on session.** MVP assumes the app is foregrounded during a session (background audio keeps playing, but MPC messaging degrades in background). Document this in UI copy; do not engineer around it in MVP.

---

## 2. Locked stack

| Layer | Choice | Notes |
|---|---|---|
| Language/UI | Swift 5.10+, SwiftUI | Latest stable Xcode |
| Min iOS | 17.0 | Enables SwiftData; covers the test fleet |
| Audio | AVAudioEngine, AVAudioPlayerNode, AVAudioFile | Host-time scheduling only |
| Nearby | MultipeerConnectivity (MPC) | serviceType `pkjb-sync`; control msgs = Codable JSON (reliable mode); audio files = `sendResource` |
| Clock sync | Custom NTP-style over MPC | Host is master clock; see §5 Phase 1 |
| Local data | SwiftData | Track index, settings, per-route trim values |
| Backend | Supabase | Auth (Sign in with Apple via `signInWithIdToken`), `profiles`, `reports` tables, RLS on. Owner has the Supabase MCP connector in Claude — schema work happens there, then lands here as SQL migration files in `supabase/migrations/` |
| Testing | XCTest for pure logic; real devices for sync (simulators cannot do MPC/BT reliably) | 4-phone fleet |
| Repo | Single repo, `main` + one branch per phase | See §7 |

**Repo layout**

```
ParkJukebox/
  ParkJukebox.xcodeproj
  Sources/
    App/          (entry, navigation, theme)
    Audio/        (engine, scheduler, latency)
    Sync/         (clock sync, protocol messages)
    Session/      (MPC host/guest, peers, transfer)
    Queue/        (queue state machine, votes)
    Library/      (import, SwiftData models)
    Auth/         (Supabase, profiles, JWT cache)
    UI/           (feature views)
  Tests/
  scripts/        (phase_report.sh, build_check.sh)
  supabase/migrations/
  docs/           (DECISIONS.md — one line per deviation, dated)
  PARKJUKEBOX_BUILD_PLAN.md   <- this file
  .cursor/rules/  (four .mdc files, contents in §8)
```

---

## 3. Owner-only (HITL) checklist

Cursor cannot do these. Verifier chat should nag about the next one due.

- [ ] **H1.** Charge and gather 4 iPhones + 4 Bluetooth speakers (needed from Phase 1c).
- [ ] **H2.** Apple Developer Program, $99/yr — needed by Phase 2 (multi-device installs beyond free-provisioning limits) and mandatory for TestFlight in Phase 5. Phase 0–1 can run on free provisioning (3 devices, 7-day certificates).
- [ ] **H3.** Create the Supabase project (do it in a Claude chat via the Supabase connector at Phase 3 kickoff; paste resulting URL + anon key into the repo's `Config.xcconfig`).
- [ ] **H4.** Source and license 15–30 catalog tracks (royalty-free / CC / direct indie licenses, written proof kept in `docs/licenses/`) — Phase 4. This is the owner's marketing lane.
- [ ] **H5.** Brand kit: app icon, palette, type, name decision — Figma (owner has the Figma MCP connector) — Phase 4.
- [ ] **H6.** Recruit 4–6 beta humans + pick a park — Phase 5.
- [ ] **H7.** All field tests marked HITL below (ears + eyes at real distance).

---

## 4. Definition of Done — every task

- Builds clean on device (not just simulator) when the task touches Audio/Sync/Session.
- No force-unwraps in new code; errors surfaced to UI as friendly copy.
- New pure logic (clock math, queue reducer, JWT parse) has XCTest coverage.
- One commit per task (small tasks may share only if the Verifier pre-approved), formatted per §7, `Task:` trailer present.
- `docs/DECISIONS.md` gets one dated line if anything deviated from this plan.

---

## 5. Phases (vertical slices)

> Estimates are for sizing only — they are not deadlines. Modes: **AFK** = Cursor alone; **HITL** = owner at the keyboard/speakers.

### Phase 0 — Rails (repo, rules, scripts)

**Goal:** a repo where every later phase is verifiable.
**Components:** repo, `.cursor/rules`, scripts, CI-lite.

| # | Task | Est. | Deps | Artifact | Mode |
|---|---|---|---|---|---|
| P0-1 | Create Xcode project + repo layout per §2, commit initial scaffold | 2h | — | building app shell, tagged `phase-0-start` | AFK |
| P0-2 | Add the four `.cursor/rules/*.mdc` files exactly as §8 | 1h | P0-1 | rules files in repo | AFK |
| P0-3 | Write `scripts/build_check.sh` (xcodebuild build + test, exit non-zero on failure) | 1h | P0-1 | passing script run | AFK |
| P0-4 | Write `scripts/phase_report.sh` (args: from-tag; prints git log --oneline, diffstat, last test summary, open checklist items scraped from this file's current phase) | 2h | P0-3 | script output pasted into Verifier chat | AFK |
| P0-5 | Copy this plan into repo root + create `docs/DECISIONS.md` | 0.5h | P0-1 | files committed | AFK |

**Verification gate:** `build_check.sh` passes; `phase_report.sh` produces a readable report.
**Acceptance:** owner pastes the Phase 0 report into the Verifier chat and gets PASS.
**Close:** tag `phase-0-done`.

---

### Phase 1 — Sync Magic (tracer bullet: audio + sync + minimal UI end-to-end)

**Goal:** 4 phones + 4 Bluetooth speakers play one file as one sound. Highest risk first; everything else is worthless without this.
**Components:** Audio, Sync, Session (minimal), UI (debug HUD).

**Learning tests first (LT):** tiny throwaway harnesses proving external assumptions before building on them:
- LT-A: `AVAudioSession.outputLatency` values across the 4 speakers (log table).
- LT-B: MPC `sendResource` throughput phone→phone for a 5 MB mp3 (seconds, over peer Wi-Fi).
- LT-C: `play(at:)` actually honors a future hostTime within ±2 ms on-device.

| # | Task | Est. | Deps | Artifact | Mode |
|---|---|---|---|---|---|
| P1-1 | Learning tests LT-A/B/C, results table committed to `docs/DECISIONS.md` | 3h | P0 | measured numbers | HITL (owner runs, Cursor writes harness) |
| P1-2 | AudioScheduler: load bundled test files (music + click track), schedule playback at a given future hostTime, expose `outputLatency` compensation | 4h | P1-1 | unit-tested scheduler + solo-phone demo screen | AFK |
| P1-3 | SyncClock: NTP-style offset over MPC (20 pings, keep min-RTT sample; re-sample every 30 s; expose master↔local hostTime conversion) with XCTests on the math | 4h | P0 | tested SyncClock | AFK |
| P1-4 | Minimal Session: host advertises `pkjb-sync`, guests browse/join, reliable JSON control channel (`PlayCommand{trackID, masterStartHostTime, sampleOffset}`) | 4h | P1-3 | 2 phones exchange PlayCommand | AFK |
| P1-5 | Wire it: host taps Play → both phones schedule same file; per-route trim slider (±300 ms, persisted via SwiftData); debug HUD showing offset, RTT, outputLatency, trim | 4h | P1-2, P1-4 | 2-phone sync demo | AFK |
| P1-6 | File transfer: host `sendResource`s the mp3 to peers before Play enables; progress UI | 3h | P1-4 | guest plays a file it never had | AFK |
| P1-7 | Scale + tune to 4 phones with click track; record trim values per speaker | 3h | P1-5, P1-6 | living-room video, one click | HITL |

**Verification gate:** click track on 4 phones/speakers sounds like **one** click after trim; music shows no audible echo at 2 m spacing; per-track re-anchor keeps drift inaudible across a 4-minute song.
**Acceptance:**
- [ ] 4 phones, 4 speakers, one song, no echo (owner's ears + video)
- [ ] Kill and rejoin one guest mid-song; it re-enters in sync within 5 s (uses `scheduleSegment` from current offset)
- [ ] SyncClock unit tests pass; measured clock agreement < 5 ms on min-RTT samples
**Close:** tag `phase-1-done`.

---

### Phase 2 — The Party (sessions + jukebox queue)

**Goal:** friends cue songs from their own phones; playback never stops between tracks.
**Components:** Queue, Library, Session (full), UI.

| # | Task | Est. | Deps | Artifact | Mode |
|---|---|---|---|---|---|
| P2-1 | Library import: Files picker, DRM/format validation per C7, SwiftData track index with metadata + artwork | 4h | P1 | import flow + library screen | AFK |
| P2-2 | Queue engine: host-authoritative state machine (add, vote-bump, remove, skip, reorder), guests send intents, full-state broadcast on change; XCTests on the reducer | 5h | P1 | tested queue module | AFK |
| P2-3 | Queue + Now Playing UI: shared queue list with votes, progress bar, who-added-it chips | 5h | P2-2 | usable party screens | AFK |
| P2-4 | Prefetch pipeline: next track's file transfers to all peers while current plays; gapless hand-off between tracks | 4h | P2-2, P1-6 | 5-track set plays continuously | AFK |
| P2-5 | Late-joiner flow: join mid-song → receive file + anchor → enter in sync; empty states + friendly errors | 3h | P2-4 | demo video | AFK |
| P2-6 | Host powers v1: skip, remove track, end session | 2h | P2-2 | controls work from host only | AFK |
| P2-7 | Two-couch party test: 3+ people, 5+ tracks, nobody touches the host phone | 2h | all | video + notes in DECISIONS.md | HITL |

**Verification gate:** 30-minute session, zero playback gaps, queue never desyncs (guest and host screens always agree after ≤1 s).
**Acceptance:**
- [ ] Friend adds + upvotes from their phone; order updates everywhere
- [ ] Track N→N+1 with no manual action and no silence gap > 0.5 s
- [ ] Late joiner in sync within 10 s of tapping Join
**Close:** tag `phase-2-done`.

---

### Phase 3 — Trust (accounts, verification, safety)

**Goal:** only verified accounts join or queue; hosts can protect the vibe. (App Review requires the safety set — C8.)
**Components:** Auth, Session (gating), Queue (identity), UI, Supabase.

| # | Task | Est. | Deps | Artifact | Mode |
|---|---|---|---|---|---|
| P3-1 | HITL kickoff: create Supabase project via Claude's Supabase connector; land `profiles` + `reports` migrations (SQL files in repo) with RLS | 2h | — | migrations applied | HITL |
| P3-2 | Sign in with Apple → Supabase session; profile create/edit (display name, avatar seed); cache JWT + JWKS for offline | 5h | P3-1 | sign-in flow on device | AFK |
| P3-3 | Offline join gate: joiner presents cached JWT over MPC; host verifies RS256 signature against cached JWKS + expiry; unverifiable → polite rejection | 5h | P3-2 | park-mode gate demo (airplane-mode test) | AFK |
| P3-4 | Verified badges on peers + queue items; community rules screen on first launch | 3h | P3-2 | badge UI | AFK |
| P3-5 | Safety set: host kick (peer cannot rejoin this session), local block list, report → `reports` table (queued offline, sent when online) | 4h | P3-3 | kick/block/report all demoed | AFK |

**Verification gate:** fresh install cannot join or queue until signed in; airplane-mode phones with cached credentials still join.
**Acceptance:**
- [ ] Unsigned phone is rejected with clear copy
- [ ] Kicked phone cannot rejoin the same session
- [ ] Report lands in Supabase when connectivity returns
**Close:** tag `phase-3-done`.

---

### Phase 4 — The Look (catalog + brand)

**Goal:** feels like a product, not a demo. Owner's home turf.
**Components:** Catalog, UI theme, App/onboarding.

| # | Task | Est. | Deps | Artifact | Mode |
|---|---|---|---|---|---|
| P4-1 | HITL: brand kit in Figma (icon, palette, type, final name) + license 15–30 catalog tracks (H4/H5) | — | — | assets + `docs/licenses/` | HITL |
| P4-2 | Design tokens from Figma → SwiftUI theme (colors, type scale, components); apply across screens | 5h | P4-1 | themed app | AFK |
| P4-3 | Built-in catalog: bundle tracks + manifest (title, artist, license ref); browsable/searchable; queueable like local files | 4h | P4-1 | catalog tab | AFK |
| P4-4 | Onboarding (3 screens: what it is, speaker trim, rules) + app icon + empty states + haptics polish | 4h | P4-2 | first-run flow | AFK |
| P4-5 | Rename target/bundle to final name; screenshot set for TestFlight page | 2h | P4-2 | archive-ready build | AFK |

**Verification gate:** a stranger can install, understand, and host a session without help.
**Acceptance:**
- [ ] Catalog track and local track behave identically in the queue
- [ ] Every license has written proof in `docs/licenses/`
- [ ] Owner signs off on look in a 10-minute review
**Close:** tag `phase-4-done`.

---

### Phase 5 — Park Day (field beta)

**Goal:** survives reality: distance, sun, batteries, strangers.
**Components:** all; telemetry-lite; TestFlight.

| # | Task | Est. | Deps | Artifact | Mode |
|---|---|---|---|---|---|
| P5-1 | Telemetry-lite: local session log (joins, transfers, re-syncs, errors) + one-tap export share sheet | 3h | P4 | exported log file | AFK |
| P5-2 | TestFlight: archive, upload, internal group, beta notes (needs H2) | 2h | P4-5 | build live in TestFlight | HITL+AFK |
| P5-3 | Field protocol doc: distance ladder (2/10/25 m), obstruction test, 30-min endurance, battery notes, sun-readability | 2h | — | `docs/FIELD_TEST.md` | AFK |
| P5-4 | Park test #1 with 4–6 humans; collect logs + notes | — | P5-2, P5-3 | filled protocol + logs | HITL |
| P5-5 | Fix wave from park findings (timeboxed; new bugs become tasks with IDs P5-5a…) | 6h | P5-4 | closed fix list | AFK |
| P5-6 | Park test #2 — the MVP bar | — | P5-5 | video + sign-off | HITL |

**Verification gate / MVP DONE:** 30-minute park session, ≥4 devices incl. one first-time stranger's phone, ≤2 sync complaints, zero crashes.
**Close:** tag `mvp-done`. Celebrate loudly, in sync.

**Phase sequence:** P0 → P1 → P2 → P3 → P4 → P5. (P3-1 backend setup and P4-1 brand work may start any time after P2 — they don't block P2's code.)

---

## 6. Out of scope for MVP (do not build)

Spotify/Apple Music integration · AirPlay output mode · Android · mic auto-calibration · >8 peers · monetization · push notifications · chat.

---

## 7. Git protocol (what the Verifier chat checks)

- **Branches:** `phase-N-<name>` off `main`; merge to `main` only at phase close; tag `phase-N-done`.
- **Commits:** ASCII only. Imperative subject ≤ 72 chars with scope tag from: `[audio] [sync] [session] [queue] [library] [auth] [catalog] [ui] [scripts] [docs]`. Body = why + how to verify, wrapped at 72. Trailer `Task: P1-3` on every commit. No AI attribution of any kind.

```
[sync] add ntp-style offset estimation over mpc

Twenty ping samples per peer; keeps the min-RTT sample and
re-samples every 30s to bound drift. Conversion helpers map
master hostTime to local hostTime for the scheduler.

Verify: SyncClockTests, then debug HUD offset < 5ms on device.

Task: P1-3
```

- **Phase close ritual:** run `scripts/phase_report.sh <last-tag>` → owner pastes output into the Verifier chat → Verifier replies PASS or FIX (≤3 items) → only after PASS: merge + tag.

## 8. Cursor Rules (create verbatim in P0-2)

**`.cursor/rules/00-project.mdc`**
```
---
description: ParkJukebox working agreement
alwaysApply: true
---
- Single source of truth: PARKJUKEBOX_BUILD_PLAN.md. Sections 1-4 are locked.
- Work one task ID at a time; state the ID first; stop at HITL tasks.
- Never add Spotify/Apple Music SDKs. Never capture other apps' audio.
- Offline-first: the park has no internet (plan C6).
- Build must pass (scripts/build_check.sh) before every commit.
- Any deviation from the plan gets one dated line in docs/DECISIONS.md.
```

**`.cursor/rules/10-swift.mdc`**
```
---
description: Swift/SwiftUI style
globs: ["Sources/**/*.swift", "Tests/**/*.swift"]
---
- Swift concurrency (async/await, actors) over callbacks; @MainActor for UI state.
- No force-unwraps or force-try in committed code; errors become user-facing copy.
- Small views; feature state in observable models; SwiftData for persistence.
- Pure logic (clock math, queue reducer, token parsing) lives framework-free and unit-tested.
```

**`.cursor/rules/20-audio-sync.mdc`**
```
---
description: Sync invariants - violating any of these breaks the product
globs: ["Sources/Audio/**", "Sources/Sync/**", "Sources/Session/**"]
---
- Synced playback: AVAudioEngine + AVAudioPlayerNode.play(at:) with AVAudioTime(hostTime:). Never AVPlayer/AVAudioPlayer. Never Date()/wall clock for timing.
- All cross-device times are MASTER hostTime; convert at the edge via SyncClock.
- Compensation order: master start -> local offset -> minus (outputLatency + ioBufferDuration) -> minus user trim.
- Re-anchor at every track start; mid-track joins use scheduleSegment from the computed frame.
- Control messages: versioned Codable JSON, reliable MPC. Files: sendResource only.
- Max 8 peers per session (MPC limit). Enforce at join.
```

**`.cursor/rules/30-commits.mdc`**
```
---
description: Commit format
alwaysApply: true
---
- ASCII only. Subject: [scope] imperative, <=72 chars, no period.
- Body: why + how to verify, wrapped at 72. Blank line before trailers.
- Required trailer: Task: <ID from the plan>. Optional: Fixes:, Refs:.
- One task per commit. No AI attribution, no emoji, no co-author bots.
```

## 9. Connectors & skills map (Claude side)

- **Supabase MCP** — Phase 3: create project, run migrations, inspect rows while debugging auth/reports.
- **Figma MCP** — Phase 4: pull brand tokens/screens into the theming task.
- **No GitHub connector** → verification is paste-based via `phase_report.sh` (already in the plan). If a Git connector is added later, the Verifier may read commits directly.
- **Verifier chat skills:** use `git-commit` skills when judging commit hygiene; `the-blueprint` frame/tasks skills when re-planning; `project-handoff` at the end of every working session so nothing is lost between chats.

## 10. Risk register (top 5)

| Risk | Reality check | Mitigation |
|---|---|---|
| Speaker latency variance | outputLatency lies by up to ~150 ms on some BT speakers | Permanent trim slider (C4); trims persist per route; click-track tuning ritual in P1-7 |
| Clock drift within a song | Phone crystals drift ~ppm-level; minutes-long tracks can smear | Re-anchor every track (20-C rule in 20-audio-sync); 30 s re-sampling |
| MPC range/instability outdoors | ~10–30 m, worse with bodies/obstructions | Field ladder in P5-3; UI copy: "keep phones within ~20 m" |
| App Review (UGC + music rights) | Rejection risk | P3-5 safety set; H4 written licenses |
| Solo-builder stall (owner's known pattern) | Detail-heavy phases | Every task ≤ ~5 h with a visible artifact; Verifier re-engages with the single next task ID when quiet |

— end of plan —
