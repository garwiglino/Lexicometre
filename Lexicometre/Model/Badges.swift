import Foundation

struct Badge: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String

    static let all: [Badge] = [
        Badge(id: "first_test", title: "Premier verdict", detail: "Terminer un test complet", symbol: "flag.checkered"),
        Badge(id: "streak_10", title: "Sans faute", detail: "10 bonnes réponses d'affilée", symbol: "flame"),
        Badge(id: "streak_25", title: "Inarrêtable", detail: "25 bonnes réponses d'affilée", symbol: "flame.fill"),
        Badge(id: "streak_50", title: "Légende", detail: "50 bonnes réponses d'affilée", symbol: "crown.fill"),
        Badge(id: "rare_20", title: "Dénicheur", detail: "Trouver un mot connu par moins de 20 % des francophones", symbol: "sparkle.magnifyingglass"),
        Badge(id: "rare_5", title: "Perle rare", detail: "Trouver un mot connu par moins de 5 % des francophones", symbol: "diamond.fill"),
        Badge(id: "answers_500", title: "Lexicophile", detail: "Répondre à 500 questions", symbol: "text.book.closed"),
        Badge(id: "answers_2000", title: "Lexicomane", detail: "Répondre à 2 000 questions", symbol: "books.vertical.fill"),
        Badge(id: "days_7", title: "Fidèle", detail: "Jouer 7 jours d'affilée", symbol: "calendar"),
        Badge(id: "days_30", title: "Assidu", detail: "Jouer 30 jours d'affilée", symbol: "calendar.badge.clock"),
        Badge(id: "daily_perfect", title: "Défi parfait", detail: "Faire 10/10 au défi du jour", symbol: "star.fill"),
        Badge(id: "chrono_15", title: "Éclair", detail: "15 bonnes réponses en contre-la-montre", symbol: "bolt.fill"),
        Badge(id: "chrono_25", title: "Foudre", detail: "25 bonnes réponses en contre-la-montre", symbol: "bolt.circle.fill"),
        Badge(id: "vocab_29000", title: "Érudit", detail: "Atteindre 29 000 mots estimés", symbol: "graduationcap.fill"),
        Badge(id: "vocab_38000", title: "Immortel", detail: "Atteindre 38 000 mots estimés", symbol: "building.columns.fill"),
        Badge(id: "precision_5", title: "Mesure fine", detail: "Estimation précise à ±5 %", symbol: "scope"),
        Badge(id: "carnet_25", title: "Mémoire d'éléphant", detail: "Apprendre 25 mots du carnet", symbol: "brain.head.profile"),
    ]

    static func with(id: String) -> Badge? {
        all.first { $0.id == id }
    }
}

extension PlayerData {
    /// Badges whose condition holds, earned or not.
    func satisfiedBadges(estimate: VocabularyEstimate?, rarestPopularity: Double?) -> Set<String> {
        var ids = Set<String>()
        if testsCompleted > 0 { ids.insert("first_test") }
        if bestStreak >= 10 { ids.insert("streak_10") }
        if bestStreak >= 25 { ids.insert("streak_25") }
        if bestStreak >= 50 { ids.insert("streak_50") }
        if let rarestPopularity {
            if rarestPopularity < 0.20 { ids.insert("rare_20") }
            if rarestPopularity < 0.05 { ids.insert("rare_5") }
        }
        if totalAnswered >= 500 { ids.insert("answers_500") }
        if totalAnswered >= 2_000 { ids.insert("answers_2000") }
        if bestDayStreak >= 7 { ids.insert("days_7") }
        if bestDayStreak >= 30 { ids.insert("days_30") }
        if dailyResults.values.contains(where: { $0.score == DailyChallenge.length }) { ids.insert("daily_perfect") }
        if chronoBest >= 15 { ids.insert("chrono_15") }
        if chronoBest >= 25 { ids.insert("chrono_25") }
        if let estimate, estimate.answered >= 20 {
            if estimate.median >= 29_000 { ids.insert("vocab_29000") }
            if estimate.median >= 38_000 { ids.insert("vocab_38000") }
            if estimate.precision <= 0.05 { ids.insert("precision_5") }
        }
        if carnet.filter(\.mastered).count >= 25 { ids.insert("carnet_25") }
        return ids
    }
}
