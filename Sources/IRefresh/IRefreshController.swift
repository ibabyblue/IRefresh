import Observation

/// Optional programmatic handle. Create one, keep it in `@State`, and attach
/// it via `IRefreshScrollView.refreshController(_:)`.
@MainActor @Observable
public final class IRefreshController {
    /// True while the `onRefresh` action is running.
    public internal(set) var isRefreshing = false
    /// True while the `onLoadMore` action is running.
    public internal(set) var isLoadingMore = false

    @ObservationIgnored var _beginRefreshing: (() -> Void)?
    @ObservationIgnored var _resetNoMoreData: (() -> Void)?

    public init() {}

    /// Programmatically start a pull-to-refresh (e.g. on first appearance).
    /// No-op while a refresh or load-more is already running, or before the
    /// controller is attached to an `IRefreshScrollView`.
    public func beginRefreshing() {
        _beginRefreshing?()
    }

    /// Re-arm a footer that reached `.noMoreData`.
    public func resetNoMoreData() {
        _resetNoMoreData?()
    }
}
