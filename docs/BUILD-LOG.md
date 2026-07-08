# ParkJukebox — Build Log

> Execution history + durable decisions ONLY. **Not live state** — live state lives in
> `docs/STATUS-FOR-CLAUDE.md`. Never put an open-threads or "what's next" list here.

## 2026-07-07 — Strategist/builder loop installed (setup session)
- **Shipped:** Added the three canonical tracking files (`STATUS-FOR-CLAUDE.md`,
  `BUILD-LOG.md`, this loop's `dispatches/` folder) and `NEW-CHAT-SEED.md` on top of the
  already-built bridge. No app code changed.
- **Decisions made:** Adopted the portable Claude↔Cursor strategist/builder loop.
  `STATUS-FOR-CLAUDE.md` is now the single source of truth for live state; the existing
  `VERIFIER_SEED_PROMPT.md` is retained for the per-round verdict rhythm (not for state).
  `PARKJUKEBOX_BUILD_PLAN.md` §§1–4 remain the locked-decision reference; `DECISIONS.md`
  remains the deviation log.
- **Verification:** Files created against the skill's tracking-templates spec; no build gate
  run (docs-only change).

## Earlier history (from git, pre-loop — reference)
- `53ff7e5` [bridge] Coordination MCP server on Vercel (slice #0 infra built).
- `d85b1cb` [docs] pin supabase agent skills lockfile.
- `8804827` [auth] Config.xcconfig template for supabase keys.
- `4c4eefa` [auth] profiles and reports supabase migration.
- `2053952` [docs] vercel static site for park-jukebox.
- `d3e5d5e` [ui] track xcode workspace metadata.
- Phase 0 scaffold (Xcode project at repo root) committed 2026-07-05 — see `docs/DECISIONS.md`
  for the layout and build-gate deviations recorded at scaffold time.
