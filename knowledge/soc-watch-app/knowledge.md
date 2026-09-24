# SOC Watch — Confirmed Facts

## UI layout (verified 2026-09-22 on iPhone 17 simulator)
- Dark terminal theme (#0B0F14-ish background) renders correctly with no clipping, overlap, or wrong colors.
- Header: shield icon + "SOC WATCH" title + banknote/budget counter top-right — all present and correctly positioned.
- "INCIDENT WAVE N" progress bar with percentage, plus "CAPACITÉ D'ABSORPTION" bar beneath it — both render correctly.
- Central defense zone: 3 concentric rings, teal/orange/gray sensor dots, pulsing lock.shield core icon, red pulsing "incoming alert" dots — all present.
- 3 upgrade cards (EDR / SIEM / Threat Intel), each with a level number and 3 buttons (Cadence, Neutralisation, Budget/alerte) with cost numbers — render correctly.
- Red-bordered "POST-MORTEM" status tile at the bottom — present, correctly styled (not interactive, as expected — it's a passive status readout, never a tap target, per the deliberate resolution of the mockup-vs-spec discrepancy).

## Animation / rendering
- The red incoming-alert dots visibly change screen position across successive screenshot captures — the Canvas/TimelineView animation loop is confirmed running (not frozen/static).
- No crash observed; app process stayed in "Running" state throughout multi-minute observation windows. Console/oslog showed only standard simulator/XPC/AX noise, no app-level errors.
- Tapping an affordable upgrade button visibly increments that layer's level on the next capture — GameEngine.purchaseUpgrade works end to end.

## Balance tuning history (important — read before touching GameEngine.swift's Balance constants)
- **First playtest (initial constants) was far too punishing.** With `baseNeutralizationChance = 0.05`,
  `baseFireInterval = 1.1s`, `baseTravelDuration = 5.0s`, `baseLeakCost = 6.0`, `absorptionCapacityMax = 100.0`,
  and `alertCountGrowthPerWave = 0.6`, a fresh run breached and auto-reset (post-mortem) every ~15-30
  real seconds, capping out around wave 1-3 every single cycle. This initially LOOKED like a stuck
  offline-catch-up loop (wave/budget/EDR-level cycling non-monotonically while the post-mortem bonus
  climbed steadily) but was actually just the intended breach→auto-post-mortem→reset mechanic firing
  correctly and very frequently — each "cycle" was a legitimate, separate, very short run. Lesson:
  non-monotonic wave/budget across repeated observations is NOT automatically a code bug in this app —
  check wave-at-breach and cycle length against expected pacing before assuming a loop/logic error.
- **Rebalanced constants (current, as of 2026-09-22):** `baseAlertCount = 5.0`,
  `alertCountGrowthPerWave = 0.35`, `majorIncidentVolumeMultiplier = 4.0`, `baseTravelDuration = 6.0`,
  `baseFireInterval = 0.9s`, `baseNeutralizationChance = 0.14`, `neutralizationChancePerLevel = 0.015`,
  `absorptionCapacityMax = 140.0`, `baseLeakCost = 4.0`. Verified result: a fresh unupgraded run now
  survives past wave 8-9 and breaches around wave 10 (the first Major Incident/boss wave), roughly a
  3-4x pacing improvement over the original constants. See hypotheses.md H1 — this may still need
  further softening once real usage data exists.
- Persisted `GameState.absorptionCapacityMax` is baked into the save file at breach/save time. Changing
  the `Balance.absorptionCapacityMax` constant does NOT retroactively update existing saves — when
  re-testing balance changes on the simulator, uninstall the app first (`xcrun simctl uninstall <device> <bundleID>`)
  or clear UserDefaults, otherwise you're testing against a stale persisted value.

## Post-rename regression check (Cyber Game 2 → SOC Watch) — verified 2026-09-23 on iPhone 17 simulator
- After the project/target/source-folder/Info.plist rename, app launches straight to the main screen with
  no crash (this was a returning-user save, not a fresh install, so no onboarding sheet appeared — expected
  per the mockup, not a bug). All expected UI present and correctly rendered: dark theme, header (title +
  budget), wave progress bar, absorption capacity bar, 3 concentric defense rings, 3 upgrade cards
  (EDR/SIEM/Threat Intel), POST-MORTEM tile.
- Tick loop and animation loop both confirmed alive post-rename: budget number and alert-dot positions both
  changed across two ~2.5s-apart captures.
- Purchase flow confirmed working post-rename: tapping an affordable Cadence button increased its displayed
  cost immediately (12→16), i.e. GameEngine.purchaseUpgrade still fires correctly.
- Within the same short session a full breach→post-mortem→reset cycle was also observed live (wave 8 at 75%
  absorption → reset to wave ~1-2, all layer levels back to Lv.0, POST-MORTEM permanent bonus ticked to
  +20%, Best wave: 10) — consistent with the already-documented breach/reset mechanic below, not a
  rename-induced bug.
- Only standard simulator/AX/XPC log noise in console output (XPC connection warnings, AXValidations
  category-not-found, duplicate ObjC class warning for WebKit/WebCore accessibility bundles) — no app-level
  errors or crashes.
- Minor leftover from the rename (not a runtime bug, worth fixing when next touching project settings): the
  running app's bundle identifier is still `devplaceholder.D2P9GI00.Cyber-Game-2` even though the product/
  scheme/display name is now "SOC Watch" — the rename changed the project file, source folder, and Info.plist
  names but did not update `PRODUCT_BUNDLE_IDENTIFIER`.

## Fire-feedback visual (sensor pulse + beam flash) — verified 2026-09-22 on iPhone 17 simulator
- Confirmed both pieces of the newly-added fire feedback render correctly: (1) a layer's sensor dot at
  the top of its ring gets a visible brighter/larger halo ring around it, and (2) a thin radial beam
  flashes from that ring's outer edge toward whichever red alert dot it targeted, colored like the
  layer (teal=EDR, orange=SIEM, gray=Threat Intel).
- Both effects were caught mid-flash multiple times across two 5-shot bursts (~3-4s apart per shot due
  to tool-call overhead, wider than the effect's ~0.35s duration) — confirms the flash is real and
  frequent enough to catch even with coarse, non-frame-perfect sampling. Not caught on every single
  capture (expected, since capture interval > flash duration).
- After boosting EDR Cadence from Lv.1 to Lv.5 (3 taps, cost climbed 12→14→18 as level rose), a
  follow-up 5-shot burst showed the EDR-teal halo+beam combo in 2/5 frames, vs 0/5 EDR-specific flashes
  in the pre-upgrade baseline burst (which showed SIEM/orange flashes instead, at SIEM's then-current
  level 3-4). Small sample, but directionally consistent with cadence driving flash frequency per layer.
- No crash, no app-level console errors during either burst; only standard simulator AX/XPC log noise.
- Reconfirms H1's underlying mechanic from a different angle: level numbers climb even without tapping
  buttons between observations spaced >10s apart (e.g. EDR went Lv.3→Lv.6→Lv.9 then reset to Lv.1) —
  this is the wave-progress/breach/post-mortem-reset cycle (see balance tuning history above), not a
  bug. Reconfirms rules.md R1: always sample 3+ points over time, never trust a single before/after pair,
  because level/wave/budget numbers move on their own between captures independent of taps.
