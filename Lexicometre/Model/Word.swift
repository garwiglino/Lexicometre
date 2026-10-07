import Foundation

enum PartOfSpeech: String, Codable, CaseIterable, Sendable {
    case noun = "n"
    case verb = "v"
    case adjective = "adj"
    case adverb = "adv"

    var label: String {
        switch self {
        case .noun: "nom"
        case .verb: "verbe"
        case .adjective: "adjectif"
        case .adverb: "adverbe"
        }
    }
}

enum Gender: String, Codable, Sendable {
    case masculine = "m"
    case feminine = "f"
    case both = "mf"

    var label: String {
        switch self {
        case .masculine: "masculin"
        case .feminine: "féminin"
        case .both: "masculin et féminin"
        }
    }
}

/// A word of the quiz bank.
struct Word: Identifiable, Hashable, Sendable {
    /// Rank of the lemma among all the words of the lexicon (1 = best known). Unique.
    let id: Int
    let text: String
    let pos: PartOfSpeech
    let gender: Gender?
    /// Difficulty on the logit scale: P(known) = σ(a · (θ − difficulty)).
    let difficulty: Double
    let definition: String
    /// Usage example in Markdown, the headword in **bold**.
    let example: String?

    var rank: Int { id }

    /// "nom féminin", "verbe"…
    var grammar: String {
        if pos == .noun, let gender { return "nom \(gender.label)" }
        return pos.label
    }

    /// Estimated share of French speakers who know the word (Lexique 3.83 norms + frequency).
    var popularity: Double { 1 / (1 + exp(difficulty)) }

    var wiktionaryURL: URL? {
        let path = text.replacingOccurrences(of: " ", with: "_")
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "https://fr.wiktionary.org/wiki/\(encoded)")
    }
}

/// Converts a population share into a difficulty and back (logit scale).
enum Difficulty {
    static func from(popularity p: Double) -> Double {
        let q = min(max(p, 0.001), 0.999)
        return log((1 - q) / q)
    }
}
