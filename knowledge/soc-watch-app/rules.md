# SOC Watch — Confirmed Rules (apply by default)

## R2: A per-shot probability cap is meaningless if the mechanic allows unlimited repeated rolls against the same target
Any `maxNeutralizationChance`/`maxSomething`-style per-attempt cap only actually bounds a layer's
real-world stop rate if each target gets a *fixed, small number of attempts* from that layer. If
Cadence (or any fire-rate stat) can drive the number of attempts up without bound, cumulative
probability `1 - (1-p)^N` approaches 100% regardless of how low the per-shot cap is — the cap becomes
decorative. When adding or reviewing any RNG-gated defense/attack mechanic in this app, check whether
attempts-per-target are capped (e.g. via `attemptedByLayers`-style tracking) before trusting a
per-shot probability ceiling to actually balance the mechanic.
Basis: confirmed once (2026-09-30) — this exact pattern let EDR alone trivialize the game past wave
50 despite `maxNeutralizationChance = 0.75`; fixed by capping each layer to one attempt per alert
(see knowledge.md "Single-layer late-game trivialization bug", hypotheses.md H6).

## R1: Verify idle-game state over multiple time points, not just start/end
When verifying SOC Watch's passive-income or wave-progression behavior via device interaction, capture budget/wave/EDR-level at 3+ points spread over at least ~60-90s, not just a single before/after pair. A single before/after snapshot can miss non-monotonic cycling (see hypotheses.md H1) and would incorrectly read as "working" if the two samples happen to land on an upswing.
Basis: confirmed once (2026-09-22) — this cyclic behavior was only detectable because more than two captures were taken. Keep as a testing-methodology rule (not app-behavior rule) since it governs how we verify, independent of whether H1 itself is later confirmed or refuted.
