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

## Monetization & retention infrastructure (as of 2026-09-24)
- No monetization or analytics code exists anywhere in the project: no StoreKit, no IAP, no ad SDK, no
  analytics/tracking calls. The app is currently 100% free with zero revenue instrumentation.
- Offline catch-up already exists and is capped: `GameBalance.swift` (`maxOfflineSeconds: 8*3600`,
  `offlineEfficiency: 0.5`) — applied in `GameEngine.swift:262` (`gained = passiveIncomePerSecond() * elapsed * offlineEfficiency`).
  This cap is a natural, already-present lever for a future "extend offline catch-up" IAP or rewarded ad,
  rather than something that needs to be built from scratch.
- Retention primitives already shipped: one-shot `OnboardingView` (driven by `theme.onboarding`, shown via
  `PersistenceService.hasSeenOnboarding()`), and `NotificationService` schedules exactly one re-engagement
  local notification per backgrounding, choosing among 3 copy variants (post-mortem follow-up, critical
  absorption, generic idle) — see NotificationService.swift:29-49. No daily-login/streak reward system,
  no Game Center integration, no widget/Live Activity exist yet.
- Full skin/logic separation is architectural, not incidental: GameEngine.swift's own header comment states
  "No copy or color is ever hardcoded here — all player-facing content lives in `theme`" (Theme.json). This
  makes cosmetic theme-pack IAP unusually cheap to build relative to typical apps, since the reskin pipeline
  already exists for a different reason (localization/rebrand-proofing).
- `bestWaveReached` and `totalPostMortems` are already tracked in `GameState` (GameModels.swift:45-48),
  making a Game Center leaderboard/achievements integration mostly plumbing, no new game-state design.

## Monetization — rewarded ads on offline catch-up (shipped 2026-09-26)
- First monetization code in the app. `AdsService.swift` (new file, `@MainActor @Observable final class`,
  singleton `AdsService.shared`) wraps the Google Mobile Ads SDK (`GoogleMobileAds` SPM package,
  `https://github.com/googleads/swift-package-manager-google-mobile-ads.git`) for exactly one rewarded-ad
  slot: watching an ad calls `GameEngine.claimOfflineGainBoost()`, which re-adds `lastOfflineGain` to
  `state.budget` and sets `lastOfflineGain = nil` — deliberately reusing that existing field as the single
  source of truth for the "welcome back" banner AND the button's visibility, instead of adding new state.
- **Real AdMob IDs are live** (as of 2026-09-26): App ID `ca-app-pub-3619418801985843~9996006529` in
  `GADApplicationIdentifier` (Info.plist), rewarded ad unit `ca-app-pub-3619418801985843/6188798464` in
  `AdsService.rewardedAdUnitID`. Not Google's public test IDs — swapped in immediately once the user
  created the AdMob app/ad unit, so there's no "swap before submission" TODO left.
- **Non-personalized ads only, deliberately** — `Extras().additionalParameters = ["npa": "1"]` registered
  on every `Request()`. No ATT prompt, no IDFA use, keeps `PrivacyInfo.xcprivacy`'s `NSPrivacyTracking =
  false` valid as-is (the SDK ships its own privacy manifest for its own required-reason API usage, so our
  manifest didn't need any edits for this).
- **The installed Google Mobile Ads SDK version uses the newer Swift-idiomatic API** (no `GAD` prefix,
  e.g. `RewardedAd`, `MobileAds.shared`, `Request`, `Extras`, `FullScreenContentDelegate`, async/await
  `RewardedAd.load(with:request:)` instead of a completion-handler load) — NOT the older
  `GADRewardedAd`/`GADMobileAds.sharedInstance()` API shown in a lot of older tutorials/blog posts. If a
  future session adds more ad SDK code and copies a `GAD`-prefixed snippet from memory or an old doc, it
  will fail to compile with "has been renamed to ___" errors — check the installed package's actual API
  first (`XcodeRefreshCodeIssuesInFile` catches this instantly).
- `AddInfoPlist` accepted `GADApplicationIdentifier` and `SKAdNetworkItems` but reported "key not
  recognized by Xcode" for both (soft warning, not an error — `result: true`, both keys were written
  correctly). Expected: these are third-party/less-common Apple keys Xcode's plist schema doesn't have
  built-in metadata for, not a sign the write failed.
- SKAdNetworkItems list (50 IDs) was fetched live from Google's AdMob iOS quick-start doc via WebFetch
  rather than typed from memory, since it's a Google-maintained list that changes over time.
- **Verified live on the iPhone 17 simulator, 2026-09-26, with the real (not test) AdMob IDs**: on cold
  launch, `offline_gain_applied` and `session_started` fired correctly, and `AdsService` attempted a real
  ad load which failed with `ad_load_failed reason=Account not approved yet` (Google reviews new AdMob
  accounts before serving real ads — expected for a same-day-created account, not a bug). Device
  interaction confirmed the "Welcome back · +14 400 while you were away" banner and the new "Doubler
  (regarder une pub)" capsule button both render correctly below it, with the button correctly shown
  disabled/greyed-out (not the teal accent) while `AdsService.isReady == false`. No crash, no layout
  clipping/overlap. The full "tap button → watch ad → budget doubles → banner disappears" path could not
  be exercised yet since no real ad has served — revisit once the AdMob account is approved (see
  hypotheses.md).

## Attack/defense/leak visual distinction (added 2026-09-27)
- Before this, incoming alerts (attacks) and defense sensor dots were both plain circles, differing only
  by color — a known anti-pattern (relies on color alone, fails for colorblind players) and per user
  feedback, hard to tell apart at a glance even for sighted players. Fixed in `DefenseZoneView.swift`'s
  `drawAlert`: traveling incoming alerts are now diamonds (4-point rotated square via a manual `Path`),
  while defense sensor dots on the rings stay circles. Verified live on simulator across multiple
  captures: diamonds render correctly at various ring positions, sensor dots stayed circular, survived a
  full breach/post-mortem/reset cycle without shape regressions.
- Also strengthened the "leak" visual (an alert reaching the core unneutralized — the only event that
  actually costs `absorptionCapacity`, see `GameEngine.resolveLeaks`). It previously used the exact same
  thin 2pt stroked-ring treatment as a per-layer neutralize burst, just centered on the core instead of
  the ring — easy to miss among the sensor pulses/beams. Now fills a radial-gradient flash across ~85% of
  the defense zone plus a much bigger/thicker (24-84px, 4pt) shockwave ring, reusing the same
  `.radialGradient` technique `drawCore`'s danger glow already used elsewhere in this file.
- **Could not visually confirm the leak flash directly** — it fades over the same 0.4s `flashDuration`
  window as everything else in this view, and screenshot-polling round-trip (~1-1.3s per capture) is
  strictly longer than that window, so a burst of 9 captures over ~90s of real gameplay (which did include
  a full absorption-depletion reset, i.e. at least one leak definitely fired) caught zero leak-flash
  frames — a sampling-rate limitation, not evidence the change doesn't work. Confidence is based on code
  review (identical Canvas/`radialGradient` pattern already verified working in `drawCore`) rather than a
  direct screenshot catch. If this ever matters enough to verify directly, screen-record instead of
  polling screenshots — see hypotheses.md H4.

## Full code review — architecture, code quality, security (2026-09-27)
- **No `try!`, no `print(`, no `as!`, no `fatalError`, no bare force-unwraps** anywhere in `SOC Watch/SOC Watch/*.swift` (verified via project-wide grep). Error handling consistently uses `guard`/optional-chaining/`try?` with graceful fallbacks.
- **Value vs reference types are used correctly**: `GameState`, `LayerState`, `GameBalance`, `ThemeConfig`, `IncomingAlert`, `FireEvent` are all `struct`; only `GameEngine` and `AdsService` (both own identity/mutable shared lifecycle) are `final class`. No unnecessary classes.
- **Persistence is UserDefaults+JSON for `GameState`** (`PersistenceService.swift`) — correct choice, not a security gap: the persisted data is game progress only (budget/wave/layer levels), never PII or credentials, so Keychain is not warranted here.
- **No network/backend code owned by the app** — the only network traffic is the Google Mobile Ads SDK's own ad-request/consent calls (HTTPS, managed by the SDK). No custom `URLSession`, no `NSAppTransportSecurity`/ATS exceptions in `SOC-Watch-Info.plist` (default secure ATS applies). SSL pinning is correctly *not* implemented — pinning a third-party ad SDK's own endpoints is impractical and not a real gap.
- **UMP/GDPR consent flow in `AdsService.requestConsentAndStart()` is implemented correctly**: gathers consent before calling `MobileAds.shared.start()`, checks `ConsentInformation.shared.canRequestAds` first, uses `npa=1` (non-personalized) — consistent with `PrivacyInfo.xcprivacy`'s `NSPrivacyTracking = false`.
- **Architecture gap — singleton/static services called directly from Views, no protocol abstraction**: `AdsService.shared`, `NotificationService`, `AnalyticsService`, `FeedbackService` are all called directly from `ContentView.swift` and `DefenseHUDView.swift`'s `DoubleOfflineGainButton`, with no injected protocol/interface. Fine at the current size, but blocks unit-testing `ContentView`'s side-effect wiring and will need a DI seam (protocol + injected instance, e.g. via `@Environment`) if tests are ever added. See hypotheses.md H5.
- **`GameEngine.swift` is a single 342-line class** combining wave configuration, combat resolution, economy, prestige/breach, and persistence orchestration — no sub-system split. Not a bug today, but a scaling risk: as content grows this file will become the main source of merge conflicts / cognitive load. Natural future split: `WaveSystem` / `CombatResolver` / `EconomySystem` / `PrestigeSystem` behind a slim `GameEngine` facade.
- **`PersistenceService.load()` swallowed decode failures silently** (`try? JSONDecoder().decode(...)`, returned `nil` on any failure) with **no versioning/migration strategy** despite the storage key being named `com.socwatch.gamestate.v1`. If a future `GameState` field is added without a default value, an old save fails to decode and the game silently falls back to `.initial()` — a real returning-user would lose all progress with no error surfaced. **Fixed 2026-09-27**: `load()` now uses `do`/`catch` and calls a new `AnalyticsService.saveDecodeFailed(reason:)` (logged at `.error` level) before returning `nil` — the save is still unrecoverable (no migration logic added, that's a separate, larger task), but the failure is now visible in Console/`log stream` instead of invisible. Verified via `BuildProject` (builds clean) and `XcodeRefreshCodeIssuesInFile` on both changed files (no diagnostics). Not yet exercised against a real corrupt/old save on device — if this ever needs re-verification, corrupt the UserDefaults blob for `com.socwatch.gamestate.v1` on the simulator and confirm `save_decode_failed` appears in the log stream.
- Same silent-swallow pattern (still unfixed, out of scope for the above fix) exists in `GameBalance.loadBundled()` and `ThemeConfig.loadBundled()` — a bad edit to `Balance.json`/`Theme.json` is silently ignored with zero signal, which has already caused confusion during past balance-tuning sessions (nothing logs *why* the fallback was used). This was recommendation #2 in the 2026-09-27 review, not yet implemented.
- **`GameEngine.majorIncidentEveryN` is a non-private `var` defaulting to 10, never mutated anywhere in the codebase** (confirmed via grep) — dead mutability surface on an otherwise well-encapsulated class (most other engine state is `private(set)`).
- **Client-side-only economy is currently zero-risk but is a future cheating vector**: `Balance.json`/`Theme.json` ship as plain readable JSON in the bundle, trivially editable via IPA repackaging. Irrelevant today (single-player, local-only, no leaderboard/IAP wired to these values yet), but becomes a real integrity concern the moment a Game Center leaderboard or real-money IAP is wired to `budget`/`bestWaveReached` (both already identified as unbuilt future levers, see "Monetization & retention infrastructure" above).

## Local analytics instrumentation (added 2026-09-24)
- `AnalyticsService.swift` (new file, `os.Logger`, subsystem `com.socwatch.app`, category `analytics`) is
  the first telemetry in the app — purely local, no network, no third-party SDK, no PII. All interpolated
  values are marked `privacy: .public` deliberately so they're readable in Console.app / `log stream
  --predicate 'subsystem == "com.socwatch.app"'` during dev/TestFlight sessions instead of being redacted.
- Events wired: `session_started` / `session_ended` (duration, from `ContentView`'s `scenePhase` handler —
  NOT from `.task`, see below), `wave_reached` (from `.onChange(of: engine.state.currentWave)`), `breach`
  (wave/points/multiplier, from the existing `lastBreachSummary` onChange), `offline_gain_applied` (from
  the `.active` scenePhase branch after `applyOfflineProgress`), `reengagement_scheduled` (reason +
  delay, logged inside `NotificationService.scheduleReengagement`'s three branches), `onboarding_completed`.
- **Gotcha found and fixed during verification:** originally logged `session_started` from both `.task`
  (view-appear) and the `scenePhase` `.active where old != .active` branch — on a real cold launch in the
  simulator, SwiftUI's `scenePhase` transitions through `.active` almost immediately after the view
  appears, so *both* fired and double-counted every session start. Fixed by removing the `.task` call and
  keeping only the `scenePhase` one; verified via `RunProject`/`GetConsoleOutput` that a fresh launch now
  logs exactly one `session_started` (plus `offline_gain_applied`, which is pre-existing behavior that also
  fires on cold launch, not just resume-from-background — worth remembering if `offline_gain_applied`
  counts are used later to gauge "player returned after being away," since cold launches count too).
- Verified live on simulator: `wave_reached` fired correctly as an in-progress run advanced waves, and
  `offline_gain_applied`/`session_started` fired correctly on launch. `session_ended`/breach were not
  live-verified this session (would need a real backgrounding or a full breach cycle, not just a forced
  process stop) — the code path directly mirrors the already-verified `engine.persist()` call in the same
  `scenePhase` branch, so risk is low, but flag this if a future session wants to close the loop.
