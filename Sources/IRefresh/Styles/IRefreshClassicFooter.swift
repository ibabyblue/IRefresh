import SwiftUI

struct IRefreshClassicFooter: View {
    @Environment(\.iRefreshTexts) private var texts
    let context: IRefreshContext

    var body: some View {
        HStack(spacing: 8) {
            if context.phase == .refreshing {
                ProgressView()
            }
            Text(Self.statusText(for: context.phase, texts: texts))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        // Fade everything out during the end-of-load beat, before the
        // container animates the hold collapse.
        .opacity(context.phase == .finishing ? 0 : 1)
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
