# Direct LLM Provider Implementation Plan

**Goal:** Make 译入 a standalone open-source macOS app with user-owned provider API keys; remove the Go relay.

**Architecture:** AppKit settings select one of six providers or a custom endpoint. Foundation URLSession calls OpenAI-compatible Chat Completions or Anthropic Messages directly. Configuration contains no secrets; Keychain entries are scoped to provider, protocol, and complete endpoint. Existing shortcut, cancellation, focus checks, and insertion behavior remain.

**Tech Stack:** Swift 6 / Swift 5 language mode, macOS 14+, AppKit, Security, Foundation. No third-party runtime dependencies or database.

## Decisions
- User explicitly requested client-side API calls and removal of server on 2026-10-01; this supersedes the September server/billing design.
- Native HTTP adapters keep memory/dependencies small; vendor SDKs would add unnecessary dependencies. Offline inference is a separate concern: a custom localhost-compatible endpoint may be configured.
- Six provider presets plus custom OpenAI/Claude protocols. Complete endpoint URL and model remain editable. Prefer inexpensive text models; do not claim fixed prices or universal cheapest availability.
- Save each provider profile separately. On provider/endpoint/protocol changes, reload only the matching Keychain secret. No migration of legacy relay token into API credentials.
- MIT license. API bills are paid to selected provider. The user subsequently authorized public GitHub publication under their personal account.
- First send confirms recipient; no auto retries or paid model test on saving.

## Steps and verification
1. Replace old server-contract tests in `macos/Tests/TranslationCoreTests/CoreTests.swift` with request/response adapter, credential-scope, profiles, cancellation regressions. Run `swift run --package-path macos CoreChecks` and observe missing new functionality.
2. Implement presets, LLM configuration and request/response adapters in `macos/Sources/TranslationCore/`. Preserve TranslationSession and target languages. Validate endpoints, keys, text, completion reasons, refusal and output bounds. Reject redirects and cancel transport on errors/cancellation.
3. Update `Credentials.swift`, preferences, `Settings.swift`, `App.swift`: provider/model/protocol controls, independent profiles and scoped key access, direct-send consent. Build app.
4. Replace `scripts/check-integration.py` with isolated Python HTTP fixtures used only by tests: exercise both wire protocols, all provider requests, Unicode, authentication, truncation, redirect, size limits, cancellation. No real keys or paid requests.
5. Remove `server/`, Go-specific instructions and obsolete billing plan; update README/manual testing/provider reference/privacy/contribution/license. Preserve any user secret files if discovered.
6. Run core checks, HTTP integration, release build, strict signature verification. Inspect native settings and preset changes. Review code before completion and update project memory.
