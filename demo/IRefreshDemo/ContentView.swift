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

@MainActor @Observable
final class DemoFeedModel {
    private(set) var items: [Int] = Array(1...20)
    var pageLimit = 60

    func refresh() async {
        try? await Task.sleep(for: .seconds(1.5))
        items = Array(1...20)
    }

    func loadMore() async -> IRefreshLoadResult {
        try? await Task.sleep(for: .seconds(1))
        let next = items.count + 1
        items.append(contentsOf: next..<(next + 15))
        return items.count >= pageLimit ? .noMoreData : .hasMore
    }
}

struct DemoFeed: View {
    let items: [Int]

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(items, id: \.self) { index in
                DemoRow(index: index)
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
