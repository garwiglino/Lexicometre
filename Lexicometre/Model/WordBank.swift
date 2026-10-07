import Foundation

/// Distribution of the difficulty of *all* the words of the lexicon, quiz words or not.
/// The vocabulary size is the sum, over this histogram, of the probability of knowing a word.
struct DifficultyHistogram: Sendable {
    let start: Double
    let width: Double
    let counts: [Int]

    /// (center, count) of the non-empty bins.
    var bins: [(center: Double, count: Double)] {
        counts.enumerated().compactMap { index, count in
            count > 0 ? (start + (Double(index) + 0.5) * width, Double(count)) : nil
        }
    }
}

enum WordBankError: LocalizedError {
    case missingResource
    case malformed(String)

    var errorDescription: String? {
        switch self {
        case .missingResource: "Le fichier du lexique est introuvable."
        case .malformed(let detail): "Le lexique est illisible (\(detail))."
        }
    }
}

/// The bundled lexicon (Lexique 3.83 × Wiktionnaire), immutable once loaded.
final class WordBank: Sendable {
    /// Number of words of the whole lexicon (the "100 %" of the estimate).
    let universeSize: Int
    let histogram: DifficultyHistogram
    /// Quiz words sorted by increasing difficulty.
    let words: [Word]
    private let positionByID: [Int: Int]
    /// Positions in `words` of each part of speech, by increasing difficulty.
    private let positionsByPOS: [PartOfSpeech: [Int]]

    static func loadBundled() throws -> WordBank {
        guard let url = Bundle.main.url(forResource: "mots", withExtension: "tsv") else {
            throw WordBankError.missingResource
        }
        return try WordBank(text: String(contentsOf: url, encoding: .utf8))
    }

    init(text: String) throws {
        var universe = 0
        var histogram: DifficultyHistogram?
        var parsed: [Word] = []
        parsed.reserveCapacity(24_000)

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.hasPrefix("#N=") {
                universe = Int(line.dropFirst(3)) ?? 0
                continue
            }
            if line.hasPrefix("#H=") {
                let values = line.dropFirst(3).split(separator: ",")
                guard values.count > 2, let start = Double(values[0]), let width = Double(values[1]) else {
                    throw WordBankError.malformed("histogramme")
                }
                histogram = DifficultyHistogram(start: start, width: width,
                                                counts: values.dropFirst(2).map { Int($0) ?? 0 })
                continue
            }
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 6,
                  let rank = Int(fields[0]),
                  let pos = PartOfSpeech(rawValue: String(fields[2])),
                  let difficulty = Double(fields[4]) else { continue }
            let example = fields.count > 6 && !fields[6].isEmpty ? String(fields[6]) : nil
            parsed.append(Word(id: rank,
                               text: String(fields[1]),
                               pos: pos,
                               gender: Gender(rawValue: String(fields[3])),
                               difficulty: difficulty,
                               definition: String(fields[5]),
                               example: example))
        }
        guard universe > 0, let histogram, parsed.count > 100 else {
            throw WordBankError.malformed("en-tête")
        }
        parsed.sort { ($0.difficulty, $0.id) < ($1.difficulty, $1.id) }

        var positionByID: [Int: Int] = [:]
        var positionsByPOS: [PartOfSpeech: [Int]] = [:]
        for (position, word) in parsed.enumerated() {
            positionByID[word.id] = position
            positionsByPOS[word.pos, default: []].append(position)
        }
        self.universeSize = universe
        self.histogram = histogram
        self.words = parsed
        self.positionByID = positionByID
        self.positionsByPOS = positionsByPOS
    }

    func word(id: Int) -> Word? {
        positionByID[id].map { words[$0] }
    }

    var difficultyRange: ClosedRange<Double> {
        (words.first?.difficulty ?? -7)...(words.last?.difficulty ?? 2)
    }

    /// Index of the first element of `positions` whose word is at least `difficulty`.
    func insertionIndex(of difficulty: Double, in positions: [Int]? = nil) -> Int {
        var low = 0
        var high = positions?.count ?? words.count
        while low < high {
            let mid = (low + high) / 2
            let position = positions?[mid] ?? mid
            if words[position].difficulty < difficulty { low = mid + 1 } else { high = mid }
        }
        return low
    }

    /// Up to `count` words closest in difficulty to `difficulty`, skipping `excluded` ids.
    func words(near difficulty: Double, count: Int, excluding excluded: Set<Int>,
               pos: PartOfSpeech? = nil) -> [Word] {
        let positions = pos.flatMap { positionsByPOS[$0] }
        let total = positions?.count ?? words.count
        guard total > 0 else { return [] }
        var left = insertionIndex(of: difficulty, in: positions) - 1
        var right = left + 1
        var result: [Word] = []
        while result.count < count && (left >= 0 || right < total) {
            let takeRight: Bool
            if left < 0 {
                takeRight = true
            } else if right >= total {
                takeRight = false
            } else {
                let l = words[positions?[left] ?? left].difficulty
                let r = words[positions?[right] ?? right].difficulty
                takeRight = abs(r - difficulty) <= abs(difficulty - l)
            }
            let index = takeRight ? right : left
            if takeRight { right += 1 } else { left -= 1 }
            let word = words[positions?[index] ?? index]
            if !excluded.contains(word.id) { result.append(word) }
        }
        return result
    }

    /// Positions (in `words`) of the words sharing a part of speech, by increasing difficulty.
    func positions(for pos: PartOfSpeech) -> [Int] {
        positionsByPOS[pos] ?? []
    }
}
