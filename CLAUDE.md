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

- `IRefreshScrollView` (container) renders `VStack { topSpacer; content; autoFooterRow?; bottomSpacer }` inside a `ScrollView`; the refreshing/loading "hold" (`_HoldState`) is hybrid: gesture-triggered entry sets a `.contentMargins(for: .scrollContent)` inset (like UIKit `contentInset` — doesn't displace content during overscroll, so release settles directly at the hold), then at end of refresh the margin is swapped for a spacer in one non-animated net-zero layout pass so the collapse can animate (margins can't animate; spacers can). Programmatic entry uses the animated spacer directly. The header is an overlay offset just outside the content's top edge; rubber-banding reveals it, and it fades in tracking pull progress (hardcoded opacity 1 while refreshing, since programmatic entry freezes progress at 0). The pull footer is **viewport-pinned** (`.overlay(alignment: .bottom)` on the *ScrollView*, NOT on `content`), parked just below the viewport bottom and slid up into view by `_HoldState.footerReveal` (`.offset(y: footerTriggerDistance - footerReveal)`). It must be viewport-pinned, not content-anchored: a content overlay's downward `.offset` is counted into the ScrollView's `contentSize` on iOS 26 (the asymmetric twin of the header, whose upward offset can't extend past content origin), so a content-anchored terminal footer becomes reachable/visible at the scroll bottom at rest — a persistent banner. While pulling, `footerReveal` finger-tracks `pulledDistance` (fades/slides in, mirroring the header); on release at threshold it's held fully open (`footerReveal == footerTriggerDistance`) by the hold inset while loading; the end split is by result: `.hasMore` → footer slides down out of view (`footerReveal → 0`) as the appended rows arrive, `.noMoreData` → the held footer ALSO slides down to `footerReveal == 0` (a rebound, NOT a persistent banner). In the terminal `.noMoreData` state the footer stays parked below the viewport; pulling up past the content bottom rubber-bands it back into view via `revealTerminalFooter` (driven straight from geometry — `min(footerTriggerDistance, overscroll)` — since `_FooterEngine` freezes `pulledDistance` in `.noMoreData`), so the "no more data" text is pull-to-see and hidden at rest. Stays terminal until the next refresh resets it.
- `Internal/_HeaderEngine` & `_FooterEngine` are pure `@MainActor @Observable` state machines — all transition logic and edge cases live there and are unit-tested. The container only reacts to `phase` changes (`onChange`): starts tasks, fires haptics (`_Haptics.swift` wraps `UIImpactFeedbackGenerator`), syncs mutual exclusion and the controller.
- `Internal/_OffsetProbe` reports scroll metrics via PreferenceKey, quantized to 0.5pt.
- Trigger semantics are version-split: iOS 18+ release-to-refresh (`onScrollPhaseChange` via `_ScrollPhaseObserver.swift` → `handleInteraction`), iOS 17 threshold-trigger. `_supportsReleaseDetection` is the single switch; on iOS 18+ idle→pulling additionally requires an active interaction (gates out transition/bounce geometry transients).
- Built-in styles in `Styles/` read `IRefreshTexts` from the environment; strings live in `Resources/en.lproj/Localizable.strings` + `Resources/zh-Hans.lproj/Localizable.strings` (NOT `.xcstrings` — SwiftPM CLI can't compile String Catalogs).

## Conventions

- Public API chains builder modifiers returning copies (`onRefresh`, `onLoadMore`, `refreshHeader`, …); type-changing ones rebuild the generic struct — keep the internal memberwise init in sync when adding stored properties.
- Internal files/types use `_` prefix.
- Swift 6 trap: `onPreferenceChange` closures are `@Sendable` — never capture `self` there, capture engines + value config in the capture list.
- Commits: single-line subject only, no body, no Co-Authored-By.
