import CoreGraphics
import Testing
@testable import IRefresh

struct CoreModelTests {
    @Test func contextStoresValues() {
        let ctx = IRefreshContext(phase: .pulling, progress: 0.5, pulledDistance: 30)
        #expect(ctx.phase == .pulling)
        #expect(ctx.progress == 0.5)
        #expect(ctx.pulledDistance == 30)
    }

    @Test func phaseCoversAllStates() {
        let phases: [IRefreshContext.Phase] = [.idle, .pulling, .willRefresh, .refreshing, .finishing, .noMoreData]
        #expect(Set(phases.map(String.init(describing:))).count == 6)
    }

    @Test func footerModeEquality() {
        #expect(IRefreshFooterMode.auto(prefetchDistance: 0) == .auto(prefetchDistance: 0))
        #expect(IRefreshFooterMode.auto(prefetchDistance: 0) != .auto(prefetchDistance: 100))
        #expect(IRefreshFooterMode.auto(prefetchDistance: 0) != .pull)
    }

    @Test func loadResultEquality() {
        #expect(IRefreshLoadResult.hasMore != IRefreshLoadResult.noMoreData)
    }
}
