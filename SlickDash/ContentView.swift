import SwiftUI

private let page = Color(red: 0.043, green: 0.071, blue: 0.125)
private let card = Color(red: 0.067, green: 0.102, blue: 0.169)
private let cyan = Color(red: 0.133, green: 0.827, blue: 0.933)
private let green = Color(red: 0.133, green: 0.773, blue: 0.369)
private let red = Color(red: 0.937, green: 0.267, blue: 0.267)
private let amber = Color(red: 0.961, green: 0.620, blue: 0.043)
private let text = Color(red: 0.973, green: 0.980, blue: 0.988)
private let muted = Color(red: 0.545, green: 0.608, blue: 0.706)
private let line = Color(red: 0.102, green: 0.153, blue: 0.251)
private let tireBg = Color(red: 0.051, green: 0.082, blue: 0.149)

struct ContentView: View {
    @EnvironmentObject var m: DashModel
    var body: some View {
        ZStack(alignment: .trailing) {
            page.ignoresSafeArea()
            VStack(spacing: 0) {
                HeaderBar()
                switch m.mode {
                case .simple: SimpleView()
                case .driving: DrivingView()
                case .pit: PitWallView()
                }
            }
            if m.settings { SettingsSheet() }
        }
        .foregroundStyle(text)
    }
}

struct HeaderBar: View {
    @EnvironmentObject var m: DashModel
    var body: some View {
        HStack(spacing: 8) {
            Image("SMark").resizable().frame(width: 22, height: 22)
            Text("SlickDash").font(.system(size: 14, weight: .semibold))
            Text(m.live ? "LIVE" : "IDLE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(green)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Color(red: 0.08, green: 0.21, blue: 0.16))
                .clipShape(Capsule())
            Spacer()
            ForEach(Mode.allCases, id: \.self) { mode in
                Text(mode.rawValue)
                    .font(.system(size: 11))
                    .foregroundStyle(m.mode == mode ? cyan : muted)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .overlay(Capsule().stroke(m.mode == mode ? cyan : line, lineWidth: 1))
                    .onTapGesture { m.mode = mode }
            }
            Image(systemName: "gearshape.fill")
                .foregroundStyle(muted)
                .frame(width: 28, height: 28)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(line))
                .onTapGesture { m.settings = true }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        Rectangle().fill(cyan).frame(height: 1)
    }
}

struct CardBox<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content }
            .padding(10)
            .background(card)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(line))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
struct Lbl: View {
    let t: String
    var body: some View { Text(t.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(muted) }
}
struct Bar: View {
    let frac: CGFloat; let color: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(red: 0.106, green: 0.141, blue: 0.220))
                Capsule().fill(color).frame(width: g.size.width * min(1, max(0, frac)))
            }
        }.frame(height: 8)
    }
}

struct SimpleView: View {
    @EnvironmentObject var m: DashModel
    var body: some View {
        GeometryReader { geo in
            let land = geo.size.width > geo.size.height
            Group {
                if land {
                    HStack(spacing: 8) {
                        CardBox {
                            Lbl(t: "Fuel — this session")
                            Text(String(format: "%.0f%%", m.fuelPct)).font(.system(size: 42, weight: .semibold))
                            Bar(frac: CGFloat(m.fuelPct/100), color: amber)
                            Text("\(m.fuelPerLap.map { String(format: "%.1f%%/lap", $0) } ?? "—%/lap")")
                            Text("\(m.lapsRemaining.map { String(format: "%.1f laps remaining", $0) } ?? "— laps remaining")")
                            Text("\(m.stops) stop").font(.system(size: 12)).foregroundStyle(muted)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        CardBox { Lbl(t: "Tire temps"); TireGrid(p: m.packet).frame(maxHeight: .infinity) }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            CardBox {
                                Lbl(t: "Fuel — this session")
                                Text(String(format: "%.0f%%", m.fuelPct)).font(.system(size: 42, weight: .semibold))
                                Bar(frac: CGFloat(m.fuelPct/100), color: amber)
                                Text("\(m.fuelPerLap.map { String(format: "%.1f%%/lap", $0) } ?? "—%/lap")")
                                Text("\(m.lapsRemaining.map { String(format: "%.1f laps remaining", $0) } ?? "— laps remaining")")
                                Text("\(m.stops) stop").font(.system(size: 12)).foregroundStyle(muted)
                            }
                            CardBox { Lbl(t: "Tire temps"); TireGrid(p: m.packet).frame(height: 260) }
                        }.padding(8)
                    }
                }
            }.padding(land ? 8 : 0)
        }
    }
}

struct TireGrid: View {
    let p: TelemetryPacket?
    var body: some View {
        let cells: [(String, Float)] = [("FL", p?.tireFL ?? 0), ("FR", p?.tireFR ?? 0), ("RL", p?.tireRL ?? 0), ("RR", p?.tireRR ?? 0)]
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(cells, id: \.0) { k, v in
                VStack {
                    Text(k).font(.system(size: 11)).foregroundStyle(muted)
                    Text(String(format: "%.0f°C", v)).font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(v >= 100 ? red : green)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(tireBg)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

struct DrivingView: View {
    @EnvironmentObject var m: DashModel
    var p: TelemetryPacket? { m.packet }
    var body: some View {
        GeometryReader { geo in
            let land = geo.size.width > geo.size.height
            Group {
                if land {
                    // Max 2 columns: Gear+Throttle | Delta / Fuel+Tires
                    HStack(alignment: .top, spacing: 8) {
                        ScrollView {
                            VStack(spacing: 8) {
                                gearSpeedCard
                                throttleBrakeCard
                            }
                        }.frame(maxWidth: .infinity)
                        ScrollView {
                            VStack(spacing: 8) {
                                deltaCard
                                fuelCard
                                CardBox { Lbl(t: "Tire temps"); TireGrid(p: p).frame(height: 180) }
                            }
                        }.frame(maxWidth: .infinity)
                    }.padding(8)
                } else {
                    // Portrait: always 1 column
                    ScrollView {
                        VStack(spacing: 8) {
                            gearSpeedCard
                            throttleBrakeCard
                            deltaCard
                            fuelCard
                            CardBox { Lbl(t: "Tire temps"); TireGrid(p: p).frame(height: 220) }
                        }.padding(8)
                    }
                }
            }
        }
    }

    private var gearSpeedCard: some View {
        CardBox {
            Lbl(t: "Gear / speed"); RpmBar(frac: p?.rpmFrac ?? 0)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) { Lbl(t: "Gear"); Text(p?.gearDisplay ?? "N").font(.system(size: 34, weight: .semibold)) }
                VStack(alignment: .leading) { Lbl(t: "Speed"); Text(String(format: "%d km/h", Int(p?.speedKph ?? 0))).font(.system(size: 22, weight: .semibold)) }
            }
        }
    }

    private var throttleBrakeCard: some View {
        CardBox {
            HStack { Lbl(t: "Throttle"); Spacer(); Text("\(p?.throttlePct ?? 0)%").foregroundStyle(green) }
            Bar(frac: CGFloat(p?.throttlePct ?? 0)/100, color: Color(red: 0.086, green: 0.396, blue: 0.204))
            HStack { Lbl(t: "Brake"); Spacer(); Text("\(p?.brakePct ?? 0)%").foregroundStyle(muted) }
            Bar(frac: CGFloat(p?.brakePct ?? 0)/100, color: red)
        }
    }

    private var deltaCard: some View {
        CardBox {
            Lbl(t: "Delta vs session best")
            Text(formatDelta(m.liveDelta))
                .font(.system(size: 34, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle((m.liveDelta ?? 0) < 0 ? green : ((m.liveDelta == nil) ? text : red))
            HStack { Text("LAST \(formatLap(m.lastMs))"); Spacer(); Text("BEST \(formatLap(m.bestMs))") }
                .font(.system(size: 12)).foregroundStyle(muted)
        }
    }

    private var fuelCard: some View {
        CardBox {
            Lbl(t: "Fuel — this session")
            Text(String(format: "%.0f%%", m.fuelPct)).font(.system(size: 22, weight: .semibold))
            Bar(frac: CGFloat(m.fuelPct/100), color: amber)
            Text(m.fuelPerLap.map { String(format: "%.1f%%/lap", $0) } ?? "—")
            Text("\(m.lapsRemaining.map { String(format: "%.1f", $0) } ?? "—") laps · \(m.stops) stop").foregroundStyle(muted).font(.system(size: 12))
        }
    }
}

struct RpmBar: View {
    let frac: Float
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<10, id: \.self) { i in
                let on = i < Int(frac * 10)
                let c: Color = !on ? Color(red: 0.106, green: 0.141, blue: 0.220) : (i < 4 ? green : i < 6 ? Color.yellow : i < 8 ? amber : red)
                RoundedRectangle(cornerRadius: 2).fill(c).frame(height: 10)
            }
        }
    }
}

struct PitWallView: View {
    @EnvironmentObject var m: DashModel
    var p: TelemetryPacket? { m.packet }
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                CardBox { Lbl(t: "Delta vs session best"); DeltaTrace(samples: m.deltaTrace).frame(height: 80) }
                CardBox {
                    Lbl(t: "Gear / speed")
                    HStack {
                        VStack { Lbl(t: "Gear"); Text(p?.gearDisplay ?? "N").font(.system(size: 36, weight: .semibold)) }
                        Spacer()
                        VStack { Lbl(t: "Speed"); Text(String(format: "%d km/h", Int(p?.speedKph ?? 0))).font(.system(size: 36, weight: .semibold)) }
                        Spacer()
                    }
                    RpmBar(frac: p?.rpmFrac ?? 0)
                }
                CardBox {
                    Lbl(t: "Delta vs session best")
                    Text(formatDelta(m.liveDelta)).font(.system(size: 36, weight: .semibold))
                        .foregroundStyle((m.liveDelta ?? 0) < 0 ? green : ((m.liveDelta == nil) ? text : red))
                }
                CardBox {
                    Lbl(t: "This session")
                    HStack {
                        VStack { Lbl(t: "Last"); Text(formatLap(m.lastMs)).foregroundStyle(cyan) }
                        Spacer()
                        VStack { Lbl(t: "Best"); Text(formatLap(m.bestMs)).foregroundStyle(green) }
                        Spacer()
                        VStack { Lbl(t: "Laps in memory"); Text("\(m.lapsInMemory)") }
                    }
                }
                CardBox { Lbl(t: "Tire temps"); TireGrid(p: p).frame(height: 160) }
                CardBox {
                    Lbl(t: "Fuel — this session")
                    HStack {
                        Text(String(format: "%.0f%%", m.fuelPct)).font(.system(size: 28, weight: .semibold)).foregroundStyle(amber)
                        VStack {
                            Bar(frac: CGFloat(m.fuelPct/100), color: amber)
                            Text("\(m.fuelPerLap.map { String(format: "%.1f%%/lap", $0) } ?? "—") · \(m.lapsRemaining.map { String(format: "%.1f laps", $0) } ?? "—") · \(m.stops) stop")
                                .font(.system(size: 12)).foregroundStyle(muted)
                        }
                    }
                }
                CardBox {
                    HStack { Lbl(t: "This session — last 100 laps"); Spacer(); Text("BEST \(formatLap(m.bestMs))").foregroundStyle(green) }
                    ForEach(m.laps) { row in
                        let d = m.bestMs.map { Double(row.timeMs - $0) / 1000 }
                        HStack {
                            Text("L\(row.lap)").frame(width: 36, alignment: .leading)
                            Text(formatLap(row.timeMs))
                            Spacer()
                            Text(row.isBest ? "BEST" : formatDelta(d))
                                .foregroundStyle(row.isBest ? green : ((d ?? 0) > 0.4 ? red : amber))
                        }.font(.system(size: 13))
                    }
                }
            }.padding(8)
        }
    }
}

struct DeltaTrace: View {
    let samples: [Float]
    var body: some View {
        Canvas { ctx, size in
            let mid = size.height/2
            var path = Path(); path.move(to: CGPoint(x: 0, y: mid)); path.addLine(to: CGPoint(x: size.width, y: mid))
            ctx.stroke(path, with: .color(line), lineWidth: 1)
            guard samples.count > 1 else { return }
            let maxAbs = max(samples.map { abs($0) }.max() ?? 0.2, 0.2)
            var p = Path()
            for (i, v) in samples.enumerated() {
                let x = size.width * CGFloat(i) / CGFloat(samples.count - 1)
                let y = mid - CGFloat(v / maxAbs) * size.height * 0.4
                if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(p, with: .color(cyan), lineWidth: 2)
        }.background(tireBg).clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct SettingsSheet: View {
    @EnvironmentObject var m: DashModel
    var body: some View {
        ZStack(alignment: .trailing) {
            Color.black.opacity(0.72).ignoresSafeArea().onTapGesture { m.settings = false }
            VStack(alignment: .leading, spacing: 8) {
                HStack { Lbl(t: "Settings"); Spacer(); Text("Done").foregroundStyle(muted).onTapGesture { m.settings = false } }
                Lbl(t: "PlayStation on this Wi-Fi")
                Button(action: m.findPs5) {
                    Text("Find PS5").font(.system(size: 15, weight: .bold)).foregroundStyle(Color(red: 0.03, green: 0.13, blue: 0.16))
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                }.background(cyan).clipShape(RoundedRectangle(cornerRadius: 8))
                Text("Sends a heartbeat on the LAN and connects when GT7 answers.").font(.system(size: 12)).foregroundStyle(muted)
                CardBox {
                    HStack {
                        Text(m.peer ?? "—")
                        Spacer()
                        Text(m.peer == nil ? "Idle" : "Connected").font(.system(size: 11, weight: .bold)).foregroundStyle(green)
                    }
                    Bar(frac: m.peer == nil ? 0 : 0.86, color: cyan)
                    Text("rx \(m.rx)   dec \(m.dec)   err \(m.err)").font(.system(size: 12)).foregroundStyle(muted)
                }
                Button(action: { m.showIp.toggle() }) {
                    Text("Enter IP manually").foregroundStyle(cyan).frame(maxWidth: .infinity).padding(8)
                }.overlay(RoundedRectangle(cornerRadius: 8).stroke(cyan))
                if m.showIp {
                    TextField("PS5 IPv4", text: $m.manualIp).textFieldStyle(.roundedBorder)
                    Button("Connect") { m.connectIp(); m.showIp = false }.foregroundStyle(cyan)
                }
                #if DEBUG
                Button("Send Sentry test") { SlickDashApp.captureTestError() }
                    .font(.system(size: 12)).foregroundStyle(muted)
                #endif
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: 320)
            .frame(maxHeight: .infinity)
            .background(page)
            .overlay(Rectangle().frame(width: 1).foregroundStyle(cyan), alignment: .leading)
        }
    }
}
