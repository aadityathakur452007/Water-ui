# Progress Tracker

Update this file after every meaningful implementation change.

## Current Phase

**Phase 1 — Water Delivery Repurpose (APPROVED, in progress on `feature/water-repurpose`)**

Repurposing the FlutterShop template into a water delivery customer app.
Repo: fresh `git init` in `water-delivery-app` (copy of template, no old history);
`main` = template snapshot; all work on `feature/water-repurpose`.

## Current Goal

Phase 1: models + mock repos + Home + Shop + Product Detail + Cart/Checkout +
Orders list + 4-tab nav + water-blue theme + ₹ everywhere. Phase 2 (later):
order-type screen, subscription config/mgmt, account additions, search, notifications.

## Completed

- **Fresh repo + rename (2026-09-24)** — old `.git` dropped (history + origin
  `abuanwar072` gone, as approved). OS lock prevented in-place rename, so the tree
  was copied to `C:\Users\Hp\water-delivery-app` (excluding `.git`), fresh
  `git init`, root commit on `main`, branched `feature/water-repurpose`.
  Old folder `E-commerce-Complete-Flutter-UI` still on disk — user deletes manually.
- **Spec approved** — `Feature_docs/water-repurpose/spec.md`: phased scope, catalog
  (20L ₹60, 15L ₹50, 10L ₹40, 1L×12 ₹120, 500ml×12 ₹90, fee ₹10, Cash+UPI),
  water-blue `0xFF1B7BD6` primary.
- **Theme** — `constants.dart` primary + material shades + purpleColor →
  water blue; typography/spacing untouched.
- **Models** — `ProductModel` extended (id, capacity, unit, container, waterType,
  available, `priceLabel` ₹); water catalog (6 items); new `cart_model.dart`
  (`Cart`, `CartItem`, `inr()`), `order_model.dart` (Order/OrderItem/OrderType/
  OrderStatus/DeliveryAddress), `subscription_model.dart` (data-prep for Phase 2).
- **Repositories (mock/local)** — `ProductRepository` (all/byId/byCategory/search),
  `OrderRepository` (ongoing/past/lastOrder/placeOrder), `SubscriptionRepository`
  (activeDelivery). No hardcoded product values in widgets.
- **Home** — address header, water search hint → search screen, 5 water category
  chips, stepper product cards (₹), Order-again, next-delivery card, one small
  promo banner. Deleted fashion sections
  (flash_sale, best_sellers, most_popular, offers_carousel, popular_products).
- **Shop** — `DiscoverScreen` shows Water Jars/Cans/Bottles/Packaged Water.
- **Product detail** — capacity/container/type spec table, qty stepper, Continue →
  cart; fashion tiles (colors/sizes/returns/reviews) removed. Router accepts a
  product id string (legacy bool fallback kept for bookmark).
- **Checkout** — real cart: summary ₹, fee ₹10, one-time/regular cards, address,
  Cash/UPI (`RadioGroup`), Place Order → inline success view (#WD-…, View Order,
  Back to Home). `CartButton`/`UnitPrice` now render ₹.
- **Orders** — ONGOING/PAST tabs from repo, status dots, View sheet with
  `OrderProgress` timeline reuse.
- **Nav** — `EntryPoint` 4 tabs: Home, Orders, Shop, Account (Bookmark/Cart tabs
  removed; routes still exist).
- **Images** — `NetworkImageWithLoader` renders bundled `assets/` art;
  new `water_jar.svg` / `water_bottle.svg` placeholders until real photography.
- **Verify** — `flutter pub get` ✓, `flutter analyze` 0 errors / 0 warnings.
  APK build impossible here (no Android SDK); web not configured. Pre-existing
  `info` lints in untouched files left alone.

## Completed

- **Root `AGENTS.md` added** — auto-loaded by agents; contains the 3 non-negotiable rules, file reading order, and failure consequences so agents see the protocol even if they never open `Agent.md`.
- **`Agent.md` rewritten for enforceability** — mandatory routine (read context → classify → load skill → design-first → implement → sync context → verify), required response status block, hard approval gate in the design workflow, context sync protocol, expanded pre-exit checks.
- **`context/flow.md` added** — Mermaid architecture/user-flow/request-response diagrams, function call maps, route + API tables, mandatory update protocol.
- **`context/decision.md` added** — append-only ADR-style decision log with template, index, and update rules.
- **`Scaffold.py` removed** — npm/create-app provides boilerplate; the `folder-structure` skill's canonical trees are now the source of truth, materialized by hand.
- **References updated** — `SKILLS.md`, `README.md`, `.agents/AGENTS.md`, `.agents/folder-structure/SKILL.md`, `context/ai-workflow-rules.md` all updated to remove Scaffold.py and point to the canonical trees + new context files.
- **Skills bootstrap installed (2026-09-24)** — ran `python Skills.py --yes`: npm/npx verified (11.19.1), `package.json` auto-created (node sidecar in Flutter repo), 36 skills installed into `.agents/skills/` (8 GSAP + 1 hallmark + 13 taste + 13 emilkowalski + 1 impeccable engine). Then ran `specify init . --integration opencode --force --non-interactive --script ps` (specify-cli 1.0.5.dev0 already present via uv 0.12.5): created `.specify/`, `.opencode/`, `.codex/`, speckit workflow commands available (`/speckit.constitution`, `/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.implement`). Note: `uv tool install specify-cli --from git+...@latest` fails (`@latest` is not a git ref) — used pre-installed CLI instead.

## Next Up

1. **Unblock Actions** (user): verify GitHub email, check Settings → Billing for
   Actions minutes, then push any commit or run CI via `workflow_dispatch`.
2. Phase 2 app work (order-type, subscriptions, account, search, notifications).
3. Follow-ups: unique `applicationId` (still `com.example.shop`), release signing
   secrets + gated release workflow, delete `ci-probe` repo + old local folder.
4. Real water product photography to replace `water_jar.svg`/`water_bottle.svg`.
5. Fill remaining `context/*.md` template placeholders; run `/speckit.constitution`.
6. Delete old folder `E-commerce-Complete-Flutter-UI` (user, after verifying copy).

## Open Questions

- Real prices for 15L/10L/packs were defaulted (₹50/₹40/₹120/₹90) — confirm with business.
- Onboarding + auth + kids/on-sale/wallet screens still fashion-flavored; out of
  Phase 1 nav but reachable via routes — Phase 2 or delete?
- No Android SDK on this machine — APK/smoke test still needed on user side.

## Architecture Decisions

See `context/decision.md` for full decision records.

