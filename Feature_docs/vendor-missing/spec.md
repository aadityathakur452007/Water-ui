# Vendor-Missing + Location + Address Build — Spec (APPROVED 2026-10-02)

User approval: Full GPS+map first, full address format, all 4 vendor pages, live-first backend.

## 1. Sitemap delta (sitemap skill Rule 1: no page off-map gets built)
- NEW `vendor_customers` (list) + `vendor_customer_detail` (role:vendor, data: GET /api/vendor/orders derived, no new endpoint)
- NEW `vendor_earnings` (role:vendor, derived ledger from vendor orders, no new endpoint)
- NEW `vendor_inventory` (role:vendor, data: GET /api/products + client PATCH available via existing product flow; no new backend in this pass)
- EXTEND `addresses` sheet: {label,house,street,area,city,pincode,phone,lat,lng} + Use-current-location + map preview (no google_maps_flutter yet — lat/lng text + reverse-geocode display only)
- EXTEND `AndroidManifest.xml` + `Info.plist` + `location_service.dart` (permission flow)

## 2. User flows (user-flows skill: every gesture has continuation, every API branch drawn)
- Location: Home [Use location] → isServiceEnabled? no→openLocationSettings→ retry → checkPermission denied→request → deniedForever→openAppSettings → getCurrentPosition(high, 15s timeout) → placemark → prefill sheet → POST /api/addresses → 201 select + Cart refresh | 400 field errors | 401→login | NETWORK→retry + demo fallback label
- Address CRUD: Addresses tap→pop(selected) → Cart `await pushNamed + _loadAddresses()` → SelectedAddressStore (SharedPreferences selectedId) syncs Home/Cart/Addresses
- Vendor customers: VendorHome tab → fetchOrders (existing) → group by customer key (email/phone/name per withExtendedKpis) → search → detail (orders + totals)

## 3. Architecture (design-patterns: Layered + Repository + Adapter, minimum code)
- Mobile: Screen → Service/Repository → ApiClient → Hono → DbClient → SQLite/D1. No new layers. `LocationService` pure wrapper over geolocator+geocoding+permission_handler. `SelectedAddressStore` ChangeNotifier + SharedPreferences (no new state lib).
- Backend: address handlers extend columns (house,street,area,pincode,phone,lat,lng); runtime migration `migrations/0002_addresses.sql`; schema.sql updated; D1 seed updated. Vendor: NO new endpoints this pass (derive from existing vendor/orders+subscriptions to avoid contract break). Profile stays device-local with honest label; server profile is Phase 2 ADR.

## 4. Security (ssdlc STRIDE)
- Role forced server-side (register ignores role). Vendor routes 403 non-vendor. PII: customer{name,phone,email} only, never password_hash/role/sessions (existing LEFT JOIN kept). Input: pincode ^[1-9][0-9]{5}$, phone 10-digit, lat -90..90 lng -180..180, allowlist validation → 400. No secrets in code. Location data stored only as address lat/lng user provided.

## 5. Premium UI (premium-design Modern Minimalist + design-basics + ui-checklist)
- 8pt spacing scale, 16px screen padding, 12px card padding, 8px gaps. 44x44 touch targets. Contrast 4.5:1 body. labelText (never hint-only). Expanded on row texts to kill overlap. States.md: loading/empty/error/retry on every new list. Only transform+opacity anim, prefers-reduced-motion respected. Reuse flutter_ui_collection + existing ProductCard/NetworkImageWithLoader.

## 6. File ownership (parallel, disjoint — no two agents touch same file)
- A-location: AndroidManifest.xml, Info.plist, pubspec.yaml(deps append only), lib/services/location_service.dart(NEW), home_screen.dart, delivery_address_header.dart, enable_notification_screen.dart, test/location_service_test.dart
- B-address+backend: lib/repositories/address_repository.dart, lib/models/order_model.dart(DeliveryAddress only), lib/config/demo_seed.dart+demo_store.dart(address section only), lib/store/selected_address_store.dart(NEW), lib/screens/address/views/addresses_screen.dart, lib/screens/checkout/views/cart_screen.dart(address-refresh lines only), backend/schema.sql, backend/migrations/0002_addresses.sql(NEW), backend/src/app.ts(address handlers only), backend/seed.ts, backend/seed.d1.sql, test/address_*
- C-vendor: lib/screens/vendor/vendor_customers_screen.dart(NEW), vendor_earnings_screen.dart(NEW), vendor_inventory_screen.dart(NEW), vendor_home_screen.dart(tab wiring only), lib/route/route_constants.dart+router.dart(new routes only), test/vendor_missing_test.dart
- D-polish: lib/theme/*, lib/components/*, States.md compliance pass on touched flows, docs/store-listing Data-safety note (doc only, no lib/ edits overlapping A/B/C)

## 7. Success criteria
- flutter analyze zero, flutter test green, bun run check clean, docker live: register→login→POST addresses(full)→POST orders→vendor fetch shows customer→vendor screens render.
- No hallucinated imports: every import must resolve to pubspec or existing lib/ file. No google_maps_flutter (not installed). No new state mgmt lib.
