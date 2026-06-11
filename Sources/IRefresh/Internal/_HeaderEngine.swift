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
            pulledDistance = max(0, pulled)
            guard !isBlocked, pulledDistance > 0 else { return }
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
        if !isInteracting, phase == .willRefresh {
            phase = .refreshing
        }
    }

    func beginRefreshing() {
        guard phase == .idle, !isBlocked else { return }
        phase = .refreshing
    }

    func finish() {
        if phase == .refreshing { phase = .finishing }
    }

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
        guard pulledDistance >= config.triggerDistance else { return }
        phase = config.supportsReleaseDetection ? .willRefresh : .refreshing
    }
}
