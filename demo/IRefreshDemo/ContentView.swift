//
//  ContentView.swift
//  IRefreshDemo
//
//  Created by ibabyblue on 2026/06/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import IRefresh
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Classic") { ClassicDemo() }
                NavigationLink("Minimal") { MinimalDemo() }
                NavigationLink("Lottie Header") { LottieDemo() }
                NavigationLink("Auto Footer (prefetch)") { AutoFooterDemo() }
                NavigationLink("Pull Footer") { PullFooterDemo() }
                NavigationLink("Programmatic Control") { ControllerDemo() }
            }
            .navigationTitle("IRefresh")
        }
    }
}

struct DemoItem: Identifiable {
    let id = UUID()
    let number: Int
}

@MainActor @Observable
final class DemoFeedModel {
    private(set) var items: [DemoItem] = (1...20).map(DemoItem.init(number:))
    var pageLimit = 60

    func refresh() async {
        try? await Task.sleep(for: .seconds(1.5))
        // Shuffled so a successful refresh visibly reorders the rows.
        items = (1...20).map(DemoItem.init(number:)).shuffled()
    }

    func loadMore() async -> IRefreshLoadResult {
        try? await Task.sleep(for: .seconds(1))
        // At the limit, append nothing and report exhaustion — so removing the
        // hold springs the over-scroll back as a visible rebound (instead of
        // freshly-appended rows filling the gap).
        guard items.count < pageLimit else { return .noMoreData }
        let next = items.count + 1
        let upper = min(next + 15, pageLimit + 1)
        items.append(contentsOf: (next..<upper).map(DemoItem.init(number:)))
        return .hasMore
    }
}

struct DemoFeed: View {
    let items: [DemoItem]

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(items) { item in
                DemoRow(index: item.number)
            }
        }
    }
}

struct DemoRow: View {
    let index: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hue: Double(index % 20) / 20, saturation: 0.5, brightness: 0.9))
                    .frame(width: 36, height: 36)
                Text("Row \(index)")
                Spacer()
            }
            .padding(.horizontal)
            .frame(height: 56)
            Divider().padding(.leading)
        }
    }
}
