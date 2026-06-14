//
//  _Haptics.swift
//  IRefresh
//
//  Created by ibabyblue on 2026/06/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

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
