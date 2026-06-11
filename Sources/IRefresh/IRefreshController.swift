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

    @ObservationIgnored private var _pendingBegin = false
    @ObservationIgnored private var _pendingReset = false

    public init() {}

    /// Programmatically start a pull-to-refresh (e.g. on first appearance).
    /// No-op while a refresh or load-more is already running. Called before
    /// the controller is attached to an `IRefreshScrollView`, the intent is
    /// queued and replayed once attachment completes.
    public func beginRefreshing() {
        if let _beginRefreshing {
            _beginRefreshing()
        } else {
            _pendingBegin = true
        }
    }

    /// Re-arm a footer that reached `.noMoreData`. Called before the
    /// controller is attached to an `IRefreshScrollView`, the intent is
    /// queued and replayed once attachment completes.
    public func resetNoMoreData() {
        if let _resetNoMoreData {
            _resetNoMoreData()
        } else {
            _pendingReset = true
        }
    }

    /// Replays intents that were fired before attachment. Called by
    /// `IRefreshScrollView` right after wiring the closures.
    func _drainPendingIntents() {
        if _pendingBegin {
            _pendingBegin = false
            _beginRefreshing?()
        }
        if _pendingReset {
            _pendingReset = false
            _resetNoMoreData?()
        }
    }
}
