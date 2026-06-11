import Testing
@testable import IRefresh

@MainActor
struct ControllerTests {
    @Test func forwardsIntentsToRegisteredHandlers() {
        let controller = IRefreshController()
        var began = 0
        var resets = 0
        controller._beginRefreshing = { began += 1 }
        controller._resetNoMoreData = { resets += 1 }
        controller.beginRefreshing()
        controller.beginRefreshing()
        controller.resetNoMoreData()
        #expect(began == 2)
        #expect(resets == 1)
    }

    @Test func intentsBeforeAttachmentAreReplayedOnDrain() {
        let controller = IRefreshController()
        controller.beginRefreshing()
        controller.resetNoMoreData()
        var began = 0
        var resets = 0
        controller._beginRefreshing = { began += 1 }
        controller._resetNoMoreData = { resets += 1 }
        controller._drainPendingIntents()
        #expect(began == 1)
        #expect(resets == 1)
        controller._drainPendingIntents() // flags consumed — no replay
        #expect(began == 1)
        #expect(resets == 1)
    }

    @Test func intentsAreNoOpsWhenUnattached() {
        let controller = IRefreshController()
        controller.beginRefreshing() // must not crash
        controller.resetNoMoreData()
        #expect(controller.isRefreshing == false)
        #expect(controller.isLoadingMore == false)
    }
}
