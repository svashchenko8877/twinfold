import SwiftUI

struct SaveState: Codable {
    var streak = 0
    var bestStreak = 0
    var lastDaily = ""              // last day the daily was solved
    var dailyDone: [String] = []
    var solved = 0
    var best: [String: Double] = [:]   // "6-0" -> seconds
    var freeDay = ""
    var freeUsed = 0
}

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var s = SaveState()
    private let key = "twinfold.save.v1"
    static let freePerDay = 3

    init() {
        if let d = UserDefaults.standard.data(forKey: key), let v = try? JSONDecoder().decode(SaveState.self, from: d) { s = v }
        rollover()
    }

    static func dayString(_ d: Date = .now) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: d)
    }

    private func persist() {
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: key) }
    }

    func rollover() {
        let today = Self.dayString()
        if s.freeDay != today { s.freeDay = today; s.freeUsed = 0 }
        if !s.lastDaily.isEmpty, s.lastDaily != today {
            let y = Self.dayString(Calendar.current.date(byAdding: .day, value: -1, to: .now)!)
            if s.lastDaily != y { s.streak = 0 }
        }
        persist()
    }

    var today: String { Self.dayString() }
    var dailyDone: Bool { s.dailyDone.contains(today) }
    var freeLeft: Int { max(0, Self.freePerDay - s.freeUsed) }

    func useFree() { s.freeUsed += 1; persist() }

    func finish(n: Int, diff: Difficulty, seconds: Double, daily: Bool) {
        s.solved += 1
        let k = "\(n)-\(diff.rawValue)"
        if s.best[k] == nil || seconds < s.best[k]! { s.best[k] = seconds }
        if daily, !dailyDone {
            s.dailyDone.append(today)
            let y = Self.dayString(Calendar.current.date(byAdding: .day, value: -1, to: .now)!)
            s.streak = (s.lastDaily == y) ? s.streak + 1 : 1
            s.lastDaily = today
            s.bestStreak = max(s.bestStreak, s.streak)
        }
        persist()
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func good() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func bad() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

func timeString(_ t: Double) -> String {
    let s = Int(t); return String(format: "%d:%02d", s / 60, s % 60)
}
