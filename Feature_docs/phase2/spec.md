# Phase 2 — Spec (PROPOSED 2026-10-02, awaiting approval — NO CODE YET)

Scope approved by user: all four slices. Proposed build order (each shippable alone):
1. Server vendor profile → 2. Release prep → 3. Map picker → 4. Push notifications.

## Slice 1 — Server vendor profile + support tickets
- **Sitemap**: no new pages (reuse `VendorSettingsScreen`); new API only.
- **API (new, additive — contract unfrozen for these with ADR)**: `GET /api/vendor/profile` → `{name,phone,address,hours}`; `PATCH /api/vendor/profile` (same fields, allowlist validation); `GET /api/vendor/slots` + `PUT /api/vendor/slots`; `GET+POST /api/vendor/tickets` + `GET /api/vendor/tickets/:id` + `POST /api/vendor/tickets/:id/replies`. New tables: `vendor_profile(user_id UNIQUE, name, phone, address, hours)`, `vendor_slots(user_id, slot_key, enabled)`, `support_tickets(id, vendor_id, subject, status, created_at)`, `ticket_replies(id, ticket_id, author, body, created_at)`. D1 migration `0004_vendor_profile.sql` + runtime guard in `index.ts` (same PRAGMA pattern as 0003).
- **Flutter**: `VendorSettingsStore` gains live branch (GET on open, PATCH on save, loading/error/retry per States.md); honest "synced" vs "this device" label flips by `AppConfig.demoMode`; support tab lists tickets + detail + reply box. Vendor PII rule unchanged (profile is the vendor's own row — no cross-user leak; tickets scoped `vendor_id = me`).
- **Flows**: open→skeleton→load 200/error-retry/401→login; save→dirty/disabled→PATCH→toast→rollback on 409/NETWORK.
- **Tests**: profile CRUD round-trip (bun smoke), slots toggle, ticket open/reply, widget save-then-toast.

## Slice 2 — Release prep (store-listing pre-flight §0–§8)
- Package `com.example.shop` → `com.waterdelivery.app` (namespace + applicationId + MainActivity path + google-services if any); app label `Shodasha` (already set — verify); version from tag/CI (already wired).
- Data-safety flip: location collection **Yes** (precise, foreground, order-fulfilment purpose) + privacy-policy URL (host first — user provides URL or I draft policy text for hosting).
- Upload key: 4 secrets (`ANDROID_KEYSTORE_BASE64/ALIAS/PASSWORD/STORE_PASSWORD`) — user-run (keystore never touches repo; `.gitignore` already covers `*.jks`/`key.properties`).
- Internal-testing track rollout per `store-listing.md §7`.
- No app-code behavior change; verification = `release.yml` dry-run + versionCode check.

## Slice 3 — Map picker + live order tracking (KEYLESS revision 2026-10-02)
- **No Google Maps, no API key, no billing**: `google_maps_flutter` is OUT (its keys need a billing-enabled Cloud project). IN: `flutter_map` + OpenStreetMap tiles — zero key, zero billing, free. Trade-offs accepted: OSM tile usage policy (our volume is fine), no Google POI/Places autocomplete; reverse-geocode stays on the platform-native `geocoding` plugin (already added, free, no key).
- **Pages**: `address_map_picker` (flutter_map + draggable pin + confirm → returns lat/lng+geocode into address sheet); `order_tracking` (flutter_map customer pin + status timeline reuse of `OrderProgress`; no fake courier polyline).
- **Flows/tests**: unchanged from original (permission via `LocationService` → camera at fix → drag/confirm → prefill → save). Widget test uses fake controller; offline → honest fallback (no key ⇒ nothing to fail).
- **Pages**: `address_map_picker` (map + draggable pin + confirm → returns lat/lng+geocode into address sheet); `order_tracking` (order polyline vendor→customer is OUT — honest scope: static map with customer pin + status timeline reuse of `OrderProgress`).
- **Flows**: sheet [Pick on map] → permission (reuse `LocationService`) → camera at current fix → drag/confirm → prefill → save as Slice-1 address.
- **Tests**: pin-drag→confirm returns coords (widget, fake controller); tracking renders without key when offline (honest fallback).

## Slice 4 — Push notifications via existing/free Firebase project (NO-BILLING revision 2026-10-02)
- **FCM needs NO billing/card/details of any kind** — Firebase Spark (free) tier covers Cloud Messaging fully. The only inputs are the two client config files, which are public identifiers (designed to ship inside the app, NOT secrets): `google-services.json` (Android) + `GoogleService-Info.plist` (iOS). Repo has NEITHER today (verified 2026-10-02: no firebase files, deps, or gradle plugins in `apps/user`) — so nothing to reuse yet; if your Firebase console project exists, download these 2 files and hand them over.
- **New deps**: `firebase_core` + `firebase_messaging` (free).
- **Pages**: reuse `notifications` list (now server-driven) + `notification_options` (server-persisted prefs, replaces shared_prefs branch when live).
- **Flows**: login→register token→topics (`user_<id>`, `vendor_all`); vendor advance→user gets status push; permission denied→in-app list still works (same honest fallback as Slice-1 screen).
- **Security (ssdlc)**: tokens are secrets — auth-owned rows only (`user_id = me` enforced), FCM server key in env/secret store, APNs/FCM keys user-run.
- **Tests**: token register/deregister, pref sync, advance→fan-out unit (mocked FCM sender).

## Cross-slice rules (from Phase 1 learning)
- File-disjoint parallel agents per slice; additive backend migrations only (`0004`, `0005`…); every import resolves; demo-mode fallback preserved; `flutter analyze` zero + tests green + `bun run check` + live smoke per slice; context sync per slice (ADR-031…).

## Success criteria
- Slice 1: profile edit on device A visible on device B (server truth proven).
- Slice 2: signed AAB from CI + completed Data-safety + privacy URL live.
- Slice 3: address saved from map pin shows same lat/lng on vendor detail.
- Slice 4: vendor advance → user device receives status push within 60s on live backend.

**Gate: reply `approve phase 2` (or name slices, e.g. `approve slice 1+2`) — no implementation until then.**
