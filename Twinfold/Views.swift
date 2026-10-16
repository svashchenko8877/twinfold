import SwiftUI

struct GameSpec: Identifiable, Hashable {
    let n: Int
    let diff: Difficulty
    let daily: Bool
    let seed: UInt64
    var id: String { "\(n)-\(diff.rawValue)-\(seed)" }
}

// MARK: Home

struct HomeView: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var pm: PurchaseManager
    @State private var game: GameSpec?
    @State private var showPaywall = false
    @State private var showHow = false
    @State private var size = 6
    @State private var diff = Difficulty.easy

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    dailyCard
                    freePlayCard
                    statsCard
                    Button { showHow = true } label: {
                        Label("How to play", systemImage: "questionmark.circle").font(rounded(15, .bold)).foregroundStyle(Theme.text2)
                    }.padding(.top, 4)
                    if !pm.isPro {
                        Button("Restore purchase") { Task { await pm.restore() } }
                            .font(rounded(13, .semibold)).foregroundStyle(Theme.text2)
                    }
                    Link("Privacy policy", destination: URL(string: "https://svashchenko8877.github.io/twinfold/privacy.html")!)
                        .font(rounded(12, .medium)).foregroundStyle(Theme.text2)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
        }
        .fullScreenCover(item: $game) { spec in GameView(spec: spec) }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showHow) { HowToView() }
        .onAppear { store.rollover() }
        #if DEBUG
        .task {
            let a = ProcessInfo.processInfo.arguments
            if a.contains("-tfgame") { game = GameSpec(n: 6, diff: .medium, daily: false, seed: 7) }
            if a.contains("-tfpaywall") { showPaywall = true }
            if a.contains("-tfhow") { showHow = true }
        }
        #endif
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Token(value: 1, size: 34); Token(value: 0, size: 34)
                    Text("Twinfold").font(rounded(34, .black)).foregroundStyle(.white)
                }
                Text("Daily binary puzzles").font(rounded(14, .medium)).foregroundStyle(Theme.text2)
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "flame.fill").foregroundStyle(Theme.sun)
                Text("\(store.s.streak)").font(rounded(20, .heavy)).foregroundStyle(.white)
            }
            .padding(.horizontal, 14).padding(.vertical, 8).glassEffect(.regular, in: Capsule())
        }.padding(.top, 8)
    }

    private var dailyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's puzzle").font(rounded(20, .heavy)).foregroundStyle(.white)
                Spacer()
                if store.dailyDone { Label("Solved", systemImage: "checkmark.circle.fill").font(rounded(14, .bold)).foregroundStyle(Theme.good) }
            }
            Text(store.dailyDone ? "Come back tomorrow to keep your \(store.s.streak)-day streak." : "Same puzzle for everyone. Solve it to grow your streak.")
                .font(rounded(14, .medium)).foregroundStyle(Theme.text2)
            Button {
                game = GameSpec(n: 6, diff: .medium, daily: true, seed: Puzzle.dailySeed(store.today))
            } label: { Text(store.dailyDone ? "Play again" : "Play daily") }
                .buttonStyle(ChunkyButton(color: Theme.sun.opacity(0.95)))
        }
        .padding(18).glass(26)
    }

    private var freePlayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Free play").font(rounded(20, .heavy)).foregroundStyle(.white)
                Spacer()
                if !pm.isPro {
                    Text("\(store.freeLeft) free left today").font(rounded(13, .bold)).foregroundStyle(Theme.text2)
                }
            }
            Picker("Size", selection: $size) {
                ForEach([6, 8, 10], id: \.self) { n in Text(pm.isPro || n == 6 ? "\(n)×\(n)" : "\(n)×\(n) 🔒").tag(n) }
            }.pickerStyle(.segmented)
            Picker("Difficulty", selection: $diff) {
                ForEach(Difficulty.allCases) { d in Text(pm.isPro || d != .hard ? d.title : "\(d.title) 🔒").tag(d) }
            }.pickerStyle(.segmented)
            Button { startFree() } label: { Text("Start puzzle") }.buttonStyle(ChunkyButton(color: Theme.moon))
            if !pm.isPro {
                Button { showPaywall = true } label: {
                    HStack { Image(systemName: "sparkles"); Text("Unlock Pro — unlimited, all sizes") }
                        .font(rounded(14, .bold)).foregroundStyle(Theme.sun)
                }
            }
        }
        .padding(18).glass(26)
    }

    private func startFree() {
        if !pm.isPro && (size != 6 || diff == .hard || store.freeLeft == 0) { showPaywall = true; return }
        if !pm.isPro { store.useFree() }
        game = GameSpec(n: size, diff: diff, daily: false, seed: UInt64.random(in: 1...UInt64.max))
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            stat("\(store.s.solved)", "Solved")
            stat("\(store.s.bestStreak)", "Best streak")
            stat(store.s.best["6-0"].map(timeString) ?? "–", "Best 6×6")
        }.padding(.vertical, 16).glass(22)
    }
    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(rounded(24, .heavy)).foregroundStyle(.white)
            Text(l).font(rounded(12, .semibold)).foregroundStyle(Theme.text2)
        }.frame(maxWidth: .infinity)
    }
}

// MARK: Game

struct Move { let idx: Int; let old: Int8 }

struct GameView: View {
    let spec: GameSpec
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var pm: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var puzzle: Puzzle?
    @State private var cells: [Int8] = []
    @State private var moves: [Move] = []
    @State private var seconds: Double = 0
    @State private var won = false
    @State private var hintsUsed = 0
    @State private var hintCell: Int?
    @State private var showPaywall = false
    @State private var ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var startedAt = Date()

    private var board: Board { Board(n: spec.n, cells: cells) }
    private var conflicts: Set<Int> { board.conflicts() }
    private var hintLimit: Int { pm.isPro ? 99 : 1 }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 16) {
                topBar
                if let puzzle {
                    gridView(puzzle)
                    controls
                    Text("Fill the grid with suns and moons. No three of a kind in a row, equal counts in every row and column, and no two identical rows or columns.")
                        .font(rounded(12, .medium)).foregroundStyle(Theme.text2).multilineTextAlignment(.center).padding(.horizontal, 24)
                } else {
                    Spacer(); ProgressView().tint(.white); Spacer()
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 16)
            if won { winOverlay }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .task { await load() }
        .onReceive(ticker) { _ in if puzzle != nil && !won { seconds = Date().timeIntervalSince(startedAt) } }
    }

    private func load() async {
        let s = spec
        let p = await Task.detached(priority: .userInitiated) {
            Puzzle.generate(n: s.n, difficulty: s.diff, seed: s.seed)
        }.value
        puzzle = p; cells = p.given; startedAt = Date()
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 40, height: 40).glassEffect(.regular.interactive(), in: Circle())
            }
            Spacer()
            VStack(spacing: 0) {
                Text(spec.daily ? "Daily" : "\(spec.n)×\(spec.n) · \(spec.diff.title)").font(rounded(16, .heavy)).foregroundStyle(.white)
                Text(timeString(seconds)).font(rounded(14, .semibold).monospacedDigit()).foregroundStyle(Theme.text2)
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }.padding(.top, 6)
    }

    private func gridView(_ p: Puzzle) -> some View {
        let bad = conflicts
        return GeometryReader { geo in
            let side = min(geo.size.width, geo.size.width)
            let cell = side / CGFloat(spec.n)
            VStack(spacing: 0) {
                ForEach(0..<spec.n, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<spec.n, id: \.self) { c in
                            let i = r * spec.n + c
                            let locked = p.given[i] != -1
                            ZStack {
                                RoundedRectangle(cornerRadius: cell * 0.18, style: .continuous)
                                    .fill(locked ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
                                    .padding(2)
                                if bad.contains(i) {
                                    RoundedRectangle(cornerRadius: cell * 0.18, style: .continuous)
                                        .stroke(Theme.bad, lineWidth: 2.5).padding(2)
                                }
                                if hintCell == i {
                                    RoundedRectangle(cornerRadius: cell * 0.18, style: .continuous)
                                        .stroke(Theme.good, lineWidth: 3).padding(2)
                                }
                                Token(value: cells[i], size: cell)
                            }
                            .frame(width: cell, height: cell)
                            .contentShape(Rectangle())
                            .onTapGesture { tap(i, locked: locked) }
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(6).glass(24)
    }

    private func tap(_ i: Int, locked: Bool) {
        guard !locked, !won else { return }
        moves.append(Move(idx: i, old: cells[i]))
        cells[i] = cells[i] == -1 ? 1 : (cells[i] == 1 ? 0 : -1)
        hintCell = nil
        Haptics.tap()
        if board.isSolved() { finish() }
    }

    private func finish() {
        won = true
        seconds = Date().timeIntervalSince(startedAt)
        store.finish(n: spec.n, diff: spec.diff, seconds: seconds, daily: spec.daily)
        Haptics.good()
    }

    private var controls: some View {
        HStack(spacing: 12) {
            ctl("arrow.uturn.backward", "Undo", enabled: !moves.isEmpty) {
                if let m = moves.popLast() { cells[m.idx] = m.old; hintCell = nil }
            }
            ctl("lightbulb.fill", "Hint", enabled: true) { hint() }
            ctl("trash", "Reset", enabled: cells != puzzle?.given) {
                if let p = puzzle { cells = p.given; moves = []; hintCell = nil }
            }
        }
    }

    private func ctl(_ icon: String, _ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 20, weight: .bold))
                Text(title).font(rounded(12, .bold))
            }.foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }.disabled(!enabled).opacity(enabled ? 1 : 0.4)
    }

    private func hint() {
        guard let p = puzzle, !won else { return }
        if hintsUsed >= hintLimit { showPaywall = true; return }
        // Fix a wrong cell first, otherwise reveal an empty one.
        let wrong = (0..<cells.count).filter { cells[$0] != -1 && p.given[$0] == -1 && cells[$0] != p.solution[$0] }
        let empty = (0..<cells.count).filter { cells[$0] == -1 }
        guard let i = wrong.randomElement() ?? empty.randomElement() else { return }
        moves.append(Move(idx: i, old: cells[i]))
        cells[i] = p.solution[i]
        hintCell = i; hintsUsed += 1
        Haptics.tap()
        if board.isSolved() { finish() }
    }

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                HStack(spacing: 10) { Token(value: 1, size: 60); Token(value: 0, size: 60) }
                Text("Solved!").font(rounded(34, .black)).foregroundStyle(.white)
                Text("\(timeString(seconds))" + (hintsUsed > 0 ? " · \(hintsUsed) hint\(hintsUsed == 1 ? "" : "s")" : ""))
                    .font(rounded(18, .semibold)).foregroundStyle(Theme.text2)
                if spec.daily {
                    Label("\(store.s.streak)-day streak", systemImage: "flame.fill").font(rounded(18, .heavy)).foregroundStyle(Theme.sun)
                }
                Button { dismiss() } label: { Text("Done") }.buttonStyle(ChunkyButton(color: Theme.moon)).padding(.top, 6)
            }
            .padding(26).glass(30).padding(.horizontal, 30)
        }
    }
}

// MARK: How to / Paywall

struct HowToView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How to play").font(rounded(30, .black)).foregroundStyle(.white)
                    rule("hand.tap.fill", "Tap a cell to cycle: sun, moon, empty.")
                    rule("equal.circle.fill", "Every row and column has the same number of suns and moons.")
                    rule("3.circle.fill", "No more than two suns or two moons side by side — in any row or column.")
                    rule("square.on.square", "No two rows are identical, and no two columns are identical.")
                    rule("lightbulb.fill", "Stuck? A hint fixes a mistake or reveals a cell.")
                    Button("Got it") { dismiss() }.buttonStyle(ChunkyButton(color: Theme.moon)).padding(.top, 8)
                }.padding(24)
            }
        }.preferredColorScheme(.dark)
    }
    private func rule(_ icon: String, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.sun).frame(width: 30)
            Text(t).font(rounded(16, .medium)).foregroundStyle(.white)
        }
    }
}

struct PaywallView: View {
    @EnvironmentObject var pm: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    private let perks: [(String, String, String)] = [
        ("infinity", "Unlimited puzzles", "Play as many as you like, every day."),
        ("square.grid.3x3.fill", "8×8 and 10×10 grids", "Bigger boards for a real challenge."),
        ("flame.fill", "Hard difficulty", "Fewer clues, tougher logic."),
        ("lightbulb.fill", "Unlimited hints", "Never stay stuck."),
    ]

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    HStack { Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                                .frame(width: 38, height: 38).glassEffect(.regular.interactive(), in: Circle())
                        }
                    }
                    HStack(spacing: 12) { Token(value: 1, size: 80); Token(value: 0, size: 80) }
                    Text("Twinfold Pro").font(rounded(32, .black)).foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(perks, id: \.0) { p in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: p.0).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .glassEffect(.regular.tint(Theme.moon.opacity(0.6)), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.1).font(rounded(17, .heavy)).foregroundStyle(.white)
                                    Text(p.2).font(rounded(13, .medium)).foregroundStyle(Theme.text2)
                                }
                            }
                        }
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).glass(26)
                    VStack(spacing: 4) {
                        Text(pm.price).font(rounded(44, .black)).foregroundStyle(.white)
                        Text("one-time purchase · no ads · no subscription").font(rounded(13, .semibold)).foregroundStyle(Theme.text2)
                    }
                    Button { Task { await pm.buy() } } label: {
                        HStack(spacing: 8) {
                            if pm.busy { ProgressView().tint(.white) }
                            Text(pm.busy ? "Working…" : "Unlock Pro")
                        }
                    }.buttonStyle(ChunkyButton(color: Theme.sun, enabled: !pm.busy)).disabled(pm.busy)
                    Button("Restore purchase") { Task { await pm.restore() } }
                        .font(rounded(15, .bold)).foregroundStyle(Theme.moon).disabled(pm.busy)
                    if let m = pm.message {
                        Text(m).font(rounded(13, .semibold)).foregroundStyle(Theme.sun).multilineTextAlignment(.center)
                    }
                    Text("Payment is charged to your Apple ID. One-time purchase; it does not renew.")
                        .font(rounded(11, .medium)).foregroundStyle(Theme.text2).multilineTextAlignment(.center)
                }.padding(.horizontal, 22).padding(.vertical, 10)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: pm.isPro) { _, v in if v { dismiss() } }
    }
}
