import Testing
@testable import IRefresh

struct StyleTests {
    private let texts = IRefreshTexts(
        pulling: "P", willRefresh: "W", refreshing: "R",
        loadMoreIdle: "I", willLoadMore: "WL", loadingMore: "L",
        noMoreData: "N", lastUpdatedFormat: "U %@", lastUpdatedNever: "Never"
    )

    @Test func classicHeaderStatusTextMapping() {
        #expect(IRefreshClassicHeader.statusText(for: .idle, texts: texts) == "P")
        #expect(IRefreshClassicHeader.statusText(for: .pulling, texts: texts) == "P")
        #expect(IRefreshClassicHeader.statusText(for: .willRefresh, texts: texts) == "W")
        #expect(IRefreshClassicHeader.statusText(for: .refreshing, texts: texts) == "R")
        #expect(IRefreshClassicHeader.statusText(for: .finishing, texts: texts) == "R")
    }

    @Test func classicFooterStatusTextMapping() {
        #expect(IRefreshClassicFooter.statusText(for: .idle, texts: texts) == "I")
        #expect(IRefreshClassicFooter.statusText(for: .pulling, texts: texts) == "I")
        #expect(IRefreshClassicFooter.statusText(for: .willRefresh, texts: texts) == "WL")
        #expect(IRefreshClassicFooter.statusText(for: .refreshing, texts: texts) == "L")
        #expect(IRefreshClassicFooter.statusText(for: .finishing, texts: texts) == "L")
        #expect(IRefreshClassicFooter.statusText(for: .noMoreData, texts: texts) == "N")
    }

    @Test func headerStyleFactories() {
        if case .classic(let key) = IRefreshHeaderStyle.classic.kind {
            #expect(key == nil)
        } else {
            Issue.record("expected classic kind")
        }
        if case .classic(let key) = IRefreshHeaderStyle.classic(lastUpdatedKey: "feed").kind {
            #expect(key == "feed")
        } else {
            Issue.record("expected classic kind")
        }
        if case .minimal = IRefreshHeaderStyle.minimal.kind {} else {
            Issue.record("expected minimal kind")
        }
    }
}
