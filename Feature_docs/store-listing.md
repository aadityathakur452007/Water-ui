# Google Play Store Listing — Water Delivery App (v1)

> Branch: `feature/water-release-prep` · Doc-only, no `lib/` or `android/` changes.
> Audit status: release signing wiring OK, keystore gitignore OK, secrets contract OK —
> see §8. Package rename is still pending (see §1).

## 0. Pre-flight (do first)

- [ ] Rename package to `com.waterdelivery.app` (today: `com.example.shop` — §8)
- [ ] Rename app label to final name (today: `shop` — §8)
- [ ] Set the 4 GitHub secrets (§5), push a `v*` tag, confirm signed AAB
- [ ] Host privacy-policy URL (§4), complete Data safety + Content rating (§4–§6)

## 1. App identity

| Field | Value | Status |
|---|---|---|
| App name (Play) | Water Delivery (confirm final spelling) | TODO — `AndroidManifest.xml` label is still `shop` |
| Package | `com.waterdelivery.app` | TODO — `build.gradle` namespace + `applicationId` are still `com.example.shop`; `MainActivity` still at `com/example/shop/` |
| Version | `1.0.0+1` (`pubspec.yaml`); CI overrides to `--build-name=<tag>` + `--build-number=<run_number>` | Note: Play versionCode = GitHub run number, not `+1` |
| Category | Shopping / Food & Drink (pick one, stays) | TODO |
| Contact email | <owner email> | TODO |

## 2. Required graphics

- [ ] High-res icon — **512 × 512 PNG**, 32-bit, no alpha issues
- [ ] Feature graphic — **1024 × 500 JPG/PNG**, no text in safe-zone edges
- [ ] Phone screenshots — **min 2**, 16:9 or 9:16, e.g. 1080 × 1920 (upload up to 8; first 3 carry the listing)
- [ ] 7-inch + 10-inch tablet screenshots (only if enabling tablet distribution; else skip)
- [ ] Promo video URL (optional, YouTube link)
- [ ] Short description — ≤ 80 chars; Full description — ≤ 4000 chars (draft both, no keyword stuffing)

## 3. What ships today (debug-signed)

- Local: `android/key.properties` absent, no `*.jks` present → `buildTypes.release` falls back to `signingConfigs.debug`. Any local `flutter run --release` / `flutter build` is **debug-signed: installable, NOT Play-uploadable**.
- CI (`release.yml`): without the 4 secrets it prints `No keystore secret — release will be debug-signed` and publishes a debug-signed APK+AAB to the GitHub Release page. **Do not upload that AAB to Play.**
- After secrets are set, the same workflow writes `android/key.properties` + `android/app/upload-keystore.jks` and produces the upload-signed AAB (`dist/water-delivery-<tag>.aab` + `.apk` + `SHA256SUMS.txt`).

## 4. Privacy policy + Data safety (v1 declares none collected)

- [ ] Host a public privacy-policy URL (required for all apps, even with zero collection). Link it in Play Console → Store settings.
- [ ] Policy must state: v1 collects **no personal data**, no location, no contacts, no analytics SDK, no ads SDK; orders/account data (if added later) requires a policy + Data-safety update before that release.
- [ ] Play Console → Data safety form: answer **"Does your app collect or share any user data?" → No** (v1). Revisit on any release that adds auth, orders, push tokens, or analytics.

## 5. Upload key — generate once, store as 4 secrets

Names must match `release.yml` exactly (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`):

```powershell
# 1. Generate (PowerShell — keytool ships with Android Studio / JDK 17)
keytool -genkey -v -keystore upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000

# 2. Base64 the keystore (single line) -> paste into secret ANDROID_KEYSTORE_BASE64
certutil -encode upload-keystore.jks upload-keystore.b64 | Select-String -Pattern "^-" -NotMatch | Set-Content upload-keystore.singleline.b64
# Linux/macOS equivalent (matches comment in release.yml):
# base64 -w0 upload-keystore.jks

# 3. GitHub → Settings → Secrets and variables → Actions → New repository secret:
#    ANDROID_KEYSTORE_BASE64 = <single-line base64>
#    ANDROID_KEY_ALIAS       = upload
#    ANDROID_KEY_PASSWORD    = <key password you typed>
#    ANDROID_STORE_PASSWORD  = <store password you typed>
```

- [ ] Keystore backup stored offline (losing the upload key = Play support reset flow). Never commit `*.jks` / `key.properties` (both gitignored — §8).
- [ ] CI writes `storeFile=upload-keystore.jks` (relative to `android/app/`) + the 3 passwords into `android/key.properties` at build time — keys match `build.gradle` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`).

## 6. Content rating questionnaire notes

- [ ] Play Console → Content rating → Start questionnaire (ISEA / ESRB / etc. via the single form).
- [ ] Expected v1 answers: no violence, no sexual content, no profanity, no gambling, no user-generated content sharing, no location sharing with other users, no ads. Water-ordering utility → **Everyone / 3+** outcome.
- [ ] If push notifications / accounts ship later, re-take only if the questionnaire flags it (accounts alone don't raise the rating; UGC/chat would).

## 7. Internal-testing track rollout

1. Play Console → Create app → enter name, package `com.waterdelivery.app`, confirm upload-key fingerprint on first AAB upload (Play App Signing enrolls at that point — keep the upload key).
2. Upload the CI-signed `dist/water-delivery-<tag>.aab` to **Testing → Internal testing** (not Production).
3. Add testers: email list or Google Group; copy the opt-in link.
4. Install on a real device via the opt-in link; verify: app name/icon, version (`<tag>` / run number), cold start, order flow smoke test.
5. Promote Internal → Closed → Open → Production only after crash-free + listing + rating + privacy URL are green. Each promotion needs a new release entry; versionCode (run number) must always increase.

## 8. Audit findings (read-only, files NOT changed)

- `android/app/build.gradle` — **OK**: loads `rootProject.file('key.properties')` (`android/key.properties`), `signingConfigs.release` is null-safe on `storeFile`, `buildTypes.release` uses `keystorePropertiesFile.exists() ? release : debug`. Matches CI fallback comment.
- `android/.gitignore` — **OK**: ignores `key.properties`, `**/*.keystore`, `**/*.jks`. Verified: `git check-ignore` hits for `android/key.properties` and `android/app/upload-keystore.jks`; no keystore files tracked (`git ls-files android` clean). Root `.gitignore` has no keystore lines — not a mismatch (android-scoped ignore covers it).
- `.github/workflows/release.yml` — **OK**: 4-secret contract (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`) written to `android/key.properties` with keys matching `build.gradle`; debug fallback message present; builds fresh APK+AAB from the tag with `--build-name=<tag-minus-v> --build-number=<run_number>`.
- **Mismatches (must fix before Play upload, outside these frozen files)**:
  1. Package is `com.example.shop` (namespace, `applicationId`, `MainActivity` path), not `com.waterdelivery.app`.
  2. App label is `shop`, not the store name.
  3. Play versionCode will be the GitHub run number (CI override), not `pubspec` `+1` — tag/run scheme is fine, just know it.
  4. Everything today is debug-signed (no local `key.properties`/`.jks`; no secrets asserted here) — expected pre-release state.
