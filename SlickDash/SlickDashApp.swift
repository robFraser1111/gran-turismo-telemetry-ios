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
    @Published var packet: TelemetryPacket?
    @Published var fuelPct = 0.0
    @Published var fuelPerLap: Double?
    @Published var lapsRemaining: Double?
    @Published var stops = 0
    @Published var lastMs: Int?
    @Published var bestMs: Int?
    @Published var liveDelta: Double?
    @Published var deltaTrace: [Float] = []
    @Published var laps: [LapRow] = []
    @Published var lapsInMemory = 0
    @Published var manualIp = ""
    @Published var showIp = false
    private let tracker = SessionTracker()
    private let client = Gt7UdpClient()
    init() {
        client.onRaw = { DispatchQueue.main.async { self.rx += 1 } }
        client.onErr = { DispatchQueue.main.async { self.err += 1 } }
        client.onPeer = { ip in DispatchQueue.main.async { self.peer = ip } }
        client.onStatus = { s in DispatchQueue.main.async { self.status = s } }
        client.onPacket = { p in
            let r = self.tracker.onPacket(p)
            DispatchQueue.main.async {
                self.dec += 1
                // LIVE = actively racing (not pause/menu/loading). Still receive packets either way.
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
                } else {
                    // Freeze HUD at menu/pause like Windows (keep lap table).
                    self.liveDelta = nil
                    self.deltaTrace = []
                    if var frozen = self.packet {
                        frozen.speedMps = 0
                        frozen.rpm = 0
                        frozen.throttle = 0
                        frozen.brake = 0
                        frozen.gear = 15 // N
                        self.packet = frozen
                    }
                }
            }
        }
        findPs5()
    }
    func findPs5() { client.startDiscover() }
    func connectIp() { client.startHost(manualIp) }
}
