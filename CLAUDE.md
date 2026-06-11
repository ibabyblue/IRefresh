# CLAUDE.md

## Project

IRefresh — pure-SwiftUI pull-to-refresh + load-more SPM package (MJRefresh-style). iOS 17+, Swift 6 strict concurrency, zero dependencies. Spec: `docs/superpowers/specs/2026-06-11-irefresh-design.md`.

## Commands

```bash
swift build        # macOS slice (the .macOS(.v14) platform exists ONLY for build/test on Mac)
swift test         # swift-testing based unit tests
# iOS slice compile check:
swift build --triple arm64-apple-ios17.0-simulator --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)"
# Demo app:
xcodebuild -project demo/IRefreshDemo.xcodeproj -scheme IRefreshDemo -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Architecture

- `IRefreshScrollView` (container) renders `VStack { headerHoldSpacer; content; autoFooterRow?; footerHoldSpacer }` inside a `ScrollView`. Header/pull-footer are overlays offset just outside the content edges; rubber-banding reveals them.
- `Internal/_HeaderEngine` & `_FooterEngine` are pure `@MainActor @Observable` state machines — all transition logic and edge cases live there and are unit-tested. The container only reacts to `phase` changes (`onChange`): starts tasks, fires haptics (`_Haptics.swift` wraps `UIImpactFeedbackGenerator`), syncs mutual exclusion and the controller.
- `Internal/_OffsetProbe` reports scroll metrics via PreferenceKey, quantized to 0.5pt.
- Trigger semantics are version-split: iOS 18+ release-to-refresh (`onScrollPhaseChange` via `_ScrollPhaseObserver.swift` → `handleInteraction`), iOS 17 threshold-trigger. `_supportsReleaseDetection` is the single switch.
- Built-in styles in `Styles/` read `IRefreshTexts` from the environment; strings live in `Resources/en.lproj/Localizable.strings` + `Resources/zh-Hans.lproj/Localizable.strings` (NOT `.xcstrings` — SwiftPM CLI can't compile String Catalogs).

## Conventions

- Public API chains builder modifiers returning copies (`onRefresh`, `onLoadMore`, `refreshHeader`, …); type-changing ones rebuild the generic struct — keep the internal memberwise init in sync when adding stored properties.
- Internal files/types use `_` prefix.
- Swift 6 trap: `onPreferenceChange` closures are `@Sendable` — never capture `self` there, capture engines + value config in the capture list.
- Commits: single-line subject only, no body, no Co-Authored-By.
