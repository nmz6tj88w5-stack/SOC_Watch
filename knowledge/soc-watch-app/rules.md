# SOC Watch — Confirmed Rules (apply by default)

## R1: Verify idle-game state over multiple time points, not just start/end
When verifying SOC Watch's passive-income or wave-progression behavior via device interaction, capture budget/wave/EDR-level at 3+ points spread over at least ~60-90s, not just a single before/after pair. A single before/after snapshot can miss non-monotonic cycling (see hypotheses.md H1) and would incorrectly read as "working" if the two samples happen to land on an upswing.
Basis: confirmed once (2026-09-22) — this cyclic behavior was only detectable because more than two captures were taken. Keep as a testing-methodology rule (not app-behavior rule) since it governs how we verify, independent of whether H1 itself is later confirmed or refuted.
