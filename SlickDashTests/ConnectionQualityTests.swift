import XCTest
@testable import SlickDash

final class ConnectionQualityTests: XCTestCase {

    func testClassifiesPacketRateAndErrors() {
        let cases: [(Double, Double, QualityRating)] = [
            (60, 0.0, .good),
            (45, 0.05, .good),
            (20, 0.1, .fair),
            (12, 0.2, .fair),
            (5, 0.0, .poor),
            (50, 0.5, .poor),
            (0, 1, .poor),
        ]
        for (pps, err, expected) in cases {
            XCTAssertEqual(
                ConnectionQuality.classify(packetsPerSecond: pps, errorRatio: err),
                expected,
                "pps=\(pps) err=\(err)"
            )
        }
    }
}
