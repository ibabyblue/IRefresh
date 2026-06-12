import SwiftUI

/// Reference-typed cache of the latest scroll metrics, so a viewport-only
/// resize (which doesn't fire `onPreferenceChange`) can still re-drive the
/// engines with up-to-date geometry.
@MainActor
final class _MetricsCache {
    var latest = _ScrollMetrics()
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
                    content
                        .overlay(alignment: .top) { headerOverlay }
                        .overlay(alignment: .bottom) { pullFooterOverlay }

                    if isAutoFooterActive {
                        footerBuilder(footerEngine.context)
                            .frame(maxWidth: .infinity)
                    }
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
            // The refresh/load "hold" is a content margin (UIKit contentInset
            // equivalent), NOT a spacer in the content: changing an inset
            // doesn't displace content during overscroll, so on release the
            // rubber-band settles directly at the hold position — a spacer
            // would shift all rows down instantly and cause a visible
            // downward jump before the bounce-back.
            .contentMargins(.top, headerHoldHeight, for: .scrollContent)
            .contentMargins(.bottom, footerHoldHeight, for: .scrollContent)
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
                // so the header (spinner included) fades out over the collapse.
                .opacity(headerEngine.phase == .finishing ? 0 : 1)
        }
    }

    @ViewBuilder
    private var pullFooterOverlay: some View {
        if onLoadMoreAction != nil, case .pull = footerMode, footerEngine.contentFillsViewport,
           footerEngine.phase != .idle {
            footerBuilder(footerEngine.context)
                .frame(maxWidth: .infinity)
                .frame(height: footerTriggerDistance)
                .offset(y: footerTriggerDistance)
                // Structurally absent while idle, matching the header overlay;
                // fades out over the collapse while `.finishing`.
                .opacity(footerEngine.phase == .finishing ? 0 : 1)
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

    /// Top content margin while refreshing — the inset the bounce settles at.
    private var headerHoldHeight: CGFloat {
        headerEngine.phase == .refreshing ? headerTriggerDistance : 0
    }

    /// Bottom content margin while loading more (`.pull` mode only).
    private var footerHoldHeight: CGFloat {
        guard case .pull = footerMode else { return 0 }
        return footerEngine.phase == .refreshing ? footerTriggerDistance : 0
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
        let action = onRefreshAction
        refreshTask = Task { [headerEngine, footerEngine] in
            await action?()
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                headerEngine.finish() // hold 60→0 + overlay fade 1→0, one transaction
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
        let action = onLoadMoreAction
        loadTask = Task { [footerEngine] in
            let result = await action?() ?? .hasMore
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                footerEngine.finish(result) // hold collapse + overlay fade, one transaction
            }
            if footerEngine.phase == .finishing {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                footerEngine.didCollapse() // invisible: opacity already 0, hold already 0
            }
        }
    }

    // MARK: - Lifecycle

    private func wireController() {
        guard let controller else { return }
        controller._beginRefreshing = { [weak headerEngine] in
            withAnimation(.easeInOut(duration: 0.25)) {
                headerEngine?.beginRefreshing()
            }
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
