#if canImport(UIKit)
import UIKit
#endif

enum _Haptics {
    @MainActor
    static func impact() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}
