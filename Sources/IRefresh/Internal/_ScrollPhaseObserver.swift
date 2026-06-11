import SwiftUI

/// True when the OS can tell us the finger left the screen (release-to-refresh
/// semantics). False on iOS 17, where IRefresh falls back to threshold-trigger.
var _supportsReleaseDetection: Bool {
    if #available(iOS 18.0, macOS 15.0, *) {
        return true
    }
    return false
}

/// Applies `onScrollPhaseChange` where available; transparent otherwise.
struct _ScrollPhaseModifier: ViewModifier {
    let onInteractionChange: (Bool) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollPhaseChange { _, newPhase in
                onInteractionChange(newPhase == .interacting)
            }
        } else {
            content
        }
    }
}
