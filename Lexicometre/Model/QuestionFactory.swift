import Foundation

struct Question: Identifiable, Sendable {
    let id = UUID()
    let word: Word
    /// Three definitions, one of them right.
    let options: [String]
    let correctIndex: Int
}

enum QuestionFactory {
    static func make<G: RandomNumberGenerator>(for word: Word, in bank: WordBank,
                                              using generator: inout G) -> Question {
        var options = distractors(for: word, in: bank, using: &generator).map(\.definition)
        options.append(word.definition)
        options.shuffle(using: &generator)
        let correct = options.firstIndex(of: word.definition) ?? 0
        return Question(word: word, options: options, correctIndex: correct)
    }

    /// Two definitions of other words of the same part of speech and a similar difficulty,
    /// of comparable length, that do not echo the target word.
    static func distractors<G: RandomNumberGenerator>(for word: Word, in bank: WordBank,
                                                     using generator: inout G) -> [Word] {
        var chosen: [Word] = []

        func acceptable(_ candidate: Word) -> Bool {
            candidate.id != word.id
                && candidate.definition != word.definition
                && !chosen.contains { $0.id == candidate.id || $0.definition == candidate.definition }
        }

        let pool = bank.positions(for: word.pos)
        if pool.count > 3 {
            let center = bank.insertionIndex(of: word.difficulty, in: pool)
            let length = Double(max(word.definition.count, 1))
            var window = 60
            for attempt in 0..<600 where chosen.count < 2 {
                if attempt > 0, attempt.isMultiple(of: 60) { window *= 2 }
                let low = max(0, center - window)
                let high = min(pool.count - 1, center + window)
                let candidate = bank.words[pool[Int.random(in: low...high, using: &generator)]]
                guard acceptable(candidate) else { continue }
                let strict = attempt < 300
                let ratio = Double(candidate.definition.count) / length
                if strict, ratio < 0.5 || ratio > 2.0 { continue }
                if attempt < 120, word.pos == .noun, candidate.gender != word.gender { continue }
                if TextMatching.reusesStem(of: word.text, in: candidate.definition) { continue }
                chosen.append(candidate)
            }
        }
        // Safety net, never reached with the bundled lexicon.
        var position = 0
        while chosen.count < 2, position < bank.words.count {
            let candidate = bank.words[position]
            if acceptable(candidate) { chosen.append(candidate) }
            position += 1
        }
        return chosen
    }
}

enum WordPicker {
    /// A random word among the `spread` unused words closest to `difficulty`.
    static func pick<G: RandomNumberGenerator>(near difficulty: Double, in bank: WordBank,
                                              excluding excluded: Set<Int>, spread: Int = 8,
                                              using generator: inout G) -> Word? {
        bank.words(near: difficulty, count: spread, excluding: excluded)
            .randomElement(using: &generator)
    }
}

/// SplitMix64: reproducible randomness (same daily challenge for everyone).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// FNV-1a hash of a string, stable across launches and devices.
    static func seed(from text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}

enum DailyChallenge {
    /// From very common to rare: share of French speakers knowing each word.
    static let popularityLadder: [Double] = [0.97, 0.92, 0.85, 0.76, 0.66, 0.56, 0.46, 0.36, 0.26, 0.16]
    static var length: Int { popularityLadder.count }

    static func questions(for day: String, in bank: WordBank) -> [Question] {
        var generator = SeededGenerator(seed: SeededGenerator.seed(from: "defi-\(day)"))
        var used = Set<Int>()
        var questions: [Question] = []
        for popularity in popularityLadder {
            let target = Difficulty.from(popularity: popularity)
            guard let word = bank.words(near: target, count: 30, excluding: used)
                .randomElement(using: &generator) else { continue }
            used.insert(word.id)
            questions.append(QuestionFactory.make(for: word, in: bank, using: &generator))
        }
        return questions
    }

    /// A rather rare word, with an example, featured on the home screen.
    static func wordOfTheDay(for day: String, in bank: WordBank) -> Word? {
        var generator = SeededGenerator(seed: SeededGenerator.seed(from: "mot-\(day)"))
        let target = Difficulty.from(popularity: Double.random(in: 0.2...0.45, using: &generator))
        return bank.words(near: target, count: 60, excluding: [])
            .filter { $0.example != nil }
            .randomElement(using: &generator)
    }
}
