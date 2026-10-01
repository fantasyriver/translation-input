> 历史设计，已由 [2026-10-01 客户端直连方案](2026-10-01-direct-provider.md) 取代。服务端与收费路线不再实施。

# Translation Input Implementation Plan

**Goal:** Build a native macOS translation panel and a lightweight authenticated translation server.

**Architecture:** AppKit client with isolated session state, HTTP translation, and a replaceable insertion component. Go standard-library server with configurable OpenAI-compatible upstream, request validation, bounded concurrency, authentication and structured errors. User selected website distribution with automatic insertion; a future store edition can reuse the service with a copy workflow.

**Tech Stack:** Swift / AppKit / Carbon / Security / URLSession, Go net/http, standalone Swift behavior checks, Go testing.

## Confirmed scope

- 2026-09-26 user confirmed client and lightweight server together.
- User chose website distribution with automatic insertion and later monetization; real payment integration is not included in the MVP.
- First milestone is development MVP, not a deployed paid service. No production model credentials or payment account have been supplied.
- No schema creation/mutation in application code. First milestone requires no database. Future billing migrations must be separate SQL files.

## 1. Service contract and tests

Files: `server/go.mod`, `server/api_test.go`, `server/api.go`.
Write HTTP tests for authorized translation, missing/wrong credentials, malformed/oversized requests, unsupported languages, upstream timeout/error, canceled requests, and concurrency limits. Run `go test ./...` and observe failures for the missing behavior, then implement bounded handlers. Validate with `go test -race ./...`.

## 2. Model adapter and runnable server

Files: `server/upstream_test.go`, `server/upstream.go`, `server/main.go`, `server/.env.example`, `server/Dockerfile`.
Test a local HTTP upstream for payload construction, Unicode preservation, refusal/truncation and response validation; then implement. Use explicit endpoint/model/key configuration, no secret defaults, no automatic retries, no redirect following, no logging of input/output/key. Add graceful shutdown and timeouts. Document TLS reverse proxy for public deployment.

## 3. macOS session and HTTP core

Files: `macos/Package.swift`, `macos/Sources/TranslationCore/*.swift`, `macos/Tests/TranslationCoreTests/*.swift`.
Test cancellation and stale response suppression, one insertion attempt per submission, endpoint validation and response/request ID consistency before implementation. Run `swift run --package-path macos CoreChecks`.

## 4. Native UI and integration

Files: `macos/Sources/TranslationInput/*.swift`, `scripts/build-app.sh`, `macos/Resources/Info.plist`.
Implement status menu, panel, NSTextView composition behavior, target language, Cmd+Enter submission, cancellation, settings and Keychain token. Register configurable hotkey with failure recovery. Keep insertion implementation separate for website/store builds. Build `.app` without altering machine developer settings. Validate startup and manual UI when accessible.

## 5. Verification and documentation

Files: `README.md`, `docs/manual-testing.md`, `docs/distribution-and-billing.md`.
Run Go tests/race/vet, Swift core tests, Release app build and local client/server HTTP integration. Report separately: code compiled, automated checks passed, UI tested, cross-app behavior tested, real model tested. Do not claim production billing, universal compatibility, notarization or live deployment.

## Distribution and billing principles

- App Store requires sandbox; current AX cross-app control cannot simply be shipped unchanged.
- Store payment candidates: paid download, StoreKit subscription, consumable translation credits. Storefront-specific external purchase exceptions require separate review.
- Website edition: Developer ID + notarization; external checkout and server entitlements can support licenses/subscriptions/credits.
- Prefer trial plus metered subscription/credits over lifetime unlimited translation.
- Production billing requires persistent accounts, verified transaction events, atomic usage ledger and idempotency. In-memory request counters are abuse controls, not a billing ledger.
