import SwiftUI

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
                    Color.clear
                        .frame(height: headerHoldHeight)
                        .animation(.easeInOut(duration: 0.25), value: headerHoldHeight)

                    content
                        .overlay(alignment: .top) { headerOverlay }
                        .overlay(alignment: .bottom) { pullFooterOverlay }

                    if isAutoFooterActive {
                        footerBuilder(footerEngine.context)
                            .frame(maxWidth: .infinity)
                    }

                    Color.clear
                        .frame(height: footerHoldHeight)
                        .animation(.easeInOut(duration: 0.25), value: footerHoldHeight)
                }
                .background { _MetricsProbe(coordinateSpace: Self.coordinateSpace) }
            }
            .coordinateSpace(name: Self.coordinateSpace)
            .environment(\.iRefreshTexts, texts)
            .modifier(_ScrollPhaseModifier { interacting in
                headerEngine.handleInteraction(interacting)
                footerEngine.handleInteraction(interacting)
            })
            .onPreferenceChange(_ScrollMetricsKey.self) { [
                headerEngine, footerEngine,
                headerTriggerDistance, footerTriggerDistance, footerMode,
                hasRefresh = onRefreshAction != nil,
                hasLoadMore = onLoadMoreAction != nil
            ] metrics in
                MainActor.assumeIsolated {
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
                            contentFillsViewport: contentHeight >= viewportHeight
                        )
                    }
                }
            }
            .transformPreference(_ScrollMetricsKey.self) { $0 = _ScrollMetrics() }
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
        if onRefreshAction != nil {
            headerBuilder(headerEngine.context)
                .frame(maxWidth: .infinity)
                .frame(height: headerTriggerDistance)
                .offset(y: -headerTriggerDistance)
        }
    }

    @ViewBuilder
    private var pullFooterOverlay: some View {
        if onLoadMoreAction != nil, case .pull = footerMode {
            footerBuilder(footerEngine.context)
                .frame(maxWidth: .infinity)
                .frame(height: footerTriggerDistance)
                .offset(y: footerTriggerDistance)
        }
    }

    private var isAutoFooterActive: Bool {
        guard onLoadMoreAction != nil, case .auto = footerMode else { return false }
        return true
    }

    private var headerHoldHeight: CGFloat {
        headerEngine.phase == .refreshing ? headerTriggerDistance : 0
    }

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
            headerEngine.finish()
            footerEngine.resetNoMoreData()
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            headerEngine.didCollapse()
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
            footerEngine.finish(result)
            if footerEngine.phase == .finishing {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                footerEngine.didCollapse()
            }
        }
    }

    // MARK: - Lifecycle

    private func wireController() {
        guard let controller else { return }
        controller._beginRefreshing = { [weak headerEngine] in
            headerEngine?.beginRefreshing()
        }
        controller._resetNoMoreData = { [weak footerEngine] in
            footerEngine?.resetNoMoreData()
        }
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
