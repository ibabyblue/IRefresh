//
//  _FooterEngine.swift
//  IRefresh
//
//  Created by ibabyblue on 2026/06/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import CoreGraphics
import Observation

/// Pure state machine for the load-more footer. `bottomDistance` is the gap
/// between the content's bottom edge and the viewport's bottom edge:
/// positive = content extends below the viewport, 0 = exactly at the bottom,
/// negative = dragged beyond the bottom (rubber band).
@MainActor @Observable
final class _FooterEngine {
    struct Config: Equatable {
        var mode: IRefreshFooterMode = .auto(prefetchDistance: 0)
        var triggerDistance: CGFloat = 50
        var supportsReleaseDetection = false
    }

    var config = Config()
    /// Set by the container while the header is busy (mutual exclusion).
    var isBlocked = false
    private(set) var phase: IRefreshContext.Phase = .idle
    private(set) var pulledDistance: CGFloat = 0
    /// Last reported viewport-fill state; the container hides the pull-mode
    /// footer overlay while the content is shorter than the viewport.
    private(set) var contentFillsViewport = false
    /// Auto mode: prevents machine-gun triggering while sitting in the zone.
    private var isArmed = true
    /// iOS 18+ gate (pull mode): transient transition/bounce geometry must not
    /// enter `.pulling` without a finger down. iOS 17 has no interaction
    /// signal, so the gate is bypassed there. Mirrors a physical fact, so
    /// `reset()` does not clear it.
    private var isInteracting = false

    var progress: Double {
        guard config.triggerDistance > 0 else { return 0 }
        return Double(pulledDistance / config.triggerDistance)
    }

    var context: IRefreshContext {
        IRefreshContext(phase: phase, progress: progress, pulledDistance: pulledDistance)
    }

    var isBusy: Bool { phase == .refreshing || phase == .finishing }

    func handleGeometry(bottomDistance: CGFloat, contentFillsViewport: Bool) {
        self.contentFillsViewport = contentFillsViewport
        switch config.mode {
        case .auto(let prefetchDistance):
            handleAuto(bottomDistance: bottomDistance, prefetch: prefetchDistance, contentFillsViewport: contentFillsViewport)
        case .pull:
            handlePull(pulledUp: max(0, -bottomDistance), contentFillsViewport: contentFillsViewport)
        }
    }

    /// iOS 18+ only, pull mode: release while at/over the threshold triggers.
    func handleInteraction(_ isInteracting: Bool) {
        self.isInteracting = isInteracting
        if !isInteracting, phase == .willRefresh, !isBlocked {
            phase = .refreshing
        }
    }

    /// Call when the load action returns. `.hasMore` in pull mode enters
    /// `.finishing` and must be followed by `didCollapse()`; in auto mode it
    /// returns straight to `.idle`. `.noMoreData` is terminal until
    /// `resetNoMoreData()`.
    func finish(_ result: IRefreshLoadResult) {
        guard phase == .refreshing else { return }
        switch result {
        case .noMoreData:
            phase = .noMoreData
        case .hasMore:
            if case .pull = config.mode {
                phase = .finishing
            } else {
                phase = .idle
            }
        }
    }

    /// Completes the `finish(.hasMore)` → collapse handshake (pull mode).
    func didCollapse() {
        if phase == .finishing {
            phase = .idle
            pulledDistance = 0
        }
    }

    /// Re-arms a footer that reached `.noMoreData`. Requires leaving the
    /// prefetch zone once before the next auto trigger.
    func resetNoMoreData() {
        if phase == .noMoreData {
            phase = .idle
            isArmed = false
        }
    }

    /// Full reset for data-source replacement. Unlike `resetNoMoreData()`, this
    /// re-arms immediately (`isArmed = true`): if the content is already inside
    /// the prefetch zone, the next geometry event triggers a load.
    func reset() {
        phase = .idle
        pulledDistance = 0
        isArmed = true
        contentFillsViewport = false
    }

    private func handleAuto(bottomDistance: CGFloat, prefetch: CGFloat, contentFillsViewport: Bool) {
        if bottomDistance > prefetch, !isBlocked { isArmed = true }
        guard phase == .idle, !isBlocked, contentFillsViewport else { return }
        if bottomDistance <= prefetch, isArmed {
            isArmed = false
            phase = .refreshing
        }
    }

    private func handlePull(pulledUp: CGFloat, contentFillsViewport: Bool) {
        guard contentFillsViewport else {
            if phase == .pulling || phase == .willRefresh {
                phase = .idle
                pulledDistance = 0
            }
            return
        }
        switch phase {
        case .idle:
            guard !isBlocked else { return }
            pulledDistance = pulledUp
            guard pulledDistance > 0, isInteracting || !config.supportsReleaseDetection else { return }
            phase = .pulling
            evaluateThreshold()
        case .pulling:
            pulledDistance = pulledUp
            if pulledDistance <= 0 {
                phase = .idle
            } else {
                evaluateThreshold()
            }
        case .willRefresh:
            pulledDistance = pulledUp
            if pulledDistance < config.triggerDistance {
                phase = pulledDistance > 0 ? .pulling : .idle
            }
        case .refreshing, .finishing, .noMoreData:
            break
        }
    }

    private func evaluateThreshold() {
        guard pulledDistance >= config.triggerDistance, !isBlocked else { return }
        phase = config.supportsReleaseDetection ? .willRefresh : .refreshing
    }
}
