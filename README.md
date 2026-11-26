# booking-mobile

[![CI](https://github.com/Kurtis-H/booking-mobile/actions/workflows/ci.yml/badge.svg)](https://github.com/Kurtis-H/booking-mobile/actions/workflows/ci.yml)

A Flutter (Android) app for buying event seats, built on the booking API from [api-performance-lab](https://github.com/Kurtis-H/api-performance-lab). It does the same job as the web app [booking-web](https://github.com/Kurtis-H/booking-web), and it is the mobile target for the Appium and Maestro side of my test framework comparison.

## What it does

* Browse upcoming events a page at a time, with seats left and sold-out events marked.
* Pick up to 10 seats on a seat map, see the total, and buy them (signing in first if needed).
* See your orders and open any of them.
* Handle what goes wrong on a phone: someone else buys your seat first (409), rate limits (429, using `Retry-After`), an expired session (401), missing events (404), and being offline. Every case has a clear message and a way forward.
* Accessible: each seat is announced as "Seat R2-5, $30.00" with its selected state, and tap targets and text contrast are checked by the tests.

## How it's tested

| Layer | Tool | What it checks |
|---|---|---|
| Unit | `flutter_test` | Seat selection rules, money and date formatting, error messages, the API client (status codes, `Retry-After`, bad bodies, network failures) |
| Widget | `flutter_test` + an in-memory fake API | Every screen through the whole app: paging, buying, losing a seat to another buyer, rate limits, sign-in errors, offline and retry |
| Golden | `matchesGoldenFile` | The seat map's layout and selected state, pixel for pixel |
| Accessibility | `meetsGuideline`, semantics matchers | Screen-reader labels and states, 48dp tap targets, WCAG text contrast |
| Integration | `integration_test` on an Android emulator | The real app against the **real** API and Postgres, including a seat sold to someone else mid-purchase |
| End to end | Maestro on the same emulator | Black-box flows a tester would write: buy seats, sign-in errors, the 10-seat limit |

Unit and widget tests need at least 80% line coverage (`tool/check_coverage.dart`).

The fake API in `test/support/fake_backend.dart` follows the real API's rules (401, 404, 409), so widget tests are fast and offline, while the emulator job proves the app works against the real thing.

Seats carry a semantics `identifier` (`seat-R1-1`), which Android exposes as a resource id, so Maestro and Appium can find them without relying on on-screen text.

## Run it

You need Flutter (stable) and, for the emulator tests, the booking API running on your machine (from api-performance-lab: `scripts/serve.sh`).

```bash
flutter pub get
flutter test                       # unit, widget, golden and accessibility tests
flutter run --dart-define=API_URL=http://10.0.2.2:8000     # Android emulator -> your machine
flutter test integration_test --dart-define=API_URL=http://10.0.2.2:8000
maestro test .maestro              # with the app installed on the emulator
```

Sign in with a key from the seed data (`key-user-1` to `key-user-200`), or tap "Use the demo account". These keys are public test data.

## CI

Every push and pull request runs:

* **Analyze, unit, widget and golden tests:** `dart format` check, `flutter analyze`, tests with the coverage gate
* **Build the Android app:** a debug APK
* **Integration tests and Maestro on an emulator:** starts Postgres and the booking API, boots an Android 14 emulator, runs `integration_test`, then installs the APK and runs every Maestro flow
* **CodeQL** for the workflows (CodeQL doesn't analyse Dart), and Dependabot for pub, Gradle and Actions

## How this was built

I wrote this without a local Flutter SDK, so GitHub Actions did the compiling: a one-off bootstrap workflow ran `flutter create` for the Android project, upgraded dependencies, generated the golden image and formatted the code, then committed the results back to the branch. Every later change was checked by CI on the pull request.

## Known gaps

* Order details show seat ids, not labels, because the API's order response doesn't include labels yet (tracked in api-performance-lab).
* Android only for now. Adding iOS means generating the iOS project and running the emulator job on a macOS runner (free for public repos), plus an iOS simulator for Maestro.
