import SwiftUI
import Testing
@testable import IRefresh

@MainActor
struct ScrollViewModifierTests {
    @Test func defaultsAreApplied() {
        let view = IRefreshScrollView { Text("content") }
        #expect(view.onRefreshAction == nil)
        #expect(view.onLoadMoreAction == nil)
        #expect(view.footerMode == .auto(prefetchDistance: 0))
        #expect(view.headerTriggerDistance == 60)
        #expect(view.footerTriggerDistance == 50)
        #expect(view.controller == nil)
    }

    @Test func builderModifiersStoreConfig() {
        let controller = IRefreshController()
        let texts = IRefreshTexts(pulling: "x")
        let view = IRefreshScrollView { Text("content") }
            .onRefresh {}
            .onLoadMore(mode: .pull) { .noMoreData }
            .refreshController(controller)
            .refreshTexts(texts)
        #expect(view.onRefreshAction != nil)
        #expect(view.onLoadMoreAction != nil)
        #expect(view.footerMode == .pull)
        #expect(view.controller === controller)
        #expect(view.texts.pulling == "x")
    }

    @Test func styledHeaderModifierKeepsConfig() {
        let view = IRefreshScrollView { Text("content") }
            .onRefresh {}
            .refreshHeader(.minimal, triggerDistance: 80)
            .refreshFooter(.minimal, triggerDistance: 70)
        #expect(view.headerTriggerDistance == 80)
        #expect(view.footerTriggerDistance == 70)
        #expect(view.onRefreshAction != nil)
    }

    @Test func customBuilderModifierChangesGenericAndKeepsConfig() {
        let controller = IRefreshController()
        let view = IRefreshScrollView { Text("content") }
            .onRefresh {}
            .refreshController(controller)
            .refreshHeader { _ in Color.red }
        #expect(view.onRefreshAction != nil)
        #expect(view.controller === controller)
    }
}
