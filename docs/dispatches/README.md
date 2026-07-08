# Dispatches

One spec file per slice, named `dispatch-[NN]-[slug]-[YYYY-MM-DD].md`, following the
strategist/builder-loop dispatch template:

what-it-is → what's-already-built → locked-design → Phase A (research/plan) →
Phase B (build) → must-hold → out-of-scope → plan-back checkpoint → go-conditions →
how-Claude-verifies-live

Post each spec to the bridge with `request_build` (include `hotFiles` so the lock-check
protects it). Live state lives in `docs/STATUS-FOR-CLAUDE.md`, not here.
