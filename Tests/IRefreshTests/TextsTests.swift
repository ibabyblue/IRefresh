import Testing
@testable import IRefresh

struct TextsTests {
    @Test func defaultsAreNonEmpty() {
        let texts = IRefreshTexts()
        #expect(!texts.pulling.isEmpty)
        #expect(!texts.willRefresh.isEmpty)
        #expect(!texts.refreshing.isEmpty)
        #expect(!texts.loadMoreIdle.isEmpty)
        #expect(!texts.willLoadMore.isEmpty)
        #expect(!texts.loadingMore.isEmpty)
        #expect(!texts.noMoreData.isEmpty)
        #expect(texts.lastUpdatedFormat.contains("%@"))
        #expect(!texts.lastUpdatedNever.isEmpty)
    }

    @Test func customOverrides() {
        let texts = IRefreshTexts(pulling: "custom-pulling")
        #expect(texts.pulling == "custom-pulling")
        #expect(!texts.refreshing.isEmpty)
    }
}
