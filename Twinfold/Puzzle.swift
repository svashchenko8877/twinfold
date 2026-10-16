import Foundation

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum Difficulty: Int, CaseIterable, Codable, Identifiable {
    case easy, medium, hard
    var id: Int { rawValue }
    var title: String { ["Easy", "Medium", "Hard"][rawValue] }
    /// Share of cells that start empty.
    var blanks: Double { [0.42, 0.55, 0.66][rawValue] }
}

/// Takuzu rules: no three equal in a row/column, equal 0/1 count per line, no two identical complete lines.
struct Board {
    let n: Int
    var cells: [Int8]            // -1 empty, 0, 1
    init(n: Int, cells: [Int8]? = nil) { self.n = n; self.cells = cells ?? Array(repeating: -1, count: n * n) }
    subscript(r: Int, c: Int) -> Int8 {
        get { cells[r * n + c] }
        set { cells[r * n + c] = newValue }
    }
    var isFull: Bool { !cells.contains(-1) }

    private func line(_ i: Int, row: Bool) -> [Int8] {
        (0..<n).map { row ? self[i, $0] : self[$0, i] }
    }

    /// Cells that currently break a rule (triples, over-full lines, duplicate complete lines).
    func conflicts() -> Set<Int> {
        var bad = Set<Int>()
        for i in 0..<n {
            for isRow in [true, false] {
                let l = line(i, row: isRow)
                func idx(_ k: Int) -> Int { isRow ? i * n + k : k * n + i }
                for k in 0..<(n - 2) where l[k] >= 0 && l[k] == l[k + 1] && l[k] == l[k + 2] {
                    bad.insert(idx(k)); bad.insert(idx(k + 1)); bad.insert(idx(k + 2))
                }
                for v: Int8 in [0, 1] where l.filter({ $0 == v }).count > n / 2 {
                    for k in 0..<n where l[k] == v { bad.insert(idx(k)) }
                }
                if !l.contains(-1) {
                    for j in 0..<n where j != i && !line(j, row: isRow).contains(-1) && line(j, row: isRow) == l {
                        for k in 0..<n { bad.insert(idx(k)) }
                    }
                }
            }
        }
        return bad
    }

    func isSolved() -> Bool { isFull && conflicts().isEmpty }

    private func wouldTriple(_ r: Int, _ c: Int, _ v: Int8) -> Bool {
        func at(_ rr: Int, _ cc: Int) -> Int8 { (0..<n).contains(rr) && (0..<n).contains(cc) ? self[rr, cc] : -2 }
        for (dr, dc) in [(0, 1), (1, 0)] {
            for off in -2...0 {
                let a = at(r + dr * off, c + dc * off), b = at(r + dr * (off + 1), c + dc * (off + 1)), d = at(r + dr * (off + 2), c + dc * (off + 2))
                let vals = [a, b, d]
                // the cell itself is one of the three; the other two must both equal v to form a triple
                var others: [Int8] = []
                for (k, x) in vals.enumerated() where k != -off { others.append(x) }
                if others.allSatisfy({ $0 == v }) { return true }
            }
        }
        return false
    }

    /// Forced-move propagation. Returns false on contradiction.
    mutating func propagate() -> Bool {
        var changed = true
        while changed {
            changed = false
            if !conflicts().isEmpty { return false }
            for r in 0..<n {
                for c in 0..<n where self[r, c] == -1 {
                    let no0 = wouldTriple(r, c, 0), no1 = wouldTriple(r, c, 1)
                    if no0 && no1 { return false }
                    if no0 { self[r, c] = 1; changed = true } else if no1 { self[r, c] = 0; changed = true }
                }
            }
            for i in 0..<n {
                for isRow in [true, false] {
                    let l = line(i, row: isRow)
                    let ones = l.filter { $0 == 1 }.count, zeros = l.filter { $0 == 0 }.count
                    if ones == n / 2 && zeros < n / 2 {
                        for k in 0..<n where l[k] == -1 { if isRow { self[i, k] = 0 } else { self[k, i] = 0 }; changed = true }
                    } else if zeros == n / 2 && ones < n / 2 {
                        for k in 0..<n where l[k] == -1 { if isRow { self[i, k] = 1 } else { self[k, i] = 1 }; changed = true }
                    }
                }
            }
        }
        return conflicts().isEmpty
    }

    func countSolutions(limit: Int) -> Int {
        var b = self
        guard b.propagate() else { return 0 }
        guard let i = b.cells.firstIndex(of: -1) else { return b.isSolved() ? 1 : 0 }
        var total = 0
        for v: Int8 in [0, 1] {
            var t = b; t.cells[i] = v
            total += t.countSolutions(limit: limit - total)
            if total >= limit { break }
        }
        return total
    }

    func solveOne(rng: inout SplitMix64) -> Board? {
        var b = self
        guard b.propagate() else { return nil }
        guard let i = b.cells.firstIndex(of: -1) else { return b.isSolved() ? b : nil }
        let order: [Int8] = Bool.random(using: &rng) ? [0, 1] : [1, 0]
        for v in order {
            var t = b; t.cells[i] = v
            if let s = t.solveOne(rng: &rng) { return s }
        }
        return nil
    }
}

struct Puzzle {
    let n: Int
    let solution: [Int8]
    let given: [Int8]       // -1 where the player must fill

    static func generate(n: Int, difficulty: Difficulty, seed: UInt64) -> Puzzle {
        var rng = SplitMix64(seed: seed)
        let full = Board(n: n).solveOne(rng: &rng)!
        var b = full
        var order = Array(0..<(n * n)); order.shuffle(using: &rng)
        let target = Int(Double(n * n) * difficulty.blanks)
        var removed = 0
        for i in order where removed < target {
            let keep = b.cells[i]
            b.cells[i] = -1
            if b.countSolutions(limit: 2) == 1 { removed += 1 } else { b.cells[i] = keep }
        }
        return Puzzle(n: n, solution: full.cells, given: b.cells)
    }

    static func dailySeed(_ day: String) -> UInt64 {
        var h: UInt64 = 1469598103934665603
        for u in day.utf8 { h = (h ^ UInt64(u)) &* 1099511628211 }
        return h
    }
}
