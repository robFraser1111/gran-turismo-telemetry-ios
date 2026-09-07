import Foundation

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
    var currentLap, totalLaps, bestLapMs, lastLapMs, alertMaxRpm, flags, gear, throttle, brake, carCode: Int
    var speedKph: Double { Double(speedMps) * 3.6 }
    var fuelPercent: Double { fuelCapacity > 0 ? Double(fuelLevel / fuelCapacity) * 100 : Double(fuelLevel) }
    var throttlePct: Int { Int(Double(throttle) / 255 * 100) }
    var brakePct: Int { Int(Double(brake) / 255 * 100) }
    var throttleNorm: Double { Double(throttle) / 255 }
    var brakeNorm: Double { Double(brake) / 255 }
    var rpmFrac: Float { min(1, max(0, rpm / Float(max(alertMaxRpm, 1)))) }
    var gearDisplay: String { switch gear { case 0: return "R"; case 15: return "N"; default: return "\(gear)" } }
    /// Car on track, not paused, not loading — same as Windows IsRacing.
    var onTrack: Bool { flags & 1 != 0 && flags & 2 == 0 && flags & 4 == 0 }
    var isPaused: Bool { flags & 2 != 0 }
    var isLoading: Bool { flags & 4 != 0 }
    var isRacing: Bool { onTrack }
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
            currentLap: i16(0x74), totalLaps: i16(0x76), bestLapMs: i32(0x78), lastLapMs: i32(0x7C),
            alertMaxRpm: i16(0x8A), flags: i16(0x8E), gear: gears & 0x0F, throttle: Int(p[0x91]), brake: Int(p[0x92]),
            carCode: p.count >= 0x128 ? i32(0x124) : 0)
    }
}

enum QualityRating: String { case poor = "Poor"; case fair = "Fair"; case good = "Good"
    static func classify(packetsPerSecond: Double, errorRatio: Double) -> QualityRating {
        let err = min(1, max(0, errorRatio))
        if packetsPerSecond >= 40 && err < 0.08 { return .good }
        if packetsPerSecond >= 12 && err < 0.25 { return .fair }
        return .poor
    }
}

final class Gt7UdpClient {
    static let sendPort: UInt16 = 33739
    static let recvPort: UInt16 = 33740
    var onPacket: ((TelemetryPacket) -> Void)?
    var onRaw: (() -> Void)?
    var onErr: (() -> Void)?
    var onPeer: ((String) -> Void)?
    var onStatus: ((String) -> Void)?

    private let queue = DispatchQueue(label: "gt7.udp")
    private var running = false
    private var sock: Int32 = -1
    private var peer: String?
    private var discovering = false
    private var heartbeatTargets: [String] = []

    func startDiscover() {
        stop()
        discovering = true
        peer = nil
        heartbeatTargets = Self.broadcastAddresses()
        onStatus?("Looking for GT7 on this network…")
        startLoop()
    }

    func startHost(_ ip: String) {
        stop()
        discovering = false
        peer = ip
        heartbeatTargets = [ip]
        onStatus?("Heartbeat → \(ip)")
        startLoop()
    }

    func stop() {
        running = false
        let fd = sock
        sock = -1
        if fd >= 0 { Darwin.close(fd) }
    }

    private func startLoop() {
        running = true
        queue.async { [weak self] in self?.runLoop() }
    }

    private func runLoop() {
        let fd = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else {
            DispatchQueue.main.async { self.onStatus?("UDP socket failed") }
            return
        }
        sock = fd
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = Self.sendPort.bigEndian // placeholder; set recv below
        addr.sin_port = Self.recvPort.bigEndian
        addr.sin_addr = in_addr(s_addr: INADDR_ANY.bigEndian)
        let bindOk: Bool = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
        guard bindOk else {
            DispatchQueue.main.async { self.onStatus?("bind :33740 failed") }
            Darwin.close(fd)
            if sock == fd { sock = -1 }
            return
        }

        var tv = timeval(tv_sec: 0, tv_usec: 50_000)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var lastHb = Date.distantPast
        var buf = [UInt8](repeating: 0, count: 4096)
        while running {
            let now = Date()
            if now.timeIntervalSince(lastHb) > 0.25 {
                lastHb = now
                let targets: [String]
                if let peer {
                    targets = [peer]
                } else {
                    targets = heartbeatTargets.isEmpty ? ["255.255.255.255"] : heartbeatTargets
                }
                for host in targets {
                    Self.sendHeartbeat(fd: fd, host: host, port: Self.sendPort)
                }
            }

            var src = sockaddr_in()
            var srcLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n: Int = withUnsafeMutablePointer(to: &src) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    Darwin.recvfrom(fd, &buf, buf.count, 0, sa, &srcLen)
                }
            }
            guard n > 0 else { continue }
            DispatchQueue.main.async { self.onRaw?() }
            let bytes = Array(buf.prefix(n))
            guard let pkt = Gt7Crypto.tryDecode(bytes) else {
                DispatchQueue.main.async { self.onErr?() }
                continue
            }
            if peer == nil {
                let ip = Self.ipString(src.sin_addr)
                if !ip.isEmpty && ip != "0.0.0.0" {
                    peer = ip
                    discovering = false
                    DispatchQueue.main.async {
                        self.onPeer?(ip)
                        self.onStatus?("Connected \(ip)")
                    }
                }
            }
            DispatchQueue.main.async { self.onPacket?(pkt) }
        }
        if sock == fd {
            Darwin.close(fd)
            sock = -1
        }
    }

    private static func sendHeartbeat(fd: Int32, host: String, port: UInt16) {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard host.withCString({ inet_pton(AF_INET, $0, &addr.sin_addr) }) == 1 else { return }
        var payload: [UInt8] = [UInt8(ascii: "A")]
        _ = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.sendto(fd, &payload, 1, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }

    private static func ipString(_ addr: in_addr) -> String {
        var addr = addr
        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &addr, &buf, socklen_t(INET_ADDRSTRLEN)) != nil else { return "" }
        return String(cString: buf)
    }

    /// Global broadcast plus per-interface directed broadcasts (matches Android).
    private static func broadcastAddresses() -> [String] {
        var out: [String] = ["255.255.255.255"]
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return out }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            defer { ptr = p.pointee.ifa_next }
            let flags = Int32(p.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
            guard let dst = p.pointee.ifa_dstaddr else { continue }
            guard dst.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            let broad = dst.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            let ip = ipString(broad)
            if !ip.isEmpty { out.append(ip) }
        }
        return Array(Set(out)).sorted()
    }
}

struct LapRow: Identifiable { let id = UUID(); let lap: Int; let timeMs: Int; let isBest: Bool }

final class SessionTracker {
    private static let flyerPathFraction = 0.85
    private static let maxMatchDistanceM = 32.0

    private var laps: [LapRow] = []
    private var lastLapIndex = -1
    private var lastLapMsSeen = 0
    private var completedFlying = 0
    private var fuelAtStart: Double?
    private var fuelSamples: [Double] = []
    private var ghost: [(Float, Float, Float)] = []
    private var current: [(Float, Float, Float)] = []
    private var lapT0 = Date()
    private var pauseStarted: Date?
    private var trace: [Float] = []
    private var heldDelta: Double?
    private var ghostMatchIndex = -1
    private var ghostBestMs = 0
    private var ghostPathM = 0.0
    private var maxPathM = 0.0
    private var lastSampleX: Float?
    private var lastSampleZ: Float?
    private var carCode = 0
    private var hasCarCode = false
    private(set) var bestMs: Int?

    private var fuelPerLap: Double? {
        guard !fuelSamples.isEmpty else { return nil }
        return fuelSamples.reduce(0, +) / Double(fuelSamples.count)
    }

    private func resetStint() {
        laps = []; lastLapIndex = -1; lastLapMsSeen = 0; completedFlying = 0
        fuelAtStart = nil; fuelSamples = []; ghost = []; current = []
        lapT0 = Date(); pauseStarted = nil; trace = []; heldDelta = nil
        ghostMatchIndex = -1; ghostBestMs = 0; ghostPathM = 0; maxPathM = 0
        lastSampleX = nil; lastSampleZ = nil; bestMs = nil
    }

    func onPacket(_ p: TelemetryPacket) -> (
        fuelPerLap: Double?, rem: Double?, stops: Int, last: Int?, best: Int?,
        delta: Double?, trace: [Float], laps: [LapRow], count: Int
    ) {
        if hasCarCode && p.carCode != 0 && p.carCode != carCode { resetStint() }
        if !hasCarCode && p.carCode != 0 { carCode = p.carCode; hasCarCode = true }
        if lastLapIndex >= 0 && p.currentLap >= 0 && p.currentLap < lastLapIndex { resetStint() }

        if !p.isRacing {
            if pauseStarted == nil { pauseStarted = Date() }
            heldDelta = nil
            ghostMatchIndex = -1
            let fpl = fuelPerLap
            let rem = (fpl ?? 0) > 0.05 ? p.fuelPercent / (fpl ?? 1) : nil
            return (fpl, rem, predictedStops(fuelPct: p.fuelPercent, rem: rem, totalLaps: p.totalLaps, currentLap: p.currentLap),
                    p.lastLapMs > 0 ? p.lastLapMs : nil, bestMs, nil, [], Array(laps.suffix(12)), laps.count)
        }

        if let ps = pauseStarted {
            lapT0 = lapT0.addingTimeInterval(Date().timeIntervalSince(ps))
            pauseStarted = nil
            ghostMatchIndex = ghost.isEmpty ? -1 : 0
        }

        if p.currentLap != lastLapIndex {
            if lastLapIndex >= 0 && p.lastLapMs > 0 && p.lastLapMs != lastLapMsSeen {
                completedFlying += 1
                if let s = fuelAtStart {
                    let used = max(0, s - p.fuelPercent)
                    if used > 0.3 && used < 25 {
                        fuelSamples.append(used)
                        if fuelSamples.count > 12 { fuelSamples.removeFirst() }
                    }
                }
                if completedFlying > 1 {
                    recordFlyer(lap: lastLapIndex, timeMs: p.lastLapMs)
                }
                lastLapMsSeen = p.lastLapMs
            }
            lastLapIndex = p.currentLap
            fuelAtStart = p.fuelPercent
            current = []; lastSampleX = nil; lastSampleZ = nil
            lapT0 = Date()
            heldDelta = nil
        }

        let t = Float(Date().timeIntervalSince(lapT0))
        appendSample(x: p.posX, z: p.posZ, t: t)
        let d = liveDelta(x: p.posX, z: p.posZ, t: t)
        if let d {
            heldDelta = d
            trace.append(Float(d))
            if trace.count > 120 { trace.removeFirst() }
        }
        let fpl = fuelPerLap
        let rem = (fpl ?? 0) > 0.05 ? p.fuelPercent / (fpl ?? 1) : nil
        return (fpl, rem, predictedStops(fuelPct: p.fuelPercent, rem: rem, totalLaps: p.totalLaps, currentLap: p.currentLap),
                p.lastLapMs > 0 ? p.lastLapMs : nil, bestMs, d ?? heldDelta, Array(trace), Array(laps.suffix(12)), laps.count)
    }

    private func predictedStops(fuelPct: Double, rem: Double?, totalLaps: Int, currentLap: Int) -> Int {
        let fpl = fuelPerLap ?? 2.1
        let raceLeft = totalLaps > 0 ? max(0, totalLaps - max(currentLap, 0)) : 0
        if raceLeft <= 0 {
            return (fuelPct < 50 && (rem ?? 99) < 8) ? 1 : 0
        }
        let need = Double(raceLeft) * fpl
        let extra = need - fuelPct
        return extra <= 0.5 ? 0 : Int((extra / 100.0).rounded(.up))
    }

    private func recordFlyer(lap: Int, timeMs: Int) {
        if let last = current.indices.last {
            current[last].2 = Float(timeMs) / 1000
        }
        let path = pathLengthM(current)
        laps.append(LapRow(lap: lap, timeMs: timeMs, isBest: false))
        if laps.count > 100 { laps.removeFirst() }
        relabelBest()

        let eligible = current.count >= 2 && timeMs > 0
        if eligible {
            if path > maxPathM { maxPathM = path }
            let install = ghost.count < 2
                || (timeMs < ghostBestMs && path >= Self.flyerPathFraction * ghostPathM)
            if install {
                ghost = current
                ghostBestMs = timeMs
                ghostPathM = path
            }
        }
        ghostMatchIndex = ghost.isEmpty ? -1 : 0
        current = []
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
            if hypot(Double(x - lx), Double(z - lz)) < 1.0 { return }
        }
        current.append((x, z, t))
        lastSampleX = x; lastSampleZ = z
        if current.count > 4096 { current.removeFirst() }
    }

    private func pathLengthM(_ samples: [(Float, Float, Float)]) -> Double {
        guard samples.count > 1 else { return 0 }
        var sum = 0.0
        for i in 1..<samples.count {
            sum += hypot(Double(samples[i].0 - samples[i-1].0), Double(samples[i].1 - samples[i-1].1))
        }
        return sum
    }

    private func liveDelta(x: Float, z: Float, t: Float) -> Double? {
        guard ghost.count >= 2, let idx = findGhostMatch(x: x, z: z, elapsed: t) else { return nil }
        let g = ghost[idx]
        if hypot(Double(g.0 - x), Double(g.1 - z)) > Self.maxMatchDistanceM { return nil }
        ghostMatchIndex = idx
        let d = Double(t - g.2)
        if abs(d) > 30 && idx < max(2, ghost.count / 10) {
            ghostMatchIndex = -1
            return nil
        }
        return d
    }

    private func findGhostMatch(x: Float, z: Float, elapsed: Float) -> Int? {
        let n = ghost.count
        guard n > 0 else { return nil }
        let start: Int
        let count: Int
        if ghostMatchIndex < 0 {
            start = 0; count = n
        } else {
            let fwd = min(n, max(32, n / 8))
            let back = min(n, max(8, n / 32))
            start = (ghostMatchIndex - back + n) % n
            count = min(n, back + fwd + 1)
        }
        var bestIdx = -1
        var bestDistSq = Double.greatestFiniteMagnitude
        for i in 0..<count {
            let idx = (start + i) % n
            let g = ghost[idx]
            let d = hypot(Double(g.0 - x), Double(g.1 - z))
            let dsq = d * d
            if dsq < bestDistSq { bestDistSq = dsq; bestIdx = idx }
        }
        guard bestIdx >= 0 else { return nil }
        let near = bestDistSq + 16
        var chosen = bestIdx
        var bestElapsedErr = abs(Double(elapsed) - Double(ghost[bestIdx].2))
        for i in 0..<count {
            let idx = (start + i) % n
            let g = ghost[idx]
            let dsq = pow(Double(g.0 - x), 2) + pow(Double(g.1 - z), 2)
            if dsq > near { continue }
            let err = abs(Double(elapsed) - Double(g.2))
            if err < bestElapsedErr { bestElapsedErr = err; chosen = idx }
        }
        return chosen
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
