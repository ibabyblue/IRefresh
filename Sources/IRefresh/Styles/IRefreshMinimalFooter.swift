import SwiftUI

struct IRefreshMinimalFooter: View {
    @Environment(\.iRefreshTexts) private var texts
    let context: IRefreshContext

    var body: some View {
        ZStack {
            switch context.phase {
            case .refreshing, .finishing:
                ProgressView()
            case .noMoreData:
                Text(texts.noMoreData)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            default:
                Color.clear
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
    }
}
