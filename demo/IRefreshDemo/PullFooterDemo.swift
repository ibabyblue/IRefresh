//
//  PullFooterDemo.swift
//  IRefreshDemo
//
//  Created by ibabyblue on 2026/06/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import IRefresh
import SwiftUI

struct PullFooterDemo: View {
    @State private var model = DemoFeedModel()

    var body: some View {
        IRefreshScrollView {
            DemoFeed(items: model.items)
        }
        .onRefresh { await model.refresh() }
        .onLoadMore(mode: .pull) { await model.loadMore() }
        .refreshFooter(.classic)
        .navigationTitle("Pull Footer")
        .navigationBarTitleDisplayMode(.inline)
    }
}
