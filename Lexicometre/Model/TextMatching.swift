import Foundation

enum TextMatching {
    static let french = Locale(identifier: "fr_FR")

    /// Lowercase, without accents nor ligatures: "Mélancolie" → "melancolie", "œuvre" → "oeuvre".
    static func fold(_ text: String) -> String {
        text.lowercased(with: french)
            .replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "æ", with: "ae")
            .folding(options: [.diacriticInsensitive], locale: french)
    }

    static func tokens(_ text: String) -> [Substring] {
        fold(text).split(whereSeparator: { !$0.isLetter })
    }

    static func commonPrefixLength(_ a: Substring, _ b: Substring) -> Int {
        var length = 0
        for (x, y) in zip(a, b) {
            guard x == y else { break }
            length += 1
        }
        return length
    }

    /// True when `text` reuses `word` or its stem ("chanteur" / "Personne qui chante"):
    /// such a definition would give the answer away. Mirrors tools/build_dataset.py.
    static func reusesStem(of word: String, in text: String) -> Bool {
        let parts = tokens(word).filter { $0.count >= 3 }
        let stems = parts.isEmpty ? [Substring(fold(word))] : parts
        for token in tokens(text) where token.count >= 3 {
            for stem in stems {
                if token == stem { return true }
                let shortest = Double(min(token.count, stem.count))
                let needed = max(4, Int((0.6 * shortest).rounded(.up)))
                if commonPrefixLength(token, stem) >= needed { return true }
            }
        }
        return false
    }
}
