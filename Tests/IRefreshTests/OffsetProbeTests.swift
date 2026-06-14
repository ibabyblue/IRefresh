//
//  OffsetProbeTests.swift
//  IRefreshTests
//
//  Created by ibabyblue on 2026/06/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import CoreGraphics
import Testing
@testable import IRefresh

struct OffsetProbeTests {
    @Test func quantizeRoundsToHalfPoint() {
        #expect(_quantize(10.3) == 10.5)
        #expect(_quantize(10.2) == 10.0)
        #expect(_quantize(-3.8) == -4.0)
        #expect(_quantize(0) == 0)
    }

    @Test func metricsReduceKeepsLastValue() {
        var value = _ScrollMetrics()
        _ScrollMetricsKey.reduce(value: &value) { _ScrollMetrics(top: 12, bottom: 800) }
        #expect(value == _ScrollMetrics(top: 12, bottom: 800))
    }
}
