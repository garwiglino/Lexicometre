import Foundation

enum Profile: String, Codable, Sendable {
    case native
    case learner
    case unspecified

    var prior: EstimatorPrior {
        switch self {
        case .native: .native
        case .learner: .learner
        case .unspecified: .unspecified
        }
    }
}

enum GameMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case test
    case free
    case daily
    case chrono
    case review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .test: "Test complet"
        case .free: "Mode libre"
        case .daily: "Défi du jour"
        case .chrono: "Contre-la-montre"
        case .review: "Révisions"
        }
    }

    /// Answers of these modes feed the vocabulary estimate (no time pressure, fresh words).
    var refinesEstimate: Bool { self == .test || self == .free || self == .daily }
}

struct ResponseRecord: Codable, Sendable {
    var wordID: Int
    var difficulty: Double
    var outcome: AnswerOutcome
    var date: Date
    /// Feeds the vocabulary estimate.
    var counts: Bool

    enum CodingKeys: String, CodingKey {
        case wordID = "w", difficulty = "d", outcome = "o", date = "t", counts = "c"
    }
}

/// A word to review (Leitner boxes: 1 day, 3 days, 7 days, then learnt).
struct CarnetEntry: Codable, Identifiable, Sendable {
    var wordID: Int
    var added: Date
    var box: Int
    var due: Date
    var mastered: Bool

    var id: Int { wordID }

    static let intervals: [TimeInterval] = [0, 86_400, 3 * 86_400, 7 * 86_400]
}

struct DailyResult: Codable, Sendable {
    var day: String
    var outcomes: [AnswerOutcome]

    var score: Int { outcomes.filter { $0 == .correct }.count }

    var emojiLine: String {
        outcomes.map { outcome in
            switch outcome {
            case .correct: "🟩"
            case .wrong: "🟥"
            case .unknown: "⬜️"
            }
        }.joined()
    }
}

struct EstimatePoint: Codable, Identifiable, Sendable {
    var date: Date
    var median: Double
    var low: Double
    var high: Double

    var id: Date { date }
}

struct Settings: Codable, Equatable, Sendable {
    var haptics = true
    var reminder = false
    var reminderHour = 19
    var reminderMinute = 0
    var dailyGoal = 20

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Settings()
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? defaults.haptics
        reminder = try c.decodeIfPresent(Bool.self, forKey: .reminder) ?? defaults.reminder
        reminderHour = try c.decodeIfPresent(Int.self, forKey: .reminderHour) ?? defaults.reminderHour
        reminderMinute = try c.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? defaults.reminderMinute
        dailyGoal = try c.decodeIfPresent(Int.self, forKey: .dailyGoal) ?? defaults.dailyGoal
    }
}

/// Everything saved on the device.
struct PlayerData: Codable, Sendable {
    var profile: Profile = .unspecified
    var onboarded = false
    var responses: [ResponseRecord] = []
    /// Words already shown (never asked again to refine the estimate).
    var seen: Set<Int> = []
    var carnet: [CarnetEntry] = []
    var xp = 0
    var bestStreak = 0
    var totalAnswered = 0
    var totalCorrect = 0
    var dayStreak = 0
    var bestDayStreak = 0
    var lastActiveDate: Date?
    var todayKey = ""
    var todayCount = 0
    var goalCelebratedKey = ""
    var dailyResults: [String: DailyResult] = [:]
    var chronoBest = 0
    var testsCompleted = 0
    var history: [EstimatePoint] = []
    var badges: [String: Date] = [:]
    var rarestKnownID: Int?
    /// Highest vocabulary title reached (its minimum), to celebrate each new one once.
    var bestTitleMinimum = -1
    var settings = Settings()

    init() {}

    // Tolerant decoding: a field added in a later version must not wipe the progress.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PlayerData()
        profile = try c.decodeIfPresent(Profile.self, forKey: .profile) ?? d.profile
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? d.onboarded
        responses = try c.decodeIfPresent([ResponseRecord].self, forKey: .responses) ?? d.responses
        seen = try c.decodeIfPresent(Set<Int>.self, forKey: .seen) ?? d.seen
        carnet = try c.decodeIfPresent([CarnetEntry].self, forKey: .carnet) ?? d.carnet
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? d.xp
        bestStreak = try c.decodeIfPresent(Int.self, forKey: .bestStreak) ?? d.bestStreak
        totalAnswered = try c.decodeIfPresent(Int.self, forKey: .totalAnswered) ?? d.totalAnswered
        totalCorrect = try c.decodeIfPresent(Int.self, forKey: .totalCorrect) ?? d.totalCorrect
        dayStreak = try c.decodeIfPresent(Int.self, forKey: .dayStreak) ?? d.dayStreak
        bestDayStreak = try c.decodeIfPresent(Int.self, forKey: .bestDayStreak) ?? d.bestDayStreak
        lastActiveDate = try c.decodeIfPresent(Date.self, forKey: .lastActiveDate)
        todayKey = try c.decodeIfPresent(String.self, forKey: .todayKey) ?? d.todayKey
        todayCount = try c.decodeIfPresent(Int.self, forKey: .todayCount) ?? d.todayCount
        goalCelebratedKey = try c.decodeIfPresent(String.self, forKey: .goalCelebratedKey) ?? d.goalCelebratedKey
        dailyResults = try c.decodeIfPresent([String: DailyResult].self, forKey: .dailyResults) ?? d.dailyResults
        chronoBest = try c.decodeIfPresent(Int.self, forKey: .chronoBest) ?? d.chronoBest
        testsCompleted = try c.decodeIfPresent(Int.self, forKey: .testsCompleted) ?? d.testsCompleted
        history = try c.decodeIfPresent([EstimatePoint].self, forKey: .history) ?? d.history
        badges = try c.decodeIfPresent([String: Date].self, forKey: .badges) ?? d.badges
        rarestKnownID = try c.decodeIfPresent(Int.self, forKey: .rarestKnownID)
        bestTitleMinimum = try c.decodeIfPresent(Int.self, forKey: .bestTitleMinimum) ?? d.bestTitleMinimum
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? d.settings
    }

    var countedResponses: Int { responses.lazy.filter(\.counts).count }
    var accuracy: Double { totalAnswered > 0 ? Double(totalCorrect) / Double(totalAnswered) : 0 }
}

enum DayKey {
    /// "2026-10-06" in the user's calendar.
    static func of(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static var today: String { of(Date()) }
}
