import SwiftUI

@main
struct SlickDashApp: App {
    @StateObject var model = DashModel()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(model) }
    }
}

enum Mode: String, CaseIterable { case simple = "Simple"; case driving = "Driving"; case pit = "Pit wall" }

final class DashModel: ObservableObject {
    @Published var mode: Mode = .simple
    @Published var settings = false
    @Published var live = false
    @Published var peer: String?
    @Published var status = "Waiting for telemetry"
    @Published var rx = 0
    @Published var dec = 0
    @Published var err = 0
    @Published var quality: QualityRating = .poor
    @Published var packet: TelemetryPacket?
    @Published var fuelPct = 0.0
    @Published var fuelPerLap: Double?
    @Published var lapsRemaining: Double?
    @Published var stops = 0
    @Published var lastMs: Int?
    @Published var bestMs: Int?
    @Published var liveDelta: Double?
    @Published var deltaTrace: [Float] = []
    @Published var throttleTrace: [Float] = []
    @Published var brakeTrace: [Float] = []
    @Published var laps: [LapRow] = []
    @Published var lapsInMemory = 0
    @Published var manualIp = ""
    @Published var showIp = false
    private let tracker = SessionTracker()
    private let client = Gt7UdpClient()
    private var qualityWindowStart = Date()
    private var qualityRxAtStart = 0
    private var qualityErrAtStart = 0

    init() {
        client.onRaw = { DispatchQueue.main.async { self.rx += 1; self.refreshQuality() } }
        client.onErr = { DispatchQueue.main.async { self.err += 1; self.refreshQuality() } }
        client.onPeer = { ip in DispatchQueue.main.async { self.peer = ip } }
        client.onStatus = { s in DispatchQueue.main.async { self.status = s } }
        client.onPacket = { p in
            let r = self.tracker.onPacket(p)
            DispatchQueue.main.async {
                self.dec += 1
                self.live = p.isRacing
                self.fuelPerLap = r.fuelPerLap
                self.lapsRemaining = r.rem
                self.stops = r.stops
                self.lastMs = r.last
                self.bestMs = r.best
                self.laps = r.laps
                self.lapsInMemory = r.count
                if p.isRacing {
                    self.packet = p
                    self.fuelPct = p.fuelPercent
                    self.liveDelta = r.delta
                    self.deltaTrace = r.trace
                    self.appendTrace(&self.throttleTrace, Float(p.throttleNorm))
                    self.appendTrace(&self.brakeTrace, Float(p.brakeNorm))
                } else {
                    self.liveDelta = nil
                    self.deltaTrace = []
                    self.appendTrace(&self.throttleTrace, 0)
                    self.appendTrace(&self.brakeTrace, 0)
                    if var frozen = self.packet {
                        frozen.speedMps = 0
                        frozen.rpm = 0
                        frozen.throttle = 0
                        frozen.brake = 0
                        frozen.gear = 15
                        self.packet = frozen
                    }
                }
            }
        }
        findPs5()
    }

    func findPs5() { client.startDiscover() }
    func connectIp() { client.startHost(manualIp) }

    private func appendTrace(_ buf: inout [Float], _ v: Float) {
        buf.append(v)
        if buf.count > 120 { buf.removeFirst() }
    }

    private func refreshQuality() {
        let elapsed = Date().timeIntervalSince(qualityWindowStart)
        if elapsed >= 1.0 {
            let drx = Double(rx - qualityRxAtStart)
            let derr = Double(err - qualityErrAtStart)
            let pps = drx / max(elapsed, 0.001)
            let ratio = drx > 0 ? derr / drx : (derr > 0 ? 1 : 0)
            quality = QualityRating.classify(packetsPerSecond: pps, errorRatio: ratio)
            qualityWindowStart = Date()
            qualityRxAtStart = rx
            qualityErrAtStart = err
        }
    }
}
