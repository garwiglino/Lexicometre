import Foundation

/// Title given according to the estimated vocabulary.
struct VocabularyTitle: Equatable, Sendable {
    let name: String
    let symbol: String
    let minimum: Int
    let blurb: String

    static let all: [VocabularyTitle] = [
        VocabularyTitle(name: "Graine de mots", symbol: "leaf", minimum: 0,
                        blurb: "Les premiers mots germent. Chaque partie en fait pousser de nouveaux."),
        VocabularyTitle(name: "Curieux", symbol: "eyes", minimum: 1_500,
                        blurb: "Tu maîtrises les mots du quotidien et tu en veux davantage."),
        VocabularyTitle(name: "Explorateur", symbol: "map", minimum: 4_000,
                        blurb: "Tu circules à l'aise dans la langue courante."),
        VocabularyTitle(name: "Voyageur des mots", symbol: "airplane", minimum: 9_000,
                        blurb: "Presse, romans, conversations : peu de choses t'échappent."),
        VocabularyTitle(name: "Lecteur assidu", symbol: "book", minimum: 16_000,
                        blurb: "Un vocabulaire riche, nourri de lectures."),
        VocabularyTitle(name: "Fin lettré", symbol: "pencil.and.outline", minimum: 23_000,
                        blurb: "Tu manies les nuances et les mots choisis."),
        VocabularyTitle(name: "Érudit", symbol: "graduationcap", minimum: 29_000,
                        blurb: "Ton lexique dépasse celui de la plupart des diplômés."),
        VocabularyTitle(name: "Encyclopédiste", symbol: "books.vertical", minimum: 34_000,
                        blurb: "Même les mots rares et savants te sont familiers."),
        VocabularyTitle(name: "Immortel", symbol: "building.columns", minimum: 38_000,
                        blurb: "Digne de l'Académie française : une langue presque sans secret."),
    ]

    static func title(for vocabulary: Double) -> VocabularyTitle {
        all.last { Double($0.minimum) <= vocabulary } ?? all[0]
    }

    static func next(after title: VocabularyTitle) -> VocabularyTitle? {
        guard let index = all.firstIndex(of: title), index + 1 < all.count else { return nil }
        return all[index + 1]
    }
}

/// Indicative landmarks on the same scale (words of the lexicon known).
struct Benchmark: Identifiable, Sendable {
    let label: String
    let value: Int
    var id: String { label }

    static let all: [Benchmark] = [
        Benchmark(label: "Débutant (A2)", value: 2_000),
        Benchmark(label: "Intermédiaire (B2)", value: 6_000),
        Benchmark(label: "Collégien", value: 15_000),
        Benchmark(label: "Adulte", value: 25_000),
        Benchmark(label: "Étudiant", value: 31_500),
        Benchmark(label: "Grand lecteur", value: 36_000),
    ]
}

/// Experience levels: level n needs 60·(n−1)² XP.
enum XPLevel {
    static func level(for xp: Int) -> Int {
        Int((Double(max(xp, 0)) / 60).squareRoot()) + 1
    }

    static func threshold(of level: Int) -> Int {
        60 * (level - 1) * (level - 1)
    }

    /// Progress (0…1) toward the next level.
    static func progress(for xp: Int) -> Double {
        let current = level(for: xp)
        let start = threshold(of: current)
        let end = threshold(of: current + 1)
        return Double(xp - start) / Double(max(end - start, 1))
    }

    /// XP earned by a right answer: rare words and long streaks pay more.
    static func reward(for word: Word, streak: Int) -> Int {
        let base = 5 + Int(((1 - word.popularity) * 30).rounded())
        return Int((Double(base) * multiplier(for: streak)).rounded())
    }

    static func multiplier(for streak: Int) -> Double {
        switch streak {
        case ..<3: 1
        case 3..<6: 1.5
        case 6..<10: 2
        default: 3
        }
    }
}
