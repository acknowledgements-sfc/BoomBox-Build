# ParkJukebox — Status for Claude (catch-up digest)

> **New chat? Paste `docs/NEW-CHAT-SEED.md` as your first message** — it connects the
> repo folder (not auto-mounted) and runs the session-open ritual. Don't rely on a fresh
> chat finding this file on its own.

> **GENERATED: 2026-07-07 (PT, setup session — strategist/builder loop installed).**
> Supersedes all earlier ad-hoc state. The bridge MCP server (slice #0) was already built
> and committed (`53ff7e5`); this session added the three canonical tracking files, the
> dispatches folder, and the new-chat seed on top of the existing pieces.
> **THIS IS THE SINGLE SOURCE OF TRUTH FOR LIVE STATE / OPEN THREADS.**
> Any open-threads or "what's next" list in any other file (the build plan, `DECISIONS.md`,
> the verifier seed) is stale by default — trust only this section.
> **Session-open check:** if any `docs/dispatches/*` or `docs/*-YYYY-MM-DD.md` is dated
> AFTER the Generated date above, read it and reconcile before working.
> **Session-open check #2 (non-skippable): `git log --oneline -8` + `git status -sb` FIRST**
> whenever the repo is mounted. Git HEAD outranks any prose in any doc.

---

## ⚑ OPEN THREADS — the only authoritative list

**▶ START HERE NEXT:** Resume the app build per `PARKJUKEBOX_BUILD_PLAN.md`. The bridge
(slice #0 infra) is built and committed; the iOS app itself is early — Phase 0 scaffold
committed (`d3e5d5e` xcode workspace, `8804827` auth config). Confirm the current phase/task
ID from the build plan's HITL checklist (§3) and the last commit before dispatching.

**⚑ Slice #0 (coordination bridge) CLOSED — built + committed `53ff7e5`.** Node/TS MCP
server in `bridge/` with the seven tools, bearer auth, `bridge_0001` Supabase migration,
Vitest suites (round-trip, auth, lock-check), and a README with deploy + both clients'
connection strings. **Not yet confirmed deployed/live** — see "Next inbound."

**Build state:**
- Bridge MCP server: built, tested locally, committed. Deploy status to Vercel = UNCONFIRMED.
- iOS app (ParkJukebox): Phase 0 scaffold in place; Xcode project at repo root.
- **Test suites:** bridge Vitest (round-trip/auth/lock-check); `scripts/build_check.sh`
  runs the bridge suite; Xcode build gate pending a machine with full Xcode 16+ (dev machine
  had Command Line Tools only as of 2026-07-05 — see `docs/DECISIONS.md`).

**Migrations live:** `bridge_0001_bridge_tables.sql`, plus a profiles/reports app migration
(`4c4eefa`). Confirm applied state against the live Supabase project before relying on either.

**Known issues / carry-forward (recorded, not blocking):**
- Xcode build gate can't run until a full Xcode 16+ install exists (`sudo xcode-select -s ...`).
- Bridge deploy to Vercel + connector URLs not yet confirmed wired to Claude/Cursor.

**✔ Bridge DB confirmed live (2026-07-07):** BoomBox Supabase project `qznwgfzrhwnhhvrvhtgc`
has all four `bridge_*` tables applied and schema-verified against spec; `bridge_state` seeded
(1 row). Reached + confirmed from the Cowork/Claude Supabase connector.
**✔ `.cursor/mcp.json` written (2026-07-07):** points at `https://park-jukebox.vercel.app/mcp`
with `${BRIDGE_TOKEN}` env reference (token kept out of repo).

**Next inbound (what the human owes to close the loop — 2 steps left):**
1. In Vercel (`park-jukebox` project): set `BRIDGE_TOKEN` (new random secret), `SUPABASE_DB_URL`
   (port 6543 pooler URI), `SUPABASE_SECRET_KEY` (`sb_secret_...`); then `npx vercel deploy --prod`.
2. Add the bridge to Claude as a custom connector: URL `https://park-jukebox.vercel.app/mcp`,
   Streamable HTTP, Bearer `BRIDGE_TOKEN`.
Then smoke-test: fresh chat → paste `NEW-CHAT-SEED.md` → `get_state` returns the seeded snapshot.

**App-phase note:** git HEAD `53ff7e5`. Phase 0 rails done; two things pulled ahead (bridge,
Phase-3 profiles/reports migration). App spine sits at the Phase 0 → Phase 1 boundary. Phase 1
(Sync Magic) starts with **P1-1 (HITL)** — owner measures real BT latency on device. Hardware on
hand: **2 iPhones + 2 speakers** — enough for P1-1…P1-5 (2-device sync demos); the 4-device scale
test (P1-7) waits for more hardware.

---

## Roles / workflow

Strategist (Rob + Claude, in chat) writes dispatches + vets plans; does NOT edit repo code
(DB migrations and these tracking docs are the exception). Builder (Cursor, on Auto) does all
code/tests/commits. **Plan-back checkpoint on every non-trivial slice.** Match Plan vs Agent
mode to the slice: Plan for new surfaces / schema / migrations / locked-behavior paths; Agent
for mechanical, test-guarded, one-file work.

The existing `docs/VERIFIER_SEED_PROMPT.md` describes the round-by-round verifier loop already
in use (paste Cursor plan/report → PASS or FIX ≤3 items → next task ID → watch HITL). That loop
is compatible with this system and stays; this digest is now the single source of truth for
*state*, while the verifier seed governs the *per-round* verdict rhythm.

## Non-negotiables (ParkJukebox — confirm/extend with Rob)

Locked decisions live in `PARKJUKEBOX_BUILD_PLAN.md` §§1–4 — enforce them, never re-litigate.
Deviations are logged one dated line each in `docs/DECISIONS.md`. Project-specific gates:
- Commit hygiene per the plan's §7 and `.cursor/rules/30-commits.mdc`.
- Swift conventions per `.cursor/rules/10-swift.mdc`; audio-sync rules per `20-audio-sync.mdc`.
- **Audio-sync correctness is the core invariant** — any slice touching playback timing needs
  a real-device / real-timing check, not just unit mocks (the app's equivalent of the
  "live-LLM-smoke-call" rule).

## DB / live-state access

Supabase project backs both the bridge (`bridge_*` tables) and the app (profiles/reports).
The strategist (Claude, Cowork side) can reach the live Supabase to apply migrations and
verify writes the builder can't see. Bridge storage uses the server-only `SUPABASE_SECRET_KEY`
— never shipped to a client.

## Resume prompt (paste to pick back up)

> Continue the ParkJukebox build. I'm the strategist/dispatcher — I write slice dispatches and
> vet Cursor's plans; I don't edit repo code except DB migrations and tracking docs. Run the
> session-open ritual: `git log --oneline -8` + `git status -sb` first; then read
> `docs/STATUS-FOR-CLAUDE.md` (this file, single source of truth) and note its Generated date;
> read any dispatch or dated doc newer than that date and reconcile. The bridge (slice #0) is
> built + committed; the iOS app is early (Phase 0 scaffold). Honor the locked decisions in
> `PARKJUKEBOX_BUILD_PLAN.md` §§1–4, the plan-back checkpoint on non-trivial slices, and the
> audio-sync real-timing check on any playback-timing slice. Confirm today's date via the date
> tool before stating it; prepend the current PT time (h:mm) to each message.
