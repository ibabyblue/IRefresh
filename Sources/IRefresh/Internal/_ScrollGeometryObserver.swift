import SwiftUI

/// Pure transform from scroll-geometry numbers to `_ScrollMetrics` —
/// kept as a free function so it is unit-testable.
func _metrics(contentOffsetY: CGFloat, topInset: CGFloat, contentHeight: CGFloat) -> _ScrollMetrics {
    let top = _quantize(-(contentOffsetY + topInset))
    return _ScrollMetrics(top: top, bottom: _quantize(top + contentHeight))
}

/// iOS 18+: drives metrics from `onScrollGeometryChange`, which is reliable
/// during live gestures (the GeometryReader preference probe is not).
/// Transparent on iOS 17, where the probe remains the source.
struct _ScrollMetricsModifier: ViewModifier {
    let onMetrics: (_ScrollMetrics) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollGeometryChange(for: _ScrollMetrics.self) { geometry in
                _metrics(
                    contentOffsetY: geometry.contentOffset.y,
                    topInset: geometry.contentInsets.top,
                    contentHeight: geometry.contentSize.height
                )
            } action: { _, newValue in
                onMetrics(newValue)
            }
        } else {
            content
        }
    }
}
