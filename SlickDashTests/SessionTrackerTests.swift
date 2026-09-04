import XCTest
@testable import SlickDash

/// Mobile SessionTracker keeps out-lap skip; advanced Windows cases (pause / carCode / Seed / 85% path) are skipped.
final class SessionTrackerTests: XCTestCase {

    func testOutLapSkipThenFlyingLap() {
        let s = SessionTracker()
        _ = s.onPacket(pkt(lap: 1, lastMs: 0, bestMs: 80_000, fuel: 50))
        let afterOut = s.onPacket(pkt(lap: 2, lastMs: 90_000, bestMs: 80_000, fuel: 47))
        XCTAssertEqual(afterOut.count, 0, "first completed lap is the out-lap and must be skipped")
        XCTAssertNil(s.bestMs)

        let afterFlyer = s.onPacket(pkt(lap: 3, lastMs: 85_000, bestMs: 80_000, fuel: 44))
        XCTAssertEqual(afterFlyer.count, 1)
        XCTAssertEqual(afterFlyer.laps[0].timeMs, 85_000)
        XCTAssertEqual(afterFlyer.laps[0].lap, 2)
        XCTAssertTrue(afterFlyer.laps[0].isBest)
        XCTAssertEqual(s.bestMs, 85_000)
    }

    func testSessionBestFromLocalFlyerNotPacketBest() {
        let s = SessionTracker()
        _ = s.onPacket(pkt(lap: 1, lastMs: 0, bestMs: 70_000, fuel: 50))
        _ = s.onPacket(pkt(lap: 2, lastMs: 90_000, bestMs: 70_000, fuel: 47)) // out-lap skipped
        let r = s.onPacket(pkt(lap: 3, lastMs: 90_000, bestMs: 70_000, fuel: 44)) // flyer
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(s.bestMs, 90_000, "session best is the local flyer, not the faster packet best")
        XCTAssertEqual(r.best, 90_000)
        XCTAssertTrue(r.laps[0].isBest)
    }

    func testFuelPerLap() {
        let s = SessionTracker()
        _ = s.onPacket(pkt(lap: 5, lastMs: 85_000, bestMs: 84_000, fuel: 42))
        let r = s.onPacket(pkt(lap: 6, lastMs: 84_500, bestMs: 84_000, fuel: 39.9))
        guard let fpl = r.fuelPerLap else {
            XCTFail("expected fuelPerLap")
            return
        }
        XCTAssertEqual(fpl, 2.1, accuracy: 0.15)
        if let rem = r.rem {
            XCTAssertEqual(rem, 39.9 / fpl, accuracy: 0.5)
        }
    }

    func testFormatLapAndDelta() {
        XCTAssertEqual(formatLap(nil), "—")
        XCTAssertEqual(formatLap(0), "—")
        XCTAssertEqual(formatLap(90_000), "1:30.000")
        XCTAssertEqual(formatLap(84_539), "1:24.539")
        XCTAssertEqual(formatDelta(nil), "—")
        XCTAssertEqual(formatDelta(Double.nan), "—")
        XCTAssertEqual(formatDelta(1.25), "+1.250")
        XCTAssertEqual(formatDelta(-0.5), "−0.500")
    }

    func testLiveDeltaNilBeforeGhost() {
        let s = SessionTracker()
        let r1 = s.onPacket(pkt(lap: 1, lastMs: 0, bestMs: 80_000, fuel: 50, x: 80, z: 0))
        XCTAssertNil(r1.delta)
        let r2 = s.onPacket(pkt(lap: 1, lastMs: 0, bestMs: 80_000, fuel: 50, x: 40, z: 40))
        XCTAssertNil(r2.delta, "no ghost until a recorded flying lap installs one")
        // Out-lap complete — still no recorded lap / ghost
        let r3 = s.onPacket(pkt(lap: 2, lastMs: 80_000, bestMs: 80_000, fuel: 47, x: 80, z: 0))
        XCTAssertEqual(r3.count, 0)
        XCTAssertNil(r3.delta)
    }

    private func pkt(
        lap: Int, lastMs: Int, bestMs: Int, fuel: Double,
        capacity: Float = 100, x: Float = 0, z: Float = 0, flags: Int = 1
    ) -> TelemetryPacket {
        TelemetryPacket(
            posX: x, posZ: z, rpm: 0,
            fuelLevel: Float(fuel), fuelCapacity: capacity, speedMps: 0,
            tireFL: 0, tireFR: 0, tireRL: 0, tireRR: 0,
            currentLap: lap, bestLapMs: bestMs, lastLapMs: lastMs,
            alertMaxRpm: 8000, flags: flags, gear: 3, throttle: 0, brake: 0
        )
    }
}
