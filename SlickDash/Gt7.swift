import Foundation
import Network

enum Salsa20 {
    static let sigma = Array("expand 32-byte k".utf8)
    static func xorInPlace(key: [UInt8], nonce: [UInt8], cipher: inout [UInt8]) {
        var state = [UInt32](repeating: 0, count: 16)
        func u32(_ b: [UInt8], _ o: Int) -> UInt32 {
            UInt32(b[o]) | UInt32(b[o+1]) << 8 | UInt32(b[o+2]) << 16 | UInt32(b[o+3]) << 24
        }
        state[0] = u32(sigma, 0); state[5] = u32(sigma, 4)
        state[10] = u32(sigma, 8); state[15] = u32(sigma, 12)
        for i in 0..<4 { state[1+i] = u32(key, i*4); state[11+i] = u32(key, 16+i*4) }
        state[6] = u32(nonce, 0); state[7] = u32(nonce, 4)
        var block = [UInt8](repeating: 0, count: 64)
        var offset = 0
        while offset < cipher.count {
            generate(state, &block)
            let take = min(64, cipher.count - offset)
            for i in 0..<take { cipher[offset+i] ^= block[i] }
            offset += take
            state[8] &+= 1
            if state[8] == 0 { state[9] &+= 1 }
        }
    }
    static func rotl(_ v: UInt32, _ c: Int) -> UInt32 { (v << c) | (v >> (32 - c)) }
    static func generate(_ input: [UInt32], _ out: inout [UInt8]) {
        var x = input
        for _ in 0..<10 {
            x[4] ^= rotl(x[0] &+ x[12], 7); x[8] ^= rotl(x[4] &+ x[0], 9)
            x[12] ^= rotl(x[8] &+ x[4], 13); x[0] ^= rotl(x[12] &+ x[8], 18)
            x[9] ^= rotl(x[5] &+ x[1], 7); x[13] ^= rotl(x[9] &+ x[5], 9)
            x[1] ^= rotl(x[13] &+ x[9], 13); x[5] ^= rotl(x[1] &+ x[13], 18)
            x[14] ^= rotl(x[10] &+ x[6], 7); x[2] ^= rotl(x[14] &+ x[10], 9)
            x[6] ^= rotl(x[2] &+ x[14], 13); x[10] ^= rotl(x[6] &+ x[2], 18)
            x[3] ^= rotl(x[15] &+ x[11], 7); x[7] ^= rotl(x[3] &+ x[15], 9)
            x[11] ^= rotl(x[7] &+ x[3], 13); x[15] ^= rotl(x[11] &+ x[7], 18)
            x[1] ^= rotl(x[0] &+ x[3], 7); x[2] ^= rotl(x[1] &+ x[0], 9)
            x[3] ^= rotl(x[2] &+ x[1], 13); x[0] ^= rotl(x[3] &+ x[2], 18)
            x[6] ^= rotl(x[5] &+ x[4], 7); x[7] ^= rotl(x[6] &+ x[5], 9)
            x[4] ^= rotl(x[7] &+ x[6], 13); x[5] ^= rotl(x[4] &+ x[7], 18)
            x[11] ^= rotl(x[10] &+ x[9], 7); x[8] ^= rotl(x[11] &+ x[10], 9)
            x[9] ^= rotl(x[8] &+ x[11], 13); x[10] ^= rotl(x[9] &+ x[8], 18)
            x[12] ^= rotl(x[15] &+ x[14], 7); x[13] ^= rotl(x[12] &+ x[15], 9)
            x[14] ^= rotl(x[13] &+ x[12], 13); x[15] ^= rotl(x[14] &+ x[13], 18)
        }
        for i in 0..<16 {
            let v = x[i] &+ input[i]
            out[i*4] = UInt8(v & 0xff); out[i*4+1] = UInt8((v >> 8) & 0xff)
            out[i*4+2] = UInt8((v >> 16) & 0xff); out[i*4+3] = UInt8((v >> 24) & 0xff)
        }
    }
}

enum Gt7Crypto {
    static let magic: UInt32 = 0x47375330
    static let key: [UInt8] = Array("Simulator Interface Packet GT7 ver 0.0".utf8) + Array(repeating: 0, count: 32)
    static func tryDecode(_ raw: [UInt8]) -> TelemetryPacket? {
        guard raw.count >= TelemetryPacket.minSize else { return nil }
        var buf = raw
        func u32(_ b: [UInt8], _ o: Int) -> UInt32 {
            UInt32(b[o]) | UInt32(b[o+1]) << 8 | UInt32(b[o+2]) << 16 | UInt32(b[o+3]) << 24
        }
        let oiv = u32(buf, 0x40)
        var nonce = [UInt8](repeating: 0, count: 8)
        let xored = oiv ^ 0xDEADBEAF
        for i in 0..<4 { nonce[i] = UInt8((xored >> (8*i)) & 0xff); nonce[4+i] = UInt8((oiv >> (8*i)) & 0xff) }
        let k = Array(key.prefix(32))
        Salsa20.xorInPlace(key: k, nonce: nonce, cipher: &buf)
        if u32(buf, 0) != magic { return nil }
        return TelemetryPacket.parse(buf)
    }
}

struct TelemetryPacket {
    static let minSize = 0x128
    var posX, posZ, rpm, fuelLevel, fuelCapacity, speedMps: Float
    var tireFL, tireFR, tireRL, tireRR: Float
    var currentLap, bestLapMs, lastLapMs, alertMaxRpm, flags, gear, throttle, brake: Int
    var speedKph: Double { Double(speedMps) * 3.6 }
    var fuelPercent: Double { fuelCapacity > 0 ? Double(fuelLevel / fuelCapacity) * 100 : Double(fuelLevel) }
    var throttlePct: Int { Int(Double(throttle) / 255 * 100) }
    var brakePct: Int { Int(Double(brake) / 255 * 100) }
    var rpmFrac: Float { min(1, max(0, rpm / Float(max(alertMaxRpm, 1)))) }
    var gearDisplay: String { switch gear { case 0: return "R"; case 15: return "N"; default: return "\(gear)" } }
    var onTrack: Bool { flags & 1 != 0 && flags & 2 == 0 && flags & 4 == 0 }
    static func parse(_ p: [UInt8]) -> TelemetryPacket {
        func f(_ o: Int) -> Float {
            var v: UInt32 = UInt32(p[o]) | UInt32(p[o+1])<<8 | UInt32(p[o+2])<<16 | UInt32(p[o+3])<<24
            return Float(bitPattern: v)
        }
        func i16(_ o: Int) -> Int { Int(Int16(bitPattern: UInt16(p[o]) | UInt16(p[o+1]) << 8)) }
        func i32(_ o: Int) -> Int {
            Int(Int32(bitPattern: UInt32(p[o]) | UInt32(p[o+1])<<8 | UInt32(p[o+2])<<16 | UInt32(p[o+3])<<24))
        }
        let gears = Int(p[0x90])
        return TelemetryPacket(posX: f(0x04), posZ: f(0x0C), rpm: f(0x3C), fuelLevel: f(0x44), fuelCapacity: f(0x48),
            speedMps: f(0x4C), tireFL: f(0x60), tireFR: f(0x64), tireRL: f(0x68), tireRR: f(0x6C),
            currentLap: i16(0x74), bestLapMs: i32(0x78), lastLapMs: i32(0x7C), alertMaxRpm: i16(0x8A),
            flags: i16(0x8E), gear: gears & 0x0F, throttle: Int(p[0x91]), brake: Int(p[0x92]))
    }
}

final class Gt7UdpClient {
    static let sendPort: NWEndpoint.Port = 33739
    static let recvPort: NWEndpoint.Port = 33740
    private var conn: NWConnection?
    private var listener: NWListener?
    var onPacket: ((TelemetryPacket) -> Void)?
    var onRaw: (() -> Void)?
    var onErr: (() -> Void)?
    var onPeer: ((String) -> Void)?
    var onStatus: ((String) -> Void)?
    private var peer: String?
    private var hb: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "gt7.udp")
    private var discovering = false
    private var broadcastConn: NWConnection?

    func startDiscover() {
        stop()
        discovering = true
        peer = nil
        onStatus?("Looking for GT7 on this network…")
        bindReceive()
        heartbeat(to: "255.255.255.255")
    }
    func startHost(_ ip: String) {
        stop()
        discovering = false
        peer = ip
        onStatus?("Heartbeat → \(ip)")
        bindReceive()
        heartbeat(to: ip)
    }
    func stop() {
        hb?.cancel(); hb = nil
        listener?.cancel(); listener = nil
        broadcastConn?.cancel(); broadcastConn = nil
        conn?.cancel(); conn = nil
    }
    private func bindReceive() {
        do {
            let l = try NWListener(using: .udp, on: Self.recvPort)
            l.newConnectionHandler = { [weak self] c in
                c.start(queue: self?.queue ?? .main)
                self?.receive(c)
            }
            l.start(queue: queue)
            listener = l
        } catch {
            onStatus?("bind :33740 failed: \(error.localizedDescription)")
        }
    }
    private func heartbeat(to host: String) {
        let c = NWConnection(host: NWEndpoint.Host(host), port: Self.sendPort, using: .udp)
        c.start(queue: queue)
        broadcastConn = c
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: 0.25)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            let dest = self.peer ?? host
            let conn = NWConnection(host: NWEndpoint.Host(dest), port: Self.sendPort, using: .udp)
            conn.start(queue: self.queue)
            conn.send(content: Data([UInt8(ascii: "A")]), completion: .contentProcessed { _ in conn.cancel() })
        }
        t.resume()
        hb = t
    }
    private func receive(_ c: NWConnection) {
        c.receiveMessage { [weak self] data, _, _, _ in
            defer { self?.receive(c) }
            guard let self, let data, !data.isEmpty else { return }
            self.onRaw?()
            let bytes = [UInt8](data)
            guard let pkt = Gt7Crypto.tryDecode(bytes) else { self.onErr?(); return }
            if self.peer == nil {
                if case let .hostPort(host, _) = c.endpoint {
                    let ip = "\(host)"
                    self.peer = ip
                    self.discovering = false
                    DispatchQueue.main.async { self.onPeer?(ip); self.onStatus?("Connected \(ip)") }
                }
            }
            DispatchQueue.main.async { self.onPacket?(pkt) }
        }
    }
}

struct LapRow: Identifiable { let id = UUID(); let lap: Int; let timeMs: Int; let isBest: Bool }

final class SessionTracker {
    private var laps: [LapRow] = []
    private var lastLapIndex = -1
    private var lastLapMsSeen = 0
    private var completedFlying = 0
    private var fuelAtStart: Double?
    private var fuelPerLap: Double?
    private var ghost: [(Float, Float, Float)] = []
    private var current: [(Float, Float, Float)] = []
    private var lapT0 = Date()
    private var trace: [Float] = []
    private var heldDelta: Double?
    private var lastSampleX: Float?
    private var lastSampleZ: Float?
    private(set) var bestMs: Int?

    /// Reset stint when GT7 starts a new race (lap counter drops).
    private func resetStint() {
        laps = []
        lastLapIndex = -1
        lastLapMsSeen = 0
        completedFlying = 0
        fuelAtStart = nil
        fuelPerLap = nil
        ghost = []
        current = []
        lapT0 = Date()
        trace = []
        heldDelta = nil
        lastSampleX = nil
        lastSampleZ = nil
        bestMs = nil
    }

    func onPacket(_ p: TelemetryPacket) -> (
        fuelPerLap: Double?, rem: Double?, stops: Int, last: Int?, best: Int?,
        delta: Double?, trace: [Float], laps: [LapRow], count: Int
    ) {
        if lastLapIndex >= 0 && p.currentLap >= 0 && p.currentLap < lastLapIndex {
            resetStint()
        }

        if p.currentLap != lastLapIndex {
            if lastLapIndex >= 0 && p.lastLapMs > 0 && p.lastLapMs != lastLapMsSeen {
                completedFlying += 1
                if completedFlying > 1 {
                    laps.append(LapRow(lap: lastLapIndex, timeMs: p.lastLapMs, isBest: false))
                    if laps.count > 100 { laps.removeFirst() }
                    relabelBest()
                    if bestMs == p.lastLapMs && current.count >= 2 {
                        ghost = current
                    }
                }
                lastLapMsSeen = p.lastLapMs
                if let s = fuelAtStart {
                    let used = max(0, s - p.fuelPercent)
                    if used > 0.2 { fuelPerLap = used }
                }
            }
            lastLapIndex = p.currentLap
            fuelAtStart = p.fuelPercent
            current = []
            lastSampleX = nil
            lastSampleZ = nil
            lapT0 = Date()
            heldDelta = nil
        }

        let t = Float(Date().timeIntervalSince(lapT0))
        if p.onTrack {
            appendSample(x: p.posX, z: p.posZ, t: t)
        }
        let d = liveDelta(x: p.posX, z: p.posZ, t: t)
        if let d {
            heldDelta = d
            trace.append(Float(d))
            if trace.count > 120 { trace.removeFirst() }
        }
        let rem = (fuelPerLap ?? 0) > 0.05 ? p.fuelPercent / (fuelPerLap ?? 1) : nil
        // Session best is local flyers only — never GT7 packet PB.
        return (fuelPerLap, rem, (rem ?? 99) < 8 ? 1 : 0, p.lastLapMs > 0 ? p.lastLapMs : nil,
                bestMs, d ?? heldDelta, Array(trace), Array(laps.suffix(12)), laps.count)
    }

    private func relabelBest() {
        let best = laps.map(\.timeMs).min()
        bestMs = best
        var marked = false
        laps = laps.map { row in
            let isBest = !marked && best == row.timeMs
            if isBest { marked = true }
            return LapRow(lap: row.lap, timeMs: row.timeMs, isBest: isBest)
        }
    }

    private func appendSample(x: Float, z: Float, t: Float) {
        if let lx = lastSampleX, let lz = lastSampleZ {
            let dist = hypot(Double(x - lx), Double(z - lz))
            if dist < 1.0 { return }
        }
        current.append((x, z, t))
        lastSampleX = x
        lastSampleZ = z
        if current.count > 4096 { current.removeFirst() }
    }

    private func liveDelta(x: Float, z: Float, t: Float) -> Double? {
        guard ghost.count >= 2 else { return nil }
        var best = Double.greatestFiniteMagnitude
        var gT = ghost[0].2
        for s in ghost {
            let d = hypot(Double(s.0 - x), Double(s.1 - z))
            if d < best { best = d; gT = s.2 }
        }
        // Far off the ghost line — hold last good delta when we have one.
        if best > 32 { return nil }
        return Double(t - gT)
    }
}

func formatLap(_ ms: Int?) -> String {
    guard let ms, ms > 0 else { return "—" }
    return String(format: "%d:%02d.%03d", ms/60000, (ms%60000)/1000, ms%1000)
}
func formatDelta(_ d: Double?) -> String {
    guard let d, !d.isNaN else { return "—" }
    return d < 0 ? String(format: "−%.3f", -d) : String(format: "+%.3f", d)
}
