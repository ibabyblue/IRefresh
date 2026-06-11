import CoreGraphics
import Testing
@testable import IRefresh

@MainActor
struct FooterEngineTests {
    private func makeAuto(prefetch: CGFloat = 0) -> _FooterEngine {
        let engine = _FooterEngine()
        engine.config = .init(mode: .auto(prefetchDistance: prefetch), triggerDistance: 50, supportsReleaseDetection: false)
        return engine
    }

    private func makePull(releaseDetection: Bool) -> _FooterEngine {
        let engine = _FooterEngine()
        engine.config = .init(mode: .pull, triggerDistance: 50, supportsReleaseDetection: releaseDetection)
        return engine
    }

    // MARK: auto mode

    @Test func autoTriggersInsidePrefetchZone() {
        let engine = makeAuto(prefetch: 100)
        engine.handleGeometry(bottomDistance: 500, contentFillsViewport: true)
        #expect(engine.phase == .idle)
        engine.handleGeometry(bottomDistance: 80, contentFillsViewport: true)
        #expect(engine.phase == .refreshing)
    }

    @Test func autoDoesNotRetriggerUntilLeavingZone() {
        let engine = makeAuto(prefetch: 100)
        engine.handleGeometry(bottomDistance: 80, contentFillsViewport: true)
        #expect(engine.phase == .refreshing)
        engine.finish(.hasMore)
        #expect(engine.phase == .idle) // auto mode has no hold to collapse
        engine.handleGeometry(bottomDistance: 80, contentFillsViewport: true)
        #expect(engine.phase == .idle) // disarmed: still inside the zone
        engine.handleGeometry(bottomDistance: 300, contentFillsViewport: true)
        engine.handleGeometry(bottomDistance: 80, contentFillsViewport: true)
        #expect(engine.phase == .refreshing) // re-armed after leaving the zone
    }

    @Test func autoIgnoresShortContent() {
        let engine = makeAuto()
        engine.handleGeometry(bottomDistance: -200, contentFillsViewport: false)
        #expect(engine.phase == .idle)
    }

    @Test func autoBlockedDoesNotTrigger() {
        let engine = makeAuto(prefetch: 100)
        engine.isBlocked = true
        engine.handleGeometry(bottomDistance: 80, contentFillsViewport: true)
        #expect(engine.phase == .idle)
    }

    // MARK: noMoreData

    @Test func noMoreDataIsTerminalUntilReset() {
        let engine = makeAuto(prefetch: 100)
        engine.handleGeometry(bottomDistance: 80, contentFillsViewport: true)
        engine.finish(.noMoreData)
        #expect(engine.phase == .noMoreData)
        engine.handleGeometry(bottomDistance: 300, contentFillsViewport: true)
        engine.handleGeometry(bottomDistance: 80, contentFillsViewport: true)
        #expect(engine.phase == .noMoreData)
        engine.resetNoMoreData()
        #expect(engine.phase == .idle)
        // After reset it must leave the zone once before re-triggering.
        engine.handleGeometry(bottomDistance: 80, contentFillsViewport: true)
        #expect(engine.phase == .idle)
        engine.handleGeometry(bottomDistance: 300, contentFillsViewport: true)
        engine.handleGeometry(bottomDistance: 80, contentFillsViewport: true)
        #expect(engine.phase == .refreshing)
    }

    // MARK: pull mode

    @Test func pullThresholdSemantics() {
        let engine = makePull(releaseDetection: false)
        engine.handleGeometry(bottomDistance: -20, contentFillsViewport: true)
        #expect(engine.phase == .pulling)
        #expect(engine.pulledDistance == 20)
        engine.handleGeometry(bottomDistance: -50, contentFillsViewport: true)
        #expect(engine.phase == .refreshing)
    }

    @Test func pullReleaseSemantics() {
        let engine = makePull(releaseDetection: true)
        engine.handleGeometry(bottomDistance: -60, contentFillsViewport: true)
        #expect(engine.phase == .willRefresh)
        engine.handleGeometry(bottomDistance: -30, contentFillsViewport: true)
        #expect(engine.phase == .pulling)
        engine.handleInteraction(false)
        #expect(engine.phase == .pulling) // cancelled
        engine.handleGeometry(bottomDistance: -60, contentFillsViewport: true)
        engine.handleInteraction(false)
        #expect(engine.phase == .refreshing)
    }

    @Test func pullLifecycleCollapses() {
        let engine = makePull(releaseDetection: false)
        engine.handleGeometry(bottomDistance: -50, contentFillsViewport: true)
        #expect(engine.phase == .refreshing)
        engine.finish(.hasMore)
        #expect(engine.phase == .finishing) // pull mode collapses its hold
        engine.didCollapse()
        #expect(engine.phase == .idle)
    }

    @Test func pullIgnoresShortContent() {
        let engine = makePull(releaseDetection: false)
        engine.handleGeometry(bottomDistance: -80, contentFillsViewport: false)
        #expect(engine.phase == .idle)
    }

    @Test func pullBlockedMidPullDoesNotTrigger() {
        let engine = makePull(releaseDetection: false)
        engine.handleGeometry(bottomDistance: -20, contentFillsViewport: true)
        #expect(engine.phase == .pulling)
        engine.isBlocked = true
        engine.handleGeometry(bottomDistance: -70, contentFillsViewport: true)
        #expect(engine.phase != .refreshing)
    }

    @Test func pullBlockedWillRefreshReleaseDoesNotTrigger() {
        let engine = makePull(releaseDetection: true)
        engine.handleGeometry(bottomDistance: -60, contentFillsViewport: true)
        #expect(engine.phase == .willRefresh)
        engine.isBlocked = true
        engine.handleInteraction(false)
        #expect(engine.phase != .refreshing)
    }

    @Test func pullResetsToIdleWhenContentStopsFillingViewport() {
        let engine = makePull(releaseDetection: true)
        engine.handleGeometry(bottomDistance: -60, contentFillsViewport: true)
        #expect(engine.phase == .willRefresh)
        engine.handleGeometry(bottomDistance: -60, contentFillsViewport: false)
        #expect(engine.phase == .idle)
        #expect(engine.pulledDistance == 0)
        engine.handleInteraction(false) // release after shrink must not trigger
        #expect(engine.phase == .idle)
    }

    @Test func autoRearmsDuringRefreshingAndHonorsLatchOrdering() {
        let engine = makeAuto(prefetch: 100)
        engine.handleGeometry(bottomDistance: 80, contentFillsViewport: true)
        #expect(engine.phase == .refreshing)
        engine.handleGeometry(bottomDistance: 300, contentFillsViewport: true) // out of zone while refreshing → re-arm
        engine.finish(.hasMore)
        #expect(engine.phase == .idle)
        engine.handleGeometry(bottomDistance: 80, contentFillsViewport: true) // back in zone, armed
        #expect(engine.phase == .refreshing)
    }

    @Test func autoDoesNotRearmWhileBlocked() {
        let engine = makeAuto(prefetch: 100)
        engine.handleGeometry(bottomDistance: 80, contentFillsViewport: true)
        #expect(engine.phase == .refreshing)
        engine.finish(.hasMore) // idle, disarmed, still in zone
        engine.isBlocked = true
        engine.handleGeometry(bottomDistance: 300, contentFillsViewport: true) // out of zone while blocked → must NOT re-arm
        engine.isBlocked = false
        engine.handleGeometry(bottomDistance: 80, contentFillsViewport: true) // back in zone: not armed → no trigger
        #expect(engine.phase == .idle)
        engine.handleGeometry(bottomDistance: 300, contentFillsViewport: true) // unblocked out-of-zone → re-arm
        engine.handleGeometry(bottomDistance: 80, contentFillsViewport: true)
        #expect(engine.phase == .refreshing)
    }

    @Test func resetReturnsToIdleAndRearms() {
        let engine = makeAuto(prefetch: 100)
        engine.handleGeometry(bottomDistance: 80, contentFillsViewport: true)
        engine.reset()
        #expect(engine.phase == .idle)
        engine.handleGeometry(bottomDistance: 80, contentFillsViewport: true)
        #expect(engine.phase == .refreshing)
    }
}
