# SOC Watch — Hypotheses (need more data / confirmations)

## H4: The strengthened leak-flash effect actually reads as clearly more noticeable in play (0 observations)
On 2026-09-27, the core-leak visual in `DefenseZoneView.swift` was made much bigger/brighter (see
knowledge.md), but this was verified only by code review — a screenshot-polling device-interaction
session (9 captures, ~1-1.3s apart, over ~90s) never landed inside the 0.4s flash window, even though a
leak/reset definitely happened during that session. Status: unconfirmed by direct observation.
Next step if revisited: verify with a screen recording (continuous capture) instead of discrete
screenshot polling, since the flash duration is shorter than this tool's screenshot round-trip time —
or ask a real user/tester whether the hit now feels noticeable during a normal play session.

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

## H3: Rewarded-ad reward-claim rate on offline catch-up, once the AdMob account is approved (0 observations)
Shipped 2026-09-26 (see knowledge.md "Monetization"), but the AdMob account was created the same day and
Google hasn't approved it yet, so no real ad has actually served — `ad_load_failed reason=Account not
approved yet` on every attempt so far. Once approved, the open questions are: (1) what fraction of
sessions that show the "welcome back" banner also see `ad_offered` (i.e. the button is ready/tapped)
vs. staying disabled because no ad preloaded in time, and (2) what fraction of `ad_offered` converts to
`ad_reward_granted` (ad actually watched to completion vs. dismissed early / failed to present). Needs
several real days of usage post-approval, checked via `log stream --predicate 'subsystem ==
"com.socwatch.app"'` filtering for `ad_offered`/`ad_reward_granted`/`ad_load_failed`, before drawing any
conclusion about whether this monetization lever is worth extending (e.g. a second rewarded-ad placement,
or cosmetic theme-pack IAP per the already-identified but unbuilt lever in knowledge.md).

## H2: Fire-feedback flash frequency scales with a layer's Cadence level (1 observation)
On 2026-09-22, a 5-shot burst (~3-4s apart) after boosting EDR Cadence Lv.1→Lv.5 showed the EDR
sensor-halo+beam flash in 2/5 frames, versus 0/5 EDR-specific flashes in a same-length pre-upgrade
baseline burst (baseline showed SIEM flashes instead, unrelated to EDR's cadence). Directionally
consistent with cadence (fire rate) driving flash frequency, but it's one comparison with coarse,
uneven sampling (capture interval > flash duration, so hit rate per burst is noisy) and no control for
the other two layers' concurrent level changes. Needs 2 more independent bursts — ideally with tighter,
more uniform capture spacing — isolating one layer's Cadence change at a time before promoting to a rule.
