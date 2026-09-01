## 0.7.1 — 2026-09-02

* Metadata and documentation only: updated pub.dev description, README, and added `referral` topic. No code changes.

## 0.7.0 — 2026-07-21

* `Flinku.resetAll()` — testing-only full local wipe (match cache, user id, pending referral, tracked-once flags). Does not change `reset()` behaviour.
* Pending referral index entry is removed when a pending referral record expires by TTL.

## 0.6.0

* Pending referral attribution is stored separately from the match cache (`flinku_pending_referral_{projectId}`)
* `Flinku.reset()` no longer clears referral attribution or the stored user id
* Failed track POSTs leave the pending record in place and retry on the next `setUserId` or `configure` (when a userId is already stored)
* Pending referrals expire after 30 days

## 0.5.0

* Referral track once-per-user flag is now `referral_tracked_{projectId}_{userId}`
* README Referrals section documents `apiKey` on `configure`

## 0.4.0

* `Flinku.setUserId` — store app user id and auto-track referrals from cached match `referrerId`
* `Flinku.qualifyReferral` — mark a referred user as qualified for an optional event

## 0.3.5 - Support publishable API keys (flk_pk_). Debug-mode warning when a secret key is embedded. Surface Allowed Domains errors clearly.

## 0.3.3 - Add createLinkInstant for instant link creation without waiting for server

## 0.3.3

* Clipboard fallback in `match()` when fingerprint matching returns no result
* `FlinkuLink.matchType` — `clipboard`, `fingerprint`, `referrer`, or `none` from the API

## 0.3.2

* Documented all public APIs with `dartdoc` comments for pub.dev scoring
* Added `example/` Flutter app demonstrating `configure`, `match`, and `reset`

## 0.3.1

* `match()` now POSTs to the root API host (`apiBaseUrl`) derived from `baseUrl`, with body `subdomain` + `userAgent` (`flutter/<platform>`)
* `match()` returns `FlinkuLink?` — `null` when unmatched, on error, or on non-200 responses

## 0.3.0

* Added `createLink()` and `createLinks()` methods for programmatic link creation

## 0.2.0

* Project-based architecture — baseUrl is now your project subdomain URL
* Added `params` to FlinkuLink — access custom parameters from your links
* Added `title`, `clickedAt`, `subdomain`, `projectId` to FlinkuLink
* Added timeout configuration (default 5 seconds)
* Added retry logic — retries once on network failure
* Added double-match prevention — match() returns cached result after first match
* Added `Flinku.reset()` for testing
* Updated subdomain auto-extraction from baseUrl

## 0.1.0

* Initial release
* Deferred deep linking support for iOS and Android
* Fingerprint-based link matching
* Simple 3-line integration
