//
//  HeaderEngineTests.swift
//  IRefreshTests
//
//  Created by ibabyblue on 2026/06/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import Testing
@testable import IRefresh

@MainActor
struct HeaderEngineTests {
    private func makeEngine(releaseDetection: Bool) -> _HeaderEngine {
        let engine = _HeaderEngine()
        engine.config = .init(triggerDistance: 60, supportsReleaseDetection: releaseDetection)
        return engine
    }

    // MARK: threshold semantics (iOS 17 path)

    @Test func thresholdTriggersAtTriggerDistance() {
        let engine = makeEngine(releaseDetection: false)
        engine.handleOffset(30)
        #expect(engine.phase == .pulling)
        #expect(engine.progress == 0.5)
        engine.handleOffset(60)
        #expect(engine.phase == .refreshing)
    }

    @Test func thresholdNeverEntersWillRefresh() {
        let engine = makeEngine(releaseDetection: false)
        engine.handleOffset(59.5)
        #expect(engine.phase == .pulling)
        engine.handleOffset(80)
        #expect(engine.phase == .refreshing)
    }

    // MARK: release semantics (iOS 18+ path)

    @Test func releaseSemanticsWaitsForRelease() {
        let engine = makeEngine(releaseDetection: true)
        engine.handleInteraction(true)
        engine.handleOffset(70)
        #expect(engine.phase == .willRefresh)
        engine.handleInteraction(false)
        #expect(engine.phase == .refreshing)
    }

    @Test func pullBackBelowThresholdCancels() {
        let engine = makeEngine(releaseDetection: true)
        engine.handleInteraction(true)
        engine.handleOffset(70)
        #expect(engine.phase == .willRefresh)
        engine.handleOffset(40)
        #expect(engine.phase == .pulling)
        engine.handleInteraction(false)
        #expect(engine.phase == .pulling) // release below threshold must NOT trigger
    }

    @Test func returnToZeroGoesIdle() {
        let engine = makeEngine(releaseDetection: true)
        engine.handleInteraction(true)
        engine.handleOffset(40)
        #expect(engine.phase == .pulling)
        engine.handleOffset(0)
        #expect(engine.phase == .idle)
    }

    @Test func offsetWithoutInteractionStaysIdleOnReleasePath() {
        let engine = makeEngine(releaseDetection: true)
        engine.handleOffset(70) // transient geometry, no finger down
        #expect(engine.phase == .idle)
    }

    @Test func thresholdPathUnaffectedByInteraction() {
        let engine = makeEngine(releaseDetection: false) // iOS 17: no interaction signal exists
        engine.handleOffset(30)
        #expect(engine.phase == .pulling)
    }

    // MARK: lifecycle

    @Test func fullLifecycle() {
        let engine = makeEngine(releaseDetection: false)
        engine.handleOffset(60)
        #expect(engine.phase == .refreshing)
        engine.handleOffset(0) // offsets ignored while refreshing
        #expect(engine.phase == .refreshing)
        engine.finish()
        #expect(engine.phase == .finishing)
        engine.handleOffset(80) // ignored while finishing
        #expect(engine.phase == .finishing)
        engine.didCollapse()
        #expect(engine.phase == .idle)
        #expect(engine.pulledDistance == 0)
    }

    @Test func beginRefreshingFromIdle() {
        let engine = makeEngine(releaseDetection: false)
        engine.beginRefreshing()
        #expect(engine.phase == .refreshing)
        engine.beginRefreshing() // no-op while refreshing
        #expect(engine.phase == .refreshing)
    }

    @Test func blockedEngineIgnoresInputs() {
        let engine = makeEngine(releaseDetection: false)
        engine.isBlocked = true
        engine.handleOffset(100)
        #expect(engine.phase == .idle)
        engine.beginRefreshing()
        #expect(engine.phase == .idle)
    }

    @Test func blockingMidPullPreventsThresholdTrigger() {
        let engine = makeEngine(releaseDetection: false)
        engine.handleOffset(30)
        #expect(engine.phase == .pulling)
        engine.isBlocked = true
        engine.handleOffset(70)
        #expect(engine.phase != .refreshing)
    }

    @Test func blockingMidPullPreventsReleaseTrigger() {
        let engine = makeEngine(releaseDetection: true)
        engine.handleInteraction(true)
        engine.handleOffset(70)
        #expect(engine.phase == .willRefresh)
        engine.isBlocked = true
        engine.handleInteraction(false)
        #expect(engine.phase != .refreshing)
    }

    @Test func blockedIdleEngineDoesNotReportProgress() {
        let engine = makeEngine(releaseDetection: false)
        engine.isBlocked = true
        engine.handleOffset(100)
        #expect(engine.pulledDistance == 0)
        #expect(engine.progress == 0)
    }

    @Test func resetReturnsToIdle() {
        let engine = makeEngine(releaseDetection: false)
        engine.handleOffset(60)
        engine.reset()
        #expect(engine.phase == .idle)
        #expect(engine.pulledDistance == 0)
    }

    @Test func zeroTriggerDistanceYieldsZeroProgress() {
        let engine = _HeaderEngine()
        engine.config = .init(triggerDistance: 0, supportsReleaseDetection: false)
        #expect(engine.progress == 0)
    }
}
