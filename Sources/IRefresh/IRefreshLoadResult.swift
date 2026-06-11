/// Returned by the `onLoadMore` action.
public enum IRefreshLoadResult: Equatable, Sendable {
    case hasMore
    /// Puts the footer into its terminal no-more-data state.
    case noMoreData
}
