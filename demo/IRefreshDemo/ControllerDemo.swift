import IRefresh
import SwiftUI

struct ControllerDemo: View {
    @State private var model = DemoFeedModel()
    @State private var controller = IRefreshController()

    var body: some View {
        IRefreshScrollView {
            DemoFeed(items: model.items)
        }
        .onRefresh { await model.refresh() }
        .onLoadMore { await model.loadMore() }
        .refreshController(controller)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Refresh") { controller.beginRefreshing() }
                Button("Re-arm") { controller.resetNoMoreData() }
            }
        }
        .onAppear { controller.beginRefreshing() }
        .navigationTitle("Controller")
        .navigationBarTitleDisplayMode(.inline)
    }
}
