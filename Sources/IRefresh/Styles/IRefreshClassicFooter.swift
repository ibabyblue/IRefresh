import SwiftUI

struct IRefreshClassicFooter: View {
    @Environment(\.iRefreshTexts) private var texts
    let context: IRefreshContext

    var body: some View {
        HStack(spacing: 8) {
            if context.phase == .refreshing || context.phase == .finishing {
                ProgressView()
            }
            Text(Self.statusText(for: context.phase, texts: texts))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
    }

    static func statusText(for phase: IRefreshContext.Phase, texts: IRefreshTexts) -> String {
        switch phase {
        case .idle, .pulling: texts.loadMoreIdle
        case .willRefresh: texts.willLoadMore
        case .refreshing, .finishing: texts.loadingMore
        case .noMoreData: texts.noMoreData
        }
    }
}
