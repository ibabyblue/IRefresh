import CoreGraphics

/// Snapshot of the refresh control state, passed to header/footer view builders.
public struct IRefreshContext: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        /// Dragging, below the trigger threshold.
        case pulling
        /// Dragging at/beyond the threshold, waiting for finger release. iOS 18+ only.
        case willRefresh
        /// The async action is running. For footers this means "loading more".
        case refreshing
        /// Collapse animation in flight after the action returned.
        case finishing
        /// Footer-only terminal state; headers never receive it.
        case noMoreData
    }

    public let phase: Phase
    /// pulledDistance / triggerDistance. 0...1+, overshoot allowed.
    public let progress: Double
    public let pulledDistance: CGFloat

    public init(phase: Phase, progress: Double, pulledDistance: CGFloat) {
        self.phase = phase
        self.progress = progress
        self.pulledDistance = pulledDistance
    }
}
