import CoreGraphics
import Observation

/// Pure state machine for the pull-to-refresh header. No UI, no side effects:
/// the container observes `phase` transitions and runs tasks/haptics/animation.
@MainActor @Observable
final class _HeaderEngine {
    struct Config: Equatable {
        var triggerDistance: CGFloat = 60
        var supportsReleaseDetection = false
    }

    var config = Config()
    /// Set by the container while the footer is busy (mutual exclusion).
    var isBlocked = false
    private(set) var phase: IRefreshContext.Phase = .idle
    private(set) var pulledDistance: CGFloat = 0
    /// iOS 18+ gate: transient transition/bounce geometry (e.g. NavigationStack
    /// push insets) must not enter `.pulling` without a finger down. iOS 17 has
    /// no interaction signal, so the gate is bypassed there. Mirrors a physical
    /// fact, so `reset()` does not clear it.
    private var isInteracting = false

    var progress: Double {
        guard config.triggerDistance > 0 else { return 0 }
        return Double(pulledDistance / config.triggerDistance)
    }

    var context: IRefreshContext {
        IRefreshContext(phase: phase, progress: progress, pulledDistance: pulledDistance)
    }

    var isBusy: Bool { phase == .refreshing || phase == .finishing }

    /// `pulled` is the content-top overshoot in points (>= 0 when over-dragged).
    func handleOffset(_ pulled: CGFloat) {
        switch phase {
        case .idle:
            guard !isBlocked else { return }
            pulledDistance = max(0, pulled)
            guard pulledDistance > 0, isInteracting || !config.supportsReleaseDetection else { return }
            phase = .pulling
            evaluateThreshold()
        case .pulling:
            pulledDistance = max(0, pulled)
            if pulledDistance <= 0 {
                phase = .idle
            } else {
                evaluateThreshold()
            }
        case .willRefresh:
            pulledDistance = max(0, pulled)
            if pulledDistance < config.triggerDistance {
                phase = pulledDistance > 0 ? .pulling : .idle
            }
        case .refreshing, .finishing, .noMoreData:
            break
        }
    }

    /// iOS 18+ only: scroll phase transitions. Release while at/over the
    /// threshold triggers the refresh.
    func handleInteraction(_ isInteracting: Bool) {
        self.isInteracting = isInteracting
        if !isInteracting, phase == .willRefresh, !isBlocked {
            phase = .refreshing
        }
    }

    /// Programmatic trigger. Effective only from `.idle` while not blocked;
    /// otherwise a silent no-op (an in-flight user gesture wins).
    func beginRefreshing() {
        guard phase == .idle, !isBlocked else { return }
        phase = .refreshing
    }

    /// Call when the refresh action returns. Must be followed by `didCollapse()`
    /// once the collapse animation ends, or the engine stays frozen in
    /// `.finishing` (escape hatch: `reset()`).
    func finish() {
        if phase == .refreshing { phase = .finishing }
    }

    /// Completes the `finish()` → collapse handshake, returning to `.idle`.
    func didCollapse() {
        if phase == .finishing {
            phase = .idle
            pulledDistance = 0
        }
    }

    func reset() {
        phase = .idle
        pulledDistance = 0
    }

    private func evaluateThreshold() {
        guard pulledDistance >= config.triggerDistance, !isBlocked else { return }
        phase = config.supportsReleaseDetection ? .willRefresh : .refreshing
    }
}
