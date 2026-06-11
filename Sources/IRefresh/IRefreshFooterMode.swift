import CoreGraphics

/// How the footer triggers loading.
public enum IRefreshFooterMode: Equatable, Sendable {
    /// Triggers automatically when the bottom edge comes within `prefetchDistance` of the viewport.
    case auto(prefetchDistance: CGFloat)
    /// MJRefresh back-footer: drag the footer out, release to trigger.
    case pull
}
