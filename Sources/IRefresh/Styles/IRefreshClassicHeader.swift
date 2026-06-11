import SwiftUI

struct IRefreshClassicHeader: View {
    @Environment(\.iRefreshTexts) private var texts
    let context: IRefreshContext
    let lastUpdatedKey: String?
    @State private var lastUpdated: Date?

    var body: some View {
        HStack(spacing: 8) {
            indicator
                .frame(width: 20, height: 20)
            VStack(spacing: 2) {
                Text(Self.statusText(for: context.phase, texts: texts))
                    .font(.footnote)
                if lastUpdatedKey != nil {
                    Text(lastUpdatedText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Fade everything out during the end-of-refresh beat, before the
        // container animates the hold collapse.
        .opacity(context.phase == .finishing ? 0 : 1)
        .onAppear(perform: loadLastUpdated)
        .onChange(of: context.phase) { old, new in
            if old == .refreshing, new == .finishing {
                storeLastUpdated()
            }
        }
    }

    static func statusText(for phase: IRefreshContext.Phase, texts: IRefreshTexts) -> String {
        switch phase {
        case .idle, .pulling, .noMoreData: texts.pulling
        case .willRefresh: texts.willRefresh
        case .refreshing, .finishing: texts.refreshing
        }
    }

    @ViewBuilder
    private var indicator: some View {
        switch context.phase {
        case .refreshing:
            ProgressView()
        case .finishing:
            // No spinner while the header fades out — and explicitly not the
            // arrow either (the `default:` branch would bring it back).
            Color.clear
        default:
            Image(systemName: "arrow.down")
                .font(.system(size: 14, weight: .medium))
                .rotationEffect(.degrees(context.phase == .willRefresh ? 180 : 0))
                .animation(.easeInOut(duration: 0.2), value: context.phase == .willRefresh)
                .opacity(context.phase == .idle ? 0 : 1)
        }
    }

    private var lastUpdatedText: String {
        let time = lastUpdated.map { $0.formatted(date: .omitted, time: .shortened) } ?? texts.lastUpdatedNever
        return String(format: texts.lastUpdatedFormat, time)
    }

    private var defaultsKey: String? {
        lastUpdatedKey.map { "irefresh.lastUpdated.\($0)" }
    }

    private func loadLastUpdated() {
        guard let defaultsKey else { return }
        lastUpdated = UserDefaults.standard.object(forKey: defaultsKey) as? Date
    }

    private func storeLastUpdated() {
        guard let defaultsKey else { return }
        let now = Date()
        UserDefaults.standard.set(now, forKey: defaultsKey)
        lastUpdated = now
    }
}
