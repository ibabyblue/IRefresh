# IRefresh

MJRefresh-style pull-to-refresh and load-more for SwiftUI. Pure SwiftUI — no UIKit introspection, no third-party dependencies. Fully customizable header/footer animations (Lottie-ready), two built-in styles, auto & pull load-more modes, and a programmatic controller.

![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0%2B-orange)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

## Features

- **Pull-to-refresh with real custom animations** — the header is just a SwiftUI view driven by phase + pull progress; plug in Lottie, frame sequences, anything
- **Release-to-refresh on iOS 18+** — true MJRefresh semantics via `onScrollPhaseChange` (pull past the threshold, release to trigger, pull back to cancel); iOS 17 falls back to threshold-trigger with haptic feedback
- **Two load-more modes** — `.auto(prefetchDistance:)` fires near the bottom (infinite feed), `.pull` is a drag-out back-footer
- **`noMoreData` terminal state** — returned from your closure, reset automatically on refresh or via the controller
- **async/await API** — the animation collapses when your closure returns; impossible to forget `endRefreshing`
- **Built-in styles** — `.classic` (arrow + spinner + status text + optional last-updated time) and `.minimal` (progress ring)
- **Programmatic control** — `beginRefreshing()` on appear, `resetNoMoreData()`
- **Localization** — English and Simplified Chinese built in; all strings overridable via `IRefreshTexts`
- **Swift 6 strict concurrency** — all public types `@MainActor`, closures `@Sendable`

## Requirements

| | Minimum |
|---|---|
| iOS | 17.0 |
| Swift | 6.0 |
| Xcode | 16.0 |

> `ScrollView`-hosted content only. Native `List` cannot expose the contentOffset/inset control needed for custom refresh headers — that's a platform limitation, not a choice. `LazyVStack` reproduces any list look.

## Installation

### Swift Package Manager

In Xcode choose **File → Add Package Dependencies**, enter the repository URL, or add to `Package.swift` directly:

```swift
dependencies: [
    .package(url: "https://github.com/ibabyblue/IRefresh", from: "0.1.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "IRefresh", package: "IRefresh")
        ]
    )
]
```

## Quick Start

```swift
import IRefresh

struct FeedView: View {
    @State private var model = FeedModel()

    var body: some View {
        IRefreshScrollView {
            LazyVStack(spacing: 0) {
                ForEach(model.items) { ItemRow(item: $0) }
            }
        }
        .onRefresh {
            await model.reload()
        }
        .onLoadMore {
            await model.loadNextPage() // return .hasMore or .noMoreData
        }
    }
}
```

That's it — classic header and footer included. Omit `.onRefresh`/`.onLoadMore` to disable either direction. Load-more defaults to `.auto(prefetchDistance: 0)` — it fires when the list is scrolled to the bottom.

## Demo

Open `demo/IRefreshDemo.xcodeproj`, select a simulator and run (resolves [lottie-spm](https://github.com/airbnb/lottie-spm) on first build). Covers six pages: Classic, Minimal, custom Lottie header, auto footer with prefetch, pull footer, and programmatic control.

## Customization

### Built-in styles

```swift
.refreshHeader(.classic)                              // arrow + spinner + text
.refreshHeader(.classic(lastUpdatedKey: "feed"))      // + persisted "last updated" line
.refreshHeader(.minimal, triggerDistance: 70)         // progress ring, custom trigger distance
.refreshFooter(.classic)
.refreshFooter(.minimal)
```

The default trigger distance is 60pt for headers and 50pt for footers; built-in and custom headers are laid out at exactly the trigger distance in height.

### Custom header (e.g. Lottie)

A header is any view built from an `IRefreshContext` — `phase` plus `progress` (pull distance / trigger distance):

```swift
.refreshHeader(triggerDistance: 70) { context in
    switch context.phase {
    case .refreshing, .finishing:
        LottieView(animation: .named("loading"))
            .playing(loopMode: .loop)        // play only after release
    default:
        LottieView(animation: .named("loading"))
            .currentProgress(0)              // static while pulling
    }
}
```

The control fades the whole header in as you pull (opacity tracks `progress`), so a custom view typically stays **static while pulling** and only animates once `.refreshing`. If you'd rather scrub a Lottie by pull distance instead of fading, drive `.currentProgress(min(context.progress, 1))` in the `default` branch — both are valid.

Phases: `idle → pulling → willRefresh → refreshing → finishing → idle`. `.willRefresh` (dragging at/past the threshold, waiting for release) only occurs on iOS 18+ — treat it as optional. Footers additionally receive `.noMoreData`.

### Load-more modes

```swift
.onLoadMore(mode: .auto(prefetchDistance: 300)) { await model.loadNextPage() }  // fire 300pt early
.onLoadMore(mode: .pull) { await model.loadNextPage() }                          // drag-out back footer
```

The auto footer stays inactive while the content is shorter than the viewport.

### Programmatic control

```swift
@State private var controller = IRefreshController()

IRefreshScrollView { ... }
    .onRefresh { await model.reload() }
    .refreshController(controller)
    .onAppear { controller.beginRefreshing() }
```

`controller.resetNoMoreData()` re-arms a footer that returned `.noMoreData` (refreshing also re-arms automatically).

### Texts & localization

English and Simplified Chinese ship by default and follow the system language. Override any string:

```swift
.refreshTexts(IRefreshTexts(pulling: "Pull…", refreshing: "Working…"))
```

### Notes & limitations

- `.onLoadMore(...)` always sets the footer mode — calling it again without the `mode:` argument resets the mode to `.auto(prefetchDistance: 0)`.
- Navigating away (e.g. a `NavigationStack` push) cancels an in-flight refresh/load and collapses the UI; the async closure's work is cancelled cooperatively via `Task` cancellation.
- In `.auto` mode the footer never fires while the content is shorter than the viewport — load the first page via `onRefresh` or `IRefreshController.beginRefreshing()`.
- SPM packages localize against the host app's language set; if the host app doesn't declare zh-Hans, strings fall back to English unless the app sets `CFBundleAllowMixedLocalizations`.

## How It Works

- Content lives in a plain `ScrollView`. On iOS 18+ scroll metrics come from `onScrollGeometryChange` (reliable during live gestures); on iOS 17 a zero-size GeometryReader probe is the fallback source. Metrics are quantized to 0.5pt and feed small state machines.
- The header sits directly above the content and the pull footer just below it — both are content-anchored, so they track the pull gesture natively and fade in as you drag (opacity follows `progress`).
- While refreshing, an animated spacer "holds" the header visible; when your async closure returns, the header fades out together with a smooth collapse animation.
- Two footer presentations (like MJRefresh): `.auto` is a persistent row at the list bottom (its "no more data" is visible once you scroll there); `.pull` is a back-footer below the content (pull up to reveal it; "no more data" stays hidden at rest and rubber-bands into view only on pull).
- On iOS 18+, `onScrollPhaseChange` detects finger release for faithful MJRefresh semantics (and gates out non-interactive geometry transients). On iOS 17 that API doesn't exist, so crossing the threshold triggers immediately (with a haptic).

## License

IRefresh is available under the MIT license. See the [LICENSE](LICENSE) file for details.
