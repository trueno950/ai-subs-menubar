# Feature: ai-subs-menubar

Native macOS menu bar app to track AI subscriptions and API spend, with vibrancy design.

## Specs

S1: "un icnono en la bara de tara que cuando le de encima me muestre un cuadro con las sucripciones y los saldos" — a menu bar item that opens a popover listing subscriptions and balances.
S2: "quiero un diseno como los de mac, con transparencias, bonito" — native macOS design: vibrancy/transparency materials, rounded cards, SF Symbols.
S3: "ajustable" — user can add/edit/remove subscriptions and configure the app; all persisted locally.
S4: Data model: manual subscriptions + live API data. Research finding: OpenAI and Anthropic expose NO official remaining-credit-balance endpoint. Official Admin APIs expose month-to-date cost only (OpenAI `GET /v1/organization/costs`, Anthropic `GET /v1/organizations/cost_report`). The app shows live month-to-date API spend per provider plus an optional estimated balance = manual last top-up − month-to-date spend. No scraping, no dashboard session cookies.
S5: Services: OpenAI and Anthropic supported out of the box; any number of custom subscriptions (Cursor, Perplexity, etc.). Extended (L7): Z.ai GLM Coding Plan quota via the semi-official `/api/monitor/usage/quota/limit` endpoint (Bearer z.ai API key) — percent used, remaining, reset date; plan price/renewal day stays a manual subscription.
S6: Amounts displayed in USD.
S7: Notifications: N days before each renewal (configurable); alert when estimated balance falls below a threshold (or month-to-date spend exceeds it when no top-up is set).
S8: Personal, unsigned app; must build with Command Line Tools only (no full Xcode). API admin keys stored in the login Keychain, never in the JSON config.

## Tasks

T1 [S1,S2,S8] Scaffold: Package.swift, .app bundle build script, status bar item + vibrancy popover skeleton. → commit 7bee272
T2 [S3,S6] Core models, JSON persistence, Keychain storage, renewal/balance math — tests first. → commit 7b0c71f
T3 [S1,S3,S5] Popover UI: subscription cards, add/edit/delete (custom services), totals. → commit 25e4c74
T4 [S4,S6] OpenAI/Anthropic cost clients, month-to-date aggregation, estimated balance, refresh + cache. → commit 5f2850b
T5 [S7] Notifications (renewals, thresholds) + launch at login. → commit 291fd17
T6 [S1,S2,S8] Polish, README, final functional verification (build, launch, manual checks). → this commit

## Log

L1: "podemos crear un wigget para mis suscriociones de ia, uso mac es dificl? quiero un diseno como los de mac, con transparencias, bonito, ajustable tal vez un icnono en la bara de tara que cuando le de encima me muestre un cuadro con las sucripciones y los saldos"
L2: User decisions (via structured questions): data = "Manual + saldos API"; services = OpenAI (ChatGPT), Anthropic (Claude), Otras; currency = USD; notifications = yes.
L3: Research: no official credit-balance endpoints (OpenAI community forum + Admin API docs; Anthropic claude-code issue #47574 confirms `/v1/organizations/balance` → 404). Design adjusted within S4: live month-to-date spend via official Admin APIs + optional estimated balance from manual top-up. Endpoints pinned: OpenAI `GET https://api.openai.com/v1/organization/costs?start_time&end_time&bucket_width=1d` (Bearer admin key); Anthropic `GET https://api.anthropic.com/v1/organizations/cost_report?starting_at&ending_at` (x-api-key admin key, costs as cent strings).
L4: Environment constraint discovered in T3: Command Line Tools ship no SwiftUIMacros plugin, so `@State`-family wrappers cannot compile. UI state moved to `ObservableObject`/`@Published` with injected models and manual `Binding`s. Also: `StoreKit.Subscription` collides via SwiftUI re-export → model renamed `AISubscription`; FormatStyle `format:` string interpolation works in `Text` but not plain `String` on this toolchain → use `.formatted()`.
L5: Anthropic cost_report item fields are not documented on the docs page; parser decodes `cost` tolerantly (string or numeric, cents). Settings → API → Test surfaces the real response for adjusting if the field name differs.
L6: Final verification: 29/29 logic checks, release bundle build, launch smoke test. Pending manual checks by user: visual look of the panel, notification permission dialog, launch-at-login (requires /Applications install), real API Test with their admin keys.
L7: User asked to connect their GLM (z.ai) plan. Research: GLM Coding Plan exposes a quota endpoint (`GET https://api.z.ai/api/monitor/usage/quota/limit`, `Authorization: Bearer <z.ai API key>`, undocumented but used by cc-switch/CodexBar/pi-glm-usage; payload drifts between TOKENS_LIMIT and CREDIT_LIMIT). Implemented: parser + client + default zai provider with config migration + popover quota display (commit 825f5af). Plan price/renewal day remains a one-time manual entry. App reinstalled to /Applications and relaunched.
