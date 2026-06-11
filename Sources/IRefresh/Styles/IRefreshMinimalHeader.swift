import SwiftUI

struct IRefreshMinimalHeader: View {
    let context: IRefreshContext

    var body: some View {
        ZStack {
            switch context.phase {
            case .refreshing:
                ProgressView()
            case .finishing:
                Color.clear
            default:
                Circle()
                    .trim(from: 0, to: min(context.progress, 1))
                    .stroke(.secondary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 22, height: 22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
