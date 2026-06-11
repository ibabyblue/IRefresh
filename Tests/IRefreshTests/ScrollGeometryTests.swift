import CoreGraphics
import Testing
@testable import IRefresh

struct ScrollGeometryTests {
    @Test func restingPositionYieldsZeroTop() {
        let m = _metrics(contentOffsetY: 0, topInset: 0, contentHeight: 1000)
        #expect(m.top == 0)
        #expect(m.bottom == 1000)
    }

    @Test func overscrollYieldsPositiveTop() {
        let m = _metrics(contentOffsetY: -50, topInset: 0, contentHeight: 1000)
        #expect(m.top == 50)
        #expect(m.bottom == 1050)
    }

    @Test func topInsetIsNeutralized() {
        // At rest under a 100pt inset, contentOffset.y == -100 → top must be 0.
        let m = _metrics(contentOffsetY: -100, topInset: 100, contentHeight: 1000)
        #expect(m.top == 0)
    }

    @Test func scrolledDownYieldsNegativeTop() {
        let m = _metrics(contentOffsetY: 200, topInset: 0, contentHeight: 1000)
        #expect(m.top == -200)
        #expect(m.bottom == 800)
    }
}
