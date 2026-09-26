# SOC Watch — Hypotheses (need more data / confirmations)

## H1: V1 balance constants may still breach too early for casual players (1 observation)
After rebalancing (see knowledge.md), a fresh unupgraded run survived to wave 10 — exactly the
first Major Incident (boss) wave — before its first breach, in one ~90s device-interaction session.
Breaching on the very first boss wave could be intended (that's the boss wave's job: stress-test
the current build) or could still be a touch too punishing for a first-time player's retention.
Status: single test session, single random seed (neutralization is a random roll, so outcomes vary
run to run). Needs 2 more independent runs (or real user telemetry once shipped) recording "wave
reached before first breach" before concluding whether Balance constants in GameEngine.swift need
further softening (e.g. raising `baseNeutralizationChance` or `absorptionCapacityMax` further, or
lowering `majorIncidentVolumeMultiplier` below 4.0).
Next step if revisited: run 3+ fresh-install sessions, record wave-at-first-breach each time, compare
against the "vague moyenne atteinte avant brèche" metric once real telemetry exists.

**Action taken 2026-09-24 (single-lever test):** lowered `majorIncidentVolumeMultiplier` from 4.0 to 3.0
in both `Balance.json` and `GameBalance.swift`'s fallback — the most targeted lever since H1's breach
happened specifically on the wave-10 Major Incident (boss) spike, not during normal 1-9 pacing. Deliberately
changed only this one constant (not `absorptionCapacityMax` or `baseNeutralizationChance` at the same time)
so the effect is attributable once telemetry data comes in via the new `AnalyticsService.breach` /
`AnalyticsService.waveReached` events (see knowledge.md). Status: unconfirmed — no post-change session data
yet. Next step: after a handful of real sessions, check via `log show`/Console whether fresh runs now
typically breach past wave 10; if not, try the next lever (raise `absorptionCapacityMax` or
`baseNeutralizationChance`) one at a time, same attribution logic.

## H2: Fire-feedback flash frequency scales with a layer's Cadence level (1 observation)
On 2026-09-22, a 5-shot burst (~3-4s apart) after boosting EDR Cadence Lv.1→Lv.5 showed the EDR
sensor-halo+beam flash in 2/5 frames, versus 0/5 EDR-specific flashes in a same-length pre-upgrade
baseline burst (baseline showed SIEM flashes instead, unrelated to EDR's cadence). Directionally
consistent with cadence (fire rate) driving flash frequency, but it's one comparison with coarse,
uneven sampling (capture interval > flash duration, so hit rate per burst is noisy) and no control for
the other two layers' concurrent level changes. Needs 2 more independent bursts — ideally with tighter,
more uniform capture spacing — isolating one layer's Cadence change at a time before promoting to a rule.
