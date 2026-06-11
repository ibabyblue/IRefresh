import IRefresh
import SwiftUI

struct MinimalDemo: View {
    @State private var model = DemoFeedModel()

    var body: some View {
        IRefreshScrollView {
            DemoFeed(items: model.items)
        }
        .onRefresh { await model.refresh() }
        .onLoadMore { await model.loadMore() }
        .refreshHeader(.minimal)
        .refreshFooter(.minimal)
        .navigationTitle("Minimal")
        .navigationBarTitleDisplayMode(.inline)
    }
}
