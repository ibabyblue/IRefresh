import IRefresh
import Lottie
import SwiftUI

struct LottieDemo: View {
    @State private var model = DemoFeedModel()

    var body: some View {
        IRefreshScrollView {
            DemoFeed(items: model.items)
        }
        .onRefresh { await model.refresh() }
        .refreshHeader(triggerDistance: 70) { context in
            LottieRefreshHeader(context: context)
        }
        .navigationTitle("Lottie Header")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A custom header: pull progress scrubs the animation, refreshing loops it.
struct LottieRefreshHeader: View {
    let context: IRefreshContext

    var body: some View {
        Group {
            switch context.phase {
            case .refreshing, .finishing:
                LottieView(animation: .named("refresh_loading"))
                    .playing(loopMode: .loop)
            default:
                LottieView(animation: .named("refresh_loading"))
                    .currentProgress(min(context.progress, 1))
            }
        }
        .frame(height: 60)
    }
}
