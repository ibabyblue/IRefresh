import SwiftUI

/// Frame of the scroll content (the outer VStack) in the ScrollView's named
/// coordinate space. `top > 0` means pulled down beyond the natural top.
struct _ScrollMetrics: Equatable, Sendable {
    var top: CGFloat = 0
    var bottom: CGFloat = 0
}

struct _ScrollMetricsKey: PreferenceKey {
    static let defaultValue = _ScrollMetrics()
    static func reduce(value: inout _ScrollMetrics, nextValue: () -> _ScrollMetrics) {
        value = nextValue()
    }
}

/// Quantize to 0.5pt so the preference doesn't fire on sub-pixel churn.
@inline(__always)
func _quantize(_ value: CGFloat) -> CGFloat {
    (value * 2).rounded() / 2
}

/// Place as `.background` of the scroll content.
struct _MetricsProbe: View {
    let coordinateSpace: String

    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .named(coordinateSpace))
            Color.clear.preference(
                key: _ScrollMetricsKey.self,
                value: _ScrollMetrics(top: _quantize(frame.minY), bottom: _quantize(frame.maxY))
            )
        }
    }
}
