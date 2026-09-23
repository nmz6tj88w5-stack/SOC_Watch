# SOC Watch — Player Guide

Welcome to the SOC. Alerts don't stop coming — your job is to keep your
defenses upgraded fast enough to keep absorbing them.

## The Goal

Alerts arrive continuously as numbered **Incident Waves**. Your three
detection layers try to neutralize each one before it reaches the core.
Every alert that gets through drains your **Absorption Capacity**. Run
out of capacity, and you get a **Breach** — the run ends, but you keep a
permanent bonus for next time. There's no clock and no "win" screen: the
pressure comes purely from incoming alerts eventually outpacing your
defenses if you don't keep upgrading.

## The Defense Zone

The rings in the middle of the screen are your perimeter:

- Alerts (small pulsing red dots) spawn at the outer edge and travel
  inward toward the core.
- Each of the three rings belongs to one of your layers — the outer ring
  is checked first, then the middle ring, then the inner ring, right
  before the core.
- The colored dot at the top of each ring is that layer's sensor. When a
  layer fires, it targets whichever alert in its ring is furthest along.
- If an alert crosses all three rings without being neutralized, it
  leaks — your Absorption Capacity gauge drops.

## Your Three Layers

You defend with three fixed layers, each independently upgradeable along
three axes:

| Layer | Role |
|---|---|
| **EDR** | First line of detection on the outer ring. |
| **SIEM** | Correlates and catches what got past EDR. |
| **Threat Intel** | Last line of defense, right before the core. |

Each layer has three upgrade tracks (tap the buttons on its card):

- **Cadence** — how often that layer fires. Higher cadence means more
  chances to catch each alert before it moves past that layer's ring.
- **Neutralize** — the chance that a single shot instantly neutralizes
  the alert. This caps out at a maximum value per layer.
- **Budget/Kill** — how much Budget you earn every time that layer
  neutralizes an alert.

Upgrade costs rise each time you buy — spreading investment across all
three layers (not just one) is generally more effective than maxing a
single layer early, since every layer only guards its own ring.

## Incident Waves & Major Incidents

The bar under the header shows your current **Incident Wave** number and
how far you are through it. Both the number of alerts per wave and how
fast they spawn increase as waves go up — the game gets harder
continuously, not in sudden jumps.

Every 10th wave is flagged as a **Major Incident**: a much larger burst
of alerts arrives at once. Treat it as a checkpoint — if your defenses
can absorb it, you're upgraded well enough for the waves that follow; if
you breach on one, that's a sign to invest more evenly across layers
before pushing further next time.

## Budget

Budget is your currency, and it comes from two sources:

- **Passive income** — accrues automatically over time, and scales up
  the more you've upgraded overall.
- **Per-kill income** — every alert a layer neutralizes pays out
  according to that layer's Budget/Kill level.

Spend it on the upgrade buttons on each layer's card. A greyed-out
button means you can't afford it yet (or, for Neutralize, that it's
already at its maximum — shown as "MAX").

## Absorption Capacity & Breach

The **Absorption Capacity** bar tracks the health of your current run.
It only goes down — when an alert leaks through all three rings
unneutralized. There's no passive regeneration within a run, so the only
way to protect it is to neutralize alerts before they reach the core.

When it hits zero: **Breach Detected**. Your run ends immediately.

## Post-Mortem (what happens after a breach)

A breach automatically triggers a **Post-Mortem** — you don't press
anything for this to happen. Your current budget and layer levels reset
to zero, but you keep a **permanent bonus** based on how far you got: the
deeper the wave you reached, the bigger the bonus applied to every
future run.

The red-bordered "POST-MORTEM" tile near the bottom of the screen isn't
a button — it's a readout of your accumulated permanent bonus and your
best wave ever reached. It briefly highlights right after a breach to
let you know a new bonus just kicked in.

## Offline Progress

Budget keeps accruing (at a reduced rate) while you're away from the
app, based on real elapsed time — up to a cap. When you reopen SOC
Watch, you'll see a "Welcome back" banner showing how much you earned
while gone. Note that waves and combat do **not** progress while you're
away — only passive income does, so your run's wave/layers are exactly
where you left them.

## Tips

- Don't dump every upgrade into one layer — each layer only defends its
  own ring, so a weak inner layer will leak alerts that got past a
  maxed-out outer layer just as easily.
- Cadence and Neutralize both raise your effective kill rate, but in
  different ways — cadence gets you more attempts, Neutralize makes each
  attempt more likely to land. Balance them rather than maxing one first.
- Watch the wave counter as you approach a multiple of 10 — that's your
  next Major Incident. Make sure your upgrades can absorb a much bigger
  burst than usual.
- A breach isn't a failure state to avoid at all costs — it's how you
  earn your permanent bonus. Pushing one more wave than you're
  comfortable with before breaching is often worth it.
