import IRefresh
import SwiftUI

struct AutoFooterDemo: View {
    @State private var model = DemoFeedModel()

    var body: some View {
        IRefreshScrollView {
            DemoFeed(items: model.items)
        }
        .onRefresh { await model.refresh() }
        .onLoadMore(mode: .auto(prefetchDistance: 300)) { await model.loadMore() }
        .navigationTitle("Auto Footer")
        .navigationBarTitleDisplayMode(.inline)
    }
}
