//
//  LottieDemo.swift
//  IRefreshDemo
//
//  Created by ibabyblue on 2026/06/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

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

/// A custom header: static while pulling (fades in via the container's
/// progress-based opacity), loops while refreshing.
struct LottieRefreshHeader: View {
    let context: IRefreshContext

    var body: some View {
        Group {
            switch context.phase {
            case .refreshing, .finishing:
                LottieView(animation: .named("refresh_loading"))
                    .playing(loopMode: .loop)
            default:
                // While pulling: static first frame; the container fades the
                // whole header in with pull progress (no scrubbing/playing).
                LottieView(animation: .named("refresh_loading"))
                    .currentProgress(0)
            }
        }
        .frame(height: 60)
    }
}
