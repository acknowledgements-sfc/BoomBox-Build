# ParkJukebox — New-Chat Seed Prompt

> Paste the block below as the FIRST message in every new chat. A fresh chat starts cold:
> the repo folder is NOT mounted and the session-open ritual does NOT run on its own. This
> seed does both.

---

Continue the ParkJukebox build. I'm the strategist/dispatcher — I write slice dispatches and
vet the builder's (Cursor's) plans; I don't edit repo code except DB migrations and tracking docs.

**First, connect the repo:** request access to the folder
`/Users/robcmartin/Documents/Claude/Projects/Boombox/Boombox-Cursor-Build` — nothing is
readable until it's mounted. Tracking docs live under `docs/` at the mount root.

**Then run the session-open ritual:**
1. `git log --oneline -8` + `git status -sb` FIRST. Git HEAD outranks any doc's "what's open."
2. Poll the bridge (once deployed + connected): `get_state` → `list_tasks`.
3. Read `docs/STATUS-FOR-CLAUDE.md` — the single source of truth. Note its Generated date.
4. Read `docs/BUILD-LOG.md` for history (decisions only).
5. Read any `docs/dispatches/*` or `docs/*-YYYY-MM-DD.md` dated AFTER the Generated date and
   reconcile before doing any work.

Honor the locked decisions in `PARKJUKEBOX_BUILD_PLAN.md` §§1–4 (never re-litigate — flag,
don't deviate), the plan-back checkpoint on non-trivial slices, the Plan/Agent mode rule, and
the audio-sync real-timing check on any playback-timing slice. The Supabase project is reachable
from the Cowork/Claude side for migrations and live verification the builder can't see.

Confirm the current date via the date tool before stating it, and prepend the current PT time
(h:mm) to each message.
