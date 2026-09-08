import XCTest
@testable import SlickDash

/// Mirrors Windows Salsa20ParserTests for fields the mobile TelemetryPacket parses.
final class Salsa20ParserTests: XCTestCase {

    func testSalsa20IsInvolution() {
        var key = [UInt8](repeating: 0, count: 32)
        for i in 0..<32 { key[i] = UInt8(i) }
        let nonce: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]
        let original = (0..<200).map { UInt8($0) }
        var buf = original
        Salsa20.xorInPlace(key: key, nonce: nonce, cipher: &buf)
        XCTAssertNotEqual(buf, original)
        Salsa20.xorInPlace(key: key, nonce: nonce, cipher: &buf)
        XCTAssertEqual(buf, original)
    }

    func testSalsa20FirstBlockKnownVector() {
        var key = [UInt8](repeating: 0, count: 32)
        for i in 0..<32 { key[i] = UInt8(i) }
        let nonce: [UInt8] = [9, 8, 7, 6, 5, 4, 3, 2]
        let block = Salsa20.firstBlock(key: key, nonce: nonce)
        let expectedHex = "9a550e1ba1528b269e3473558c4aeea28ace1c870be826aedebc789f60a9da410eb808928b2d8c81e6dd680f1a4e2e4f231333cf6d08efe20ff470279ccad55a"
        XCTAssertEqual(block.count, 64)
        XCTAssertEqual(block.map { String(format: "%02x", $0) }.joined(), expectedHex)
    }

    func testPacketRoundTripSmokeTest() {
        var plaintext = [UInt8](repeating: 0, count: 0x140)
        writeU32(&plaintext, 0, Gt7Crypto.magic)
        writeF32(&plaintext, 0x3C, 7250.5)   // rpm
        writeF32(&plaintext, 0x4C, 55.55)    // speed m/s
        writeF32(&plaintext, 0x44, 87.5)     // fuel level
        writeF32(&plaintext, 0x48, 100)      // fuel cap
        writeF32(&plaintext, 0x60, 90.0)     // tire FL
        writeF32(&plaintext, 0x64, 91.5)
        writeF32(&plaintext, 0x68, 92.0)
        writeF32(&plaintext, 0x6C, 93.0)
        writeF32(&plaintext, 0x04, 11.0)     // posX
        writeF32(&plaintext, 0x0C, -22.5)    // posZ
        writeI16(&plaintext, 0x74, 3)        // lap
        writeI32(&plaintext, 0x78, 84_000)   // best
        writeI32(&plaintext, 0x7C, 85_000)   // last
        writeI16(&plaintext, 0x8A, 8500)     // maxRpm
        writeI16(&plaintext, 0x8E, 1)        // flags: on track
        plaintext[0x90] = 0x04               // gear 4
        plaintext[0x91] = 200
        plaintext[0x92] = 40

        let cipher = Gt7Crypto.encryptForTest(plaintext: plaintext, ciphertextIv: 0x12345678)
        XCTAssertEqual(readU32(cipher, 0x40), 0x12345678)

        let decoded = Gt7Crypto.tryDecode(cipher)
        XCTAssertNil(decoded.reason)
        guard let packet = decoded.packet else {
            XCTFail("Decode failed")
            return
        }
        XCTAssertEqual(packet.rpm, 7250.5, accuracy: 0.01)
        XCTAssertEqual(packet.speedMps, 55.55, accuracy: 0.01)
        XCTAssertEqual(packet.fuelLevel, 87.5, accuracy: 0.01)
        XCTAssertEqual(packet.fuelCapacity, 100, accuracy: 0.01)
        XCTAssertEqual(packet.tireFL, 90.0, accuracy: 0.01)
        XCTAssertEqual(packet.tireFR, 91.5, accuracy: 0.01)
        XCTAssertEqual(packet.tireRL, 92.0, accuracy: 0.01)
        XCTAssertEqual(packet.tireRR, 93.0, accuracy: 0.01)
        XCTAssertEqual(packet.posX, 11.0, accuracy: 0.01)
        XCTAssertEqual(packet.posZ, -22.5, accuracy: 0.01)
        XCTAssertEqual(packet.gear, 4)
        XCTAssertEqual(packet.throttle, 200)
        XCTAssertEqual(packet.brake, 40)
        XCTAssertEqual(packet.currentLap, 3)
        XCTAssertEqual(packet.bestLapMs, 84_000)
        XCTAssertEqual(packet.lastLapMs, 85_000)
        XCTAssertEqual(packet.alertMaxRpm, 8500)
        XCTAssertTrue(packet.onTrack)
    }

    func testBadMagicIsDropped() {
        var plaintext = [UInt8](repeating: 0, count: 0x140)
        writeU32(&plaintext, 0, 0xDEADBEEF)
        writeF32(&plaintext, 0x3C, 1000)
        let cipher = Gt7Crypto.encryptForTest(plaintext: plaintext, ciphertextIv: 0x11111111)
        let decoded = Gt7Crypto.tryDecode(cipher)
        XCTAssertNil(decoded.packet)
        XCTAssertNotNil(decoded.reason)
        XCTAssertTrue(decoded.reason?.localizedCaseInsensitiveContains("bad magic") == true)
    }

    func testShortPacketIsDropped() {
        let decoded = Gt7Crypto.tryDecode([UInt8](repeating: 1, count: 20))
        XCTAssertNil(decoded.packet)
        XCTAssertTrue(decoded.reason?.contains("short packet") == true)
    }

    func testGearDisplay() {
        XCTAssertEqual(packet(gear: 15).gearDisplay, "N")
        XCTAssertEqual(packet(gear: 0).gearDisplay, "R")
        XCTAssertEqual(packet(gear: 4).gearDisplay, "4")
    }

    func testKeyIsFirst32BytesOfSeed() {
        let seed = Array("Simulator Interface Packet GT7 ver 0.0".utf8)
        XCTAssertEqual(Gt7Crypto.key, Array(seed.prefix(32)))
        XCTAssertEqual(Gt7Crypto.key.count, 32)
    }

    func testNonceLayout() {
        var nonce = [UInt8](repeating: 0, count: 8)
        let oiv: UInt32 = 0x12345678
        Gt7Crypto.buildNonce(oiv, into: &nonce)
        XCTAssertEqual(readU32(nonce, 0), oiv ^ 0xDEADBEAF)
        XCTAssertEqual(readU32(nonce, 4), oiv)
    }

    private func packet(gear: Int) -> TelemetryPacket {
        TelemetryPacket(
            posX: 0, posZ: 0, rpm: 0, fuelLevel: 0, fuelCapacity: 0, speedMps: 0,
            tireFL: 0, tireFR: 0, tireRL: 0, tireRR: 0,
            currentLap: 0, bestLapMs: 0, lastLapMs: 0, alertMaxRpm: 0,
            flags: 0, gear: gear, throttle: 0, brake: 0
        )
    }
}

private func writeF32(_ bytes: inout [UInt8], _ offset: Int, _ value: Float) {
    writeU32(&bytes, offset, value.bitPattern)
}

private func writeI32(_ bytes: inout [UInt8], _ offset: Int, _ value: Int) {
    writeU32(&bytes, offset, UInt32(bitPattern: Int32(value)))
}

private func writeI16(_ bytes: inout [UInt8], _ offset: Int, _ value: Int) {
    let u = UInt16(bitPattern: Int16(value))
    bytes[offset] = UInt8(u & 0xFF)
    bytes[offset + 1] = UInt8((u >> 8) & 0xFF)
}
