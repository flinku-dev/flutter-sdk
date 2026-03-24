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
