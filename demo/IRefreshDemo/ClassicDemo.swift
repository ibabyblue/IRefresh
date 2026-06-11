import IRefresh
import SwiftUI

struct ClassicDemo: View {
    @State private var model = DemoFeedModel()

    var body: some View {
        IRefreshScrollView {
            DemoFeed(items: model.items)
        }
        .onRefresh { await model.refresh() }
        .onLoadMore { await model.loadMore() }
        .refreshHeader(.classic(lastUpdatedKey: "classic-demo"))
        .navigationTitle("Classic")
        .navigationBarTitleDisplayMode(.inline)
    }
}
