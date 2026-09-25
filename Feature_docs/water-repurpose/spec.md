# Water Delivery Repurpose — Spec (APPROVED)

## Status: APPROVED by user (2026-09-24). Phase 1 in progress on `feature/water-repurpose`.

## Goal
Repurpose the existing FlutterShop ecommerce template into a production-ready
WATER DELIVERY CUSTOMER APP. REPURPOSE, not redesign: keep typography, spacing,
cards, buttons, bottom nav, animations, transitions, and reusable widgets.

## Git / workspace (approved)
- Fresh repo: history dropped (old `.git` left in `E-commerce-Complete-Flutter-UI`,
  folder locked by OS so a copy was made). New working repo: `water-delivery-app`.
- `main` = root commit of template. All changes on `feature/water-repurpose`.
- Old folder `E-commerce-Complete-Flutter-UI` still on disk — user deletes manually.

## Product
- 20L jar, 15L can, 10L can, 1L bottle, 500ml bottle. All prices in ₹.
- Phase 1 prices (approved defaults): 20L ₹60, 15L ₹50, 10L ₹40, 1L (12-pack) ₹120,
  500ml (12-pack) ₹90. Delivery fee ₹10. Payment: Cash on Delivery + UPI.
- Android-first. No purple gradients, dark mode, glassmorphism, neon, or AI badges.

## Phase 1 scope (this branch)
1. `lib/constants.dart` — primary purple → water blue `0xFF1B7BD6`.
2. `lib/models/` — extend `ProductModel` (capacity, unit, container, waterType,
   available); water demo catalog; new `cart_model.dart`, `order_model.dart`,
   `subscription_model.dart` (data-prep only).
3. `lib/repositories/` (new) — `ProductRepository`, `OrderRepository`,
   `SubscriptionRepository` (clean local/mock layer, no hardcoded widget values).
4. `lib/entry_point.dart` — 4 tabs: Home, Shop, Orders, Account.
5. Home — address header, water search hint, 5 category chips, product cards with
   qty stepper + ₹, Order-again, active-delivery card, one small banner max.
6. Shop (`DiscoverScreen`) — Water Jars / Cans / Bottles / Packaged Water.
7. Product detail — capacity/container/type, qty, Continue. Drop size/color guides.
8. Cart/Checkout — summary ₹, delivery one-time/regular, address, Cash/UPI,
   Place Order • ₹total.
9. Orders screen — ONGOING / PAST with water data + ₹.
10. `ProductCard` — drop fashion attrs, add stepper.

## Phase 2 (later branch / same branch follow-up)
Order-type screen, subscription config, subscription mgmt + progress, account
additions (My Regular Deliveries, Payment Methods), search repurpose, notifications.

## Success criteria (Phase 1)
- `flutter analyze` clean on touched files; app builds.
- ₹ everywhere in touched flows; no clothing content in touched screens.
- Bottom nav 4 tabs work; back navigation works; theme consistent.
- No new dependencies; no duplicate widgets.
