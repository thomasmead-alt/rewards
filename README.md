# Sprout Rewards 🌱

An iPhone/iPad app for children (ages ~6–10) that turns daily responsibilities
and chores into an encouraging reward loop:

1. **Responsibilities** — daily must-dos (brush teeth, make bed…). Completing
   *all* of today's responsibilities **unlocks the day's quests**.
2. **Quests (tasks)** — parent-configured chores that earn **reward units**.
   The child picks their own unit style during onboarding: ⭐️ stars, 💎 gems,
   🪙 coins, ❤️ hearts, or 🐾 paws. Tasks can be once-a-day or repeatable, and
   can optionally require parent approval before units are credited.
3. **Spending** — units convert into:
   - **Real-life rewards** (parent-configured, e.g. screen time, a trip to the
     park). Redemptions wait for parent approval; declining refunds the units.
   - **In-app fun** to keep engagement up: a **virtual pet** to feed, play
     with, and dress up, plus a **sticker album** with themed collections.
     Stickers are bought directly — no random packs.

Everything is stored locally on one shared device. A PIN-protected **Parent
Zone** manages responsibilities, quests, rewards, approvals, balance
adjustments, and history. No accounts, no backend, no ads, no tracking.

Extra motivation: a 🔥 **streak** counts consecutive days with all
responsibilities done, and the pet never suffers — it just gets a little
sleepy if it isn't looked after.

## Project layout

| Path | What it is |
| --- | --- |
| `RewardsKit/` | Swift package with all domain logic (models, rules engine, JSON persistence). Platform-independent; tested on Linux CI. |
| `App/Sources/` | SwiftUI app layer (iOS/iPadOS 17+): onboarding, Today, Fun Zone, Rewards shop, Parent Zone. |
| `project.yml` | [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec that generates the Xcode project. |
| `.github/workflows/ci.yml` | Builds and tests `RewardsKit` on every push. |

## Building the app (on a Mac)

```bash
brew install xcodegen
xcodegen generate
open SproutRewards.xcodeproj
```

Then in Xcode: select the `SproutRewards` scheme, pick an iPhone or iPad
simulator (or your device — set your signing team under
*Signing & Capabilities* first), and Run.

## Running the domain tests

Anywhere Swift runs (macOS or Linux):

```bash
cd RewardsKit
swift test
```

The suite covers the unlock gate, the earn/spend economy, approval and refund
flows, day rollover and streaks, weekday scheduling, the pet and sticker
economies, persistence round-trips, and the PIN gate.

## Design notes

- **Unlock gate**: quests are locked until every responsibility scheduled for
  today's weekday is checked off (days with nothing scheduled are open).
- **Ledger**: every earn/spend is an append-only ledger entry; the balance is
  derived, so history always adds up.
- **Redemptions debit immediately** so a child can't request three rewards
  with the same units; a declined request refunds automatically.
- **Kid-safe choices**: no punishment mechanics, no gambling-style random
  packs, no external links, and the parent PIN keeps configuration away from
  small fingers (it's a child gate, not a security boundary).
