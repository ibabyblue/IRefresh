import SwiftUI

/// Reference-typed cache of the latest scroll metrics, so a viewport-only
/// resize (which doesn't fire `onPreferenceChange`) can still re-drive the
/// engines with up-to-date geometry.
@MainActor
final class _MetricsCache {
    var latest = _ScrollMetrics()
}

/// Reference-typed hold state so the end-of-refresh Task closures can mutate
/// it without capturing `self`. The "hold" is hybrid:
/// - **Margin** (`.contentMargins`, UIKit contentInset equivalent) for
///   gesture-triggered entry: changing an inset doesn't displace content
///   mid-rubber-band, so the release settles directly onto the hold.
/// - **Spacer** (layout) for programmatic entry and the end-of-refresh
///   collapse: margins cannot animate, spacers can.
@MainActor @Observable
final class _HoldState {
    /// Inset-based hold: used when refresh is triggered from an overscroll
    /// gesture — margins don't displace content mid-rubber-band.
    var headerMargin: CGFloat = 0
    var footerMargin: CGFloat = 0
    /// Layout-based hold: used for programmatic entry and for the animated
    /// collapse (margins cannot animate; spacers can).
    var headerSpacer: CGFloat = 0
    var footerSpacer: CGFloat = 0
}

/// A `ScrollView`-based container with MJRefresh-style pull-to-refresh and
/// load-more. Host any SwiftUI content (LazyVStack, Grid, …) and chain the
/// builder modifiers:
///
///     IRefreshScrollView {
///         LazyVStack { ... }
///     }
///     .onRefresh { await vm.reload() }
///     .onLoadMore { await vm.loadMore() }
///     .refreshHeader(.classic)
public struct IRefreshScrollView<Content: View, Header: View, Footer: View>: View {
    var content: Content
    var headerBuilder: (IRefreshContext) -> Header
    var footerBuilder: (IRefreshContext) -> Footer
    var onRefreshAction: (@Sendable () async -> Void)?
    var onLoadMoreAction: (@Sendable () async -> IRefreshLoadResult)?
    var footerMode: IRefreshFooterMode
    var headerTriggerDistance: CGFloat
    var footerTriggerDistance: CGFloat
    var controller: IRefreshController?
    var texts: IRefreshTexts

    @State private var headerEngine = _HeaderEngine()
    @State private var footerEngine = _FooterEngine()
    @State private var metricsCache = _MetricsCache()
    @State private var holdState = _HoldState()
    @State private var refreshTask: Task<Void, Never>?
    @State private var loadTask: Task<Void, Never>?

    private static var coordinateSpace: String { "IRefreshScrollView" }

    init(
        content: Content,
        headerBuilder: @escaping (IRefreshContext) -> Header,
        footerBuilder: @escaping (IRefreshContext) -> Footer,
        onRefreshAction: (@Sendable () async -> Void)? = nil,
        onLoadMoreAction: (@Sendable () async -> IRefreshLoadResult)? = nil,
        footerMode: IRefreshFooterMode = .auto(prefetchDistance: 0),
        headerTriggerDistance: CGFloat = 60,
        footerTriggerDistance: CGFloat = 50,
        controller: IRefreshController? = nil,
        texts: IRefreshTexts = IRefreshTexts()
    ) {
        self.content = content
        self.headerBuilder = headerBuilder
        self.footerBuilder = footerBuilder
        self.onRefreshAction = onRefreshAction
        self.onLoadMoreAction = onLoadMoreAction
        self.footerMode = footerMode
        self.headerTriggerDistance = headerTriggerDistance
        self.footerTriggerDistance = footerTriggerDistance
        self.controller = controller
        self.texts = texts
    }

    public var body: some View {
        GeometryReader { viewport in
            let viewportHeight = viewport.size.height
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    // Spacer half of the hybrid hold (see below): grows for
                    // programmatic entry, and carries the animated collapse.
                    Color.clear
                        .frame(height: holdState.headerSpacer)

                    content
                        .overlay(alignment: .top) { headerOverlay }
                        .overlay(alignment: .bottom) { pullFooterOverlay }

                    if isAutoFooterActive {
                        footerBuilder(footerEngine.context)
                            .frame(maxWidth: .infinity)
                    }

                    Color.clear
                        .frame(height: holdState.footerSpacer)
                }
                .background {
                    // iOS 17 only: the GeometryReader preference probe is the
                    // metrics source. On iOS 18+ `onScrollGeometryChange`
                    // (below) takes over — the probe doesn't deliver updates
                    // during live gestures there.
                    if !_supportsReleaseDetection {
                        _MetricsProbe(coordinateSpace: Self.coordinateSpace)
                    }
                }
            }
            // Hybrid hold. Gesture-triggered entry sets the *margin* (UIKit
            // contentInset equivalent): changing an inset doesn't displace
            // content during overscroll, so on release the rubber-band
            // settles directly at the hold position — a spacer would shift
            // all rows down instantly and cause a visible downward jump.
            // But margins cannot animate, so at end of refresh the margin is
            // swapped for the *spacer* in one non-animated layout pass
            // (margin −60 / spacer +60: net-zero visually) and the spacer
            // then collapses inside the `finish()` animation transaction.
            // Programmatic entry (no overscroll) uses the spacer directly.
            .contentMargins(.top, holdState.headerMargin, for: .scrollContent)
            .contentMargins(.bottom, holdState.footerMargin, for: .scrollContent)
            .coordinateSpace(name: Self.coordinateSpace)
            .environment(\.iRefreshTexts, texts)
            .modifier(_ScrollPhaseModifier { interacting in
                headerEngine.handleInteraction(interacting)
                footerEngine.handleInteraction(interacting)
            })
            .modifier(_ScrollMetricsModifier { metrics in
                metricsCache.latest = metrics
                Self.drive(
                    metrics: metrics, viewportHeight: viewportHeight,
                    headerEngine: headerEngine, footerEngine: footerEngine,
                    headerTriggerDistance: headerTriggerDistance,
                    footerTriggerDistance: footerTriggerDistance,
                    footerMode: footerMode,
                    hasRefresh: onRefreshAction != nil, hasLoadMore: onLoadMoreAction != nil
                )
            })
            .onPreferenceChange(_ScrollMetricsKey.self) { [
                headerEngine, footerEngine, metricsCache,
                headerTriggerDistance, footerTriggerDistance, footerMode,
                hasRefresh = onRefreshAction != nil,
                hasLoadMore = onLoadMoreAction != nil
            ] metrics in
                MainActor.assumeIsolated {
                    metricsCache.latest = metrics
                    Self.drive(
                        metrics: metrics, viewportHeight: viewportHeight,
                        headerEngine: headerEngine, footerEngine: footerEngine,
                        headerTriggerDistance: headerTriggerDistance,
                        footerTriggerDistance: footerTriggerDistance,
                        footerMode: footerMode, hasRefresh: hasRefresh, hasLoadMore: hasLoadMore
                    )
                }
            }
            .transformPreference(_ScrollMetricsKey.self) { $0 = _ScrollMetrics() }
            .onChange(of: viewportHeight) { _, newHeight in
                Self.drive(
                    metrics: metricsCache.latest, viewportHeight: newHeight,
                    headerEngine: headerEngine, footerEngine: footerEngine,
                    headerTriggerDistance: headerTriggerDistance,
                    footerTriggerDistance: footerTriggerDistance,
                    footerMode: footerMode,
                    hasRefresh: onRefreshAction != nil, hasLoadMore: onLoadMoreAction != nil
                )
            }
            .onChange(of: headerEngine.phase) { old, new in
                headerPhaseChanged(from: old, to: new)
            }
            .onChange(of: footerEngine.phase) { old, new in
                footerPhaseChanged(from: old, to: new)
            }
            .onAppear(perform: wireController)
            .onDisappear(perform: tearDown)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var headerOverlay: some View {
        // Structurally absent while idle — an opacity-hidden view would keep
        // its idle status text alive, and an animated idle→refreshing
        // transition (programmatic `beginRefreshing()`) then crossfades that
        // stale text into view as a ghost. Inserting fresh shows the new
        // phase's content only. Also keeps idle text from showing through
        // the translucent inline navigation bar.
        if onRefreshAction != nil, headerEngine.phase != .idle {
            headerBuilder(headerEngine.context)
                .frame(maxWidth: .infinity)
                .frame(height: headerTriggerDistance)
                .offset(y: -headerTriggerDistance)
                // `.finishing` animates 1→0 inside the finish() transaction,
                // so the header (spinner included) fades out over the collapse;
                // while pulling the header fades *in* tracking pull progress.
                .opacity(headerOverlayOpacity)
        }
    }

    /// Drives the header overlay's fade. Clamped here so custom builders still
    /// see an unclamped `context.progress`.
    private var headerOverlayOpacity: Double {
        switch headerEngine.phase {
        case .finishing: return 0                              // fades out over collapse
        case .refreshing: return 1                             // programmatic entry freezes progress at 0 — must hardcode 1
        default: return min(1, max(0, headerEngine.progress))  // .pulling / .willRefresh fade in with pull
        }
    }

    @ViewBuilder
    private var pullFooterOverlay: some View {
        // Content-anchored (MJRefresh back-footer): sits just below content's
        // bottom edge and moves with the content/finger as you pull up. Pulling
        // reveals it; on `.hasMore` the appended rows ride it off-screen
        // (instant disappear); on `.noMoreData` it becomes the terminal
        // "no more data" text below content — pull up to see it.
        if onLoadMoreAction != nil, case .pull = footerMode,
           footerEngine.contentFillsViewport, footerEngine.phase != .idle {
            footerBuilder(footerEngine.context)
                .frame(maxWidth: .infinity)
                .frame(height: footerTriggerDistance)
                .offset(y: footerTriggerDistance)   // sits just below content's bottom edge
                .opacity(footerOverlayOpacity)
        }
    }

    /// Drives the pull footer's fade — mirrors `headerOverlayOpacity`.
    private var footerOverlayOpacity: Double {
        switch footerEngine.phase {
        case .pulling, .willRefresh: return min(1, max(0, footerEngine.progress))  // fade in with pull
        default: return 1   // refreshing / finishing / noMoreData
        }
    }

    /// Pushes the latest geometry into both engines. Static so the `@Sendable`
    /// `onPreferenceChange` closure can call it without capturing `self`.
    private static func drive(
        metrics: _ScrollMetrics,
        viewportHeight: CGFloat,
        headerEngine: _HeaderEngine,
        footerEngine: _FooterEngine,
        headerTriggerDistance: CGFloat,
        footerTriggerDistance: CGFloat,
        footerMode: IRefreshFooterMode,
        hasRefresh: Bool,
        hasLoadMore: Bool
    ) {
        if hasRefresh {
            let config = _HeaderEngine.Config(
                triggerDistance: headerTriggerDistance,
                supportsReleaseDetection: _supportsReleaseDetection
            )
            if headerEngine.config != config { headerEngine.config = config }
            headerEngine.handleOffset(metrics.top)
        }
        if hasLoadMore {
            let config = _FooterEngine.Config(
                mode: footerMode,
                triggerDistance: footerTriggerDistance,
                supportsReleaseDetection: _supportsReleaseDetection
            )
            if footerEngine.config != config {
                if footerEngine.config.mode != config.mode { footerEngine.reset() }
                footerEngine.config = config
            }
            let contentHeight = metrics.bottom - metrics.top
            footerEngine.handleGeometry(
                bottomDistance: metrics.bottom - viewportHeight,
                contentFillsViewport: viewportHeight > 0 && contentHeight >= viewportHeight
            )
        }
    }

    private var isAutoFooterActive: Bool {
        guard onLoadMoreAction != nil, case .auto = footerMode else { return false }
        return true
    }

    // MARK: - Phase reactions

    private func headerPhaseChanged(from old: IRefreshContext.Phase, to new: IRefreshContext.Phase) {
        footerEngine.isBlocked = headerEngine.isBusy
        controller?.isRefreshing = new == .refreshing
        if old == .pulling, new == .willRefresh {
            _Haptics.impact() // iOS 18: threshold reached, arrow flips
        }
        guard new == .refreshing else { return }
        if old == .pulling {
            _Haptics.impact() // iOS 17 threshold-trigger path
        }
        if headerEngine.pulledDistance > 0 {
            // Gesture entry: inset, instant — no displacement mid-overscroll,
            // the release bounce settles directly onto the hold.
            holdState.headerMargin = headerTriggerDistance
        } else {
            // Programmatic entry at rest: a margin would not open a visible
            // gap; grow an animatable spacer instead.
            withAnimation(.easeInOut(duration: 0.25)) {
                holdState.headerSpacer = headerTriggerDistance
            }
        }
        let action = onRefreshAction
        refreshTask = Task { [headerEngine, footerEngine, holdState, headerTriggerDistance] in
            await action?()
            guard !Task.isCancelled else { return }
            if holdState.headerMargin > 0 {
                // Net-zero swap, NOT animated: removing the top margin clamps
                // the offset up by the hold while the spacer pushes content
                // down by the same amount — no visual change, same layout pass.
                holdState.headerMargin = 0
                holdState.headerSpacer = headerTriggerDistance
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                headerEngine.finish() // overlay fade 1→0 ...
                holdState.headerSpacer = 0 // ... + spacer collapse, one transaction
            }
            footerEngine.resetNoMoreData()
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            headerEngine.didCollapse() // invisible: opacity already 0, hold already 0
        }
    }

    private func footerPhaseChanged(from old: IRefreshContext.Phase, to new: IRefreshContext.Phase) {
        headerEngine.isBlocked = footerEngine.isBusy
        controller?.isLoadingMore = new == .refreshing
        if old == .pulling, new == .willRefresh {
            _Haptics.impact() // iOS 18: threshold reached
        }
        guard new == .refreshing else { return }
        if old == .pulling {
            _Haptics.impact() // iOS 17 threshold-trigger path (pull mode)
        }
        if case .pull = footerMode {
            // Same hybrid branch shape as the header. In practice pull-mode
            // triggers always have pulledDistance > 0 (no programmatic load),
            // but keep the symmetry.
            if footerEngine.pulledDistance > 0 {
                holdState.footerMargin = footerTriggerDistance
            } else {
                withAnimation(.easeInOut(duration: 0.25)) {
                    holdState.footerSpacer = footerTriggerDistance
                }
            }
        }
        let action = onLoadMoreAction
        loadTask = Task { [footerEngine, holdState, footerTriggerDistance] in
            let result = await action?() ?? .hasMore
            guard !Task.isCancelled else { return }
            // Collapse the gesture-entry margin to a spacer (net-zero) so we can
            // drop/animate it (see header task for the swap rationale).
            if holdState.footerMargin > 0 {
                holdState.footerMargin = 0
                holdState.footerSpacer = footerTriggerDistance
            }
            footerEngine.finish(result) // .hasMore → .finishing ; .noMoreData → .noMoreData
            switch footerEngine.phase {
            case .finishing:
                // hasMore: loading vanishes immediately. The appended rows ride
                // the content-anchored footer off-screen, so remove the hold
                // with NO animation (no rebound).
                holdState.footerSpacer = 0
                footerEngine.didCollapse()
            case .noMoreData:
                // No more data: animate the held over-scroll springing back
                // (visible rebound). The content-anchored footer becomes the
                // terminal "no more data" text below content — pull up to see.
                withAnimation(.easeInOut(duration: 0.3)) {
                    holdState.footerSpacer = 0
                }
            default:
                break
            }
        }
    }

    // MARK: - Lifecycle

    private func wireController() {
        guard let controller else { return }
        controller._beginRefreshing = { [weak headerEngine] in
            // No withAnimation here: the phase reaction animates the spacer
            // (programmatic-entry branch in `headerPhaseChanged`).
            headerEngine?.beginRefreshing()
        }
        controller._resetNoMoreData = { [weak footerEngine] in
            footerEngine?.resetNoMoreData()
        }
        controller._drainPendingIntents()
    }

    private func tearDown() {
        refreshTask?.cancel()
        loadTask?.cancel()
        refreshTask = nil
        loadTask = nil
        headerEngine.reset()
        footerEngine.reset()
        holdState.headerMargin = 0
        holdState.footerMargin = 0
        holdState.headerSpacer = 0
        holdState.footerSpacer = 0
        controller?._beginRefreshing = nil
        controller?._resetNoMoreData = nil
        controller?.isRefreshing = false
        controller?.isLoadingMore = false
    }
}

// MARK: - Public entry point

public extension IRefreshScrollView where Header == IRefreshStyledHeader, Footer == IRefreshStyledFooter {
    /// Creates a refreshable container with the default classic header/footer.
    init(@ViewBuilder content: () -> Content) {
        self.init(
            content: content(),
            headerBuilder: { IRefreshStyledHeader(style: .classic, context: $0) },
            footerBuilder: { IRefreshStyledFooter(style: .classic, context: $0) }
        )
    }
}

// MARK: - Builder modifiers (same generic type)

public extension IRefreshScrollView {
    /// Enables pull-to-refresh. The animation collapses when the closure returns.
    func onRefresh(_ action: @escaping @Sendable () async -> Void) -> Self {
        var copy = self
        copy.onRefreshAction = action
        return copy
    }

    /// Enables load-more. Return `.noMoreData` to put the footer into its
    /// terminal state (re-armed by `onRefresh` completing or
    /// `IRefreshController.resetNoMoreData()`).
    func onLoadMore(
        mode: IRefreshFooterMode = .auto(prefetchDistance: 0),
        _ action: @escaping @Sendable () async -> IRefreshLoadResult
    ) -> Self {
        var copy = self
        copy.onLoadMoreAction = action
        copy.footerMode = mode
        return copy
    }

    /// Attaches a programmatic control handle. At most one `IRefreshScrollView`
    /// per controller — when attached to several, the last one to appear wins.
    func refreshController(_ controller: IRefreshController) -> Self {
        var copy = self
        copy.controller = controller
        return copy
    }

    /// Overrides the strings used by the built-in styles.
    func refreshTexts(_ texts: IRefreshTexts) -> Self {
        var copy = self
        copy.texts = texts
        return copy
    }
}

// MARK: - Builder modifiers (type-changing)

public extension IRefreshScrollView {
    /// Uses a built-in header style. `triggerDistance` is also the header height.
    func refreshHeader(
        _ style: IRefreshHeaderStyle,
        triggerDistance: CGFloat = 60
    ) -> IRefreshScrollView<Content, IRefreshStyledHeader, Footer> {
        refreshHeader(triggerDistance: triggerDistance) {
            IRefreshStyledHeader(style: style, context: $0)
        }
    }

    /// Uses a fully custom header view (Lottie, etc.). The view is laid out at
    /// exactly `triggerDistance` points tall; drive it from the context's
    /// `phase` and `progress`. `.willRefresh` only occurs on iOS 18+.
    func refreshHeader<H: View>(
        triggerDistance: CGFloat = 60,
        @ViewBuilder _ builder: @escaping (IRefreshContext) -> H
    ) -> IRefreshScrollView<Content, H, Footer> {
        IRefreshScrollView<Content, H, Footer>(
            content: content,
            headerBuilder: builder,
            footerBuilder: footerBuilder,
            onRefreshAction: onRefreshAction,
            onLoadMoreAction: onLoadMoreAction,
            footerMode: footerMode,
            headerTriggerDistance: triggerDistance,
            footerTriggerDistance: footerTriggerDistance,
            controller: controller,
            texts: texts
        )
    }

    /// Uses a built-in footer style. `triggerDistance` only matters for `.pull` mode.
    func refreshFooter(
        _ style: IRefreshFooterStyle,
        triggerDistance: CGFloat = 50
    ) -> IRefreshScrollView<Content, Header, IRefreshStyledFooter> {
        refreshFooter(triggerDistance: triggerDistance) {
            IRefreshStyledFooter(style: style, context: $0)
        }
    }

    /// Uses a fully custom footer view.
    func refreshFooter<F: View>(
        triggerDistance: CGFloat = 50,
        @ViewBuilder _ builder: @escaping (IRefreshContext) -> F
    ) -> IRefreshScrollView<Content, Header, F> {
        IRefreshScrollView<Content, Header, F>(
            content: content,
            headerBuilder: headerBuilder,
            footerBuilder: builder,
            onRefreshAction: onRefreshAction,
            onLoadMoreAction: onLoadMoreAction,
            footerMode: footerMode,
            headerTriggerDistance: headerTriggerDistance,
            footerTriggerDistance: triggerDistance,
            controller: controller,
            texts: texts
        )
    }
}
