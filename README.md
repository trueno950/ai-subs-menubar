# AI Subs

A native macOS menu bar app to track AI subscriptions and API spend:
one icon in the menu bar, a vibrancy panel with your subscriptions,
renewal countdowns, live month-to-date API spend and estimated balances.

Built with Swift + AppKit/SwiftUI. Requires **Command Line Tools only**
(no full Xcode needed). Personal, unsigned app — nothing is published.

## Features

- **Menu bar icon** (`creditcard` symbol): left-click toggles the panel,
  right-click shows Settings/Quit.
- **Subscriptions**: add any service (ChatGPT Plus, Claude Pro, Cursor, …)
  with monthly price (USD), renewal day and icon. Renewal countdown is
  color-coded (red ≤ 1 day, orange within your notice window).
- **Live API spend**: month-to-date spend per provider via the official
  Admin APIs. Optional **estimated balance** = your last top-up − MTD spend.
- **Notifications**: N days before each renewal (at 9:00 local) and once
  per crossing when a balance falls below (or spend exceeds) a threshold.
- **Launch at login** via SMAppService.

## Why "estimated" balances?

OpenAI and Anthropic do **not** expose remaining credit balances through a
public API (their dashboards use browser-only endpoints). What both expose
officially is **cost/usage**:

- OpenAI: `GET /v1/organization/costs` (Admin API key, daily buckets)
- Anthropic: `GET /v1/organizations/cost_report` (Admin API key, cents)

So the app shows live month-to-date spend, and if you record your last
top-up it derives an estimated remaining balance. No scraping, no cookies.

## Setup

1. Build and install:

   ```bash
   ./scripts/install.sh
   ```

2. Create **Admin API keys** (read-only usage/cost scope is enough):
   - OpenAI: <https://platform.openai.com/settings/organization/admin-keys>
   - Anthropic: Claude Console → Admin API keys (`sk-ant-admin01-…`)

3. In the app: Settings → API → enable the provider, paste the key,
   set **Last top-up** (optional, enables estimated balance) and an
   **Alert threshold**, then Save → Test.

## Privacy & security

- Admin keys live **only in your login Keychain** (`SecItemAdd`); the JSON
  config (`~/Library/Application Support/AISubs/config.json`, mode 0600)
  never contains them.
- The only network traffic is HTTPS calls to `api.openai.com` and
  `api.anthropic.com` cost endpoints when you refresh.

## Development

```bash
swift build                 # debug build
swift run AISubsLogicTests  # pure-logic test harness (exit code matters)
./scripts/build-app.sh      # assemble build/AISubs.app
```

Structure: `AISubsCore` (models, renewal/balance math, cost clients,
Keychain, persistence — no UI) · `AISubs` (AppKit/SwiftUI app) ·
`AISubsLogicTests` (assert-based test executable).

> Note: built with Command Line Tools, this project avoids `@State`-family
> property wrappers (they need SwiftUI macro plugins that ship only with
> full Xcode). UI state uses `ObservableObject`/`@Published` instead.
