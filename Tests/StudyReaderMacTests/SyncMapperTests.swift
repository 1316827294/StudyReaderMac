import XCTest
@testable import StudyReaderMac

final class SyncMapperTests: XCTestCase {
    func testClampBoundsFiniteFractions() {
        XCTAssertEqual(SyncMapper.clamp(-0.2), 0)
        XCTAssertEqual(SyncMapper.clamp(0.4), 0.4)
        XCTAssertEqual(SyncMapper.clamp(1.4), 1)
    }

    func testClampHandlesNonFiniteValues() {
        XCTAssertEqual(SyncMapper.clamp(.nan), 0)
        XCTAssertEqual(SyncMapper.clamp(.infinity), 0)
    }

    func testFractionFromScrollableContent() {
        let fraction = SyncMapper.fraction(contentOffset: 250, viewportHeight: 500, contentHeight: 1500)
        XCTAssertEqual(fraction, 0.25, accuracy: 0.0001)
    }

    func testFractionForUnscrollableContentIsZero() {
        let fraction = SyncMapper.fraction(contentOffset: 250, viewportHeight: 500, contentHeight: 400)
        XCTAssertEqual(fraction, 0)
    }

    func testContentOffsetRoundTrip() {
        let offset = SyncMapper.contentOffset(for: 0.75, viewportHeight: 200, contentHeight: 1000)
        XCTAssertEqual(offset, 600, accuracy: 0.0001)
    }
}
