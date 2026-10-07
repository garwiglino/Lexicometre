import Foundation
import Observation

struct CarnetItem: Identifiable {
    let entry: CarnetEntry
    let word: Word
    var id: Int { entry.wordID }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
    let symbol: String
}

/// Root state of the app: lexicon, estimate and saved progress.
@MainActor
@Observable
final class AppModel {
    enum LoadState: Equatable {
        case loading
        case ready
        case failed(String)
    }

    struct CurvePoint: Identifiable {
        let rank: Int
        let player: Double
        let average: Double
        var id: Int { rank }
    }

    private(set) var loadState: LoadState = .loading
    private(set) var bank: WordBank?
    var player: PlayerData
    private(set) var estimate: VocabularyEstimate?
    /// Banners waiting to be shown (badges, daily goal).
    var toasts: [Toast] = []
    /// Notifications refused while enabling the daily reminder.
    var reminderDenied = false

    @ObservationIgnored private(set) var estimator: VocabularyEstimator?
    @ObservationIgnored private let storeURL: URL
    @ObservationIgnored private var generator = SystemRandomNumberGenerator()
    @ObservationIgnored private let saveQueue = DispatchQueue(label: "lexicometre.sauvegarde", qos: .utility)

    init(storeURL: URL? = nil) {
        let url = storeURL ?? Self.defaultStoreURL
        self.storeURL = url
        self.player = Self.read(from: url) ?? PlayerData()
        Haptics.enabled = player.settings.haptics
    }

    static var defaultStoreURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Lexicometre", isDirectory: true)
            .appendingPathComponent("progression.json")
    }

    // MARK: Loading

    func load() async {
        guard bank == nil else { return }
        let responses = player.responses
        let prior = player.profile.prior
        do {
            // Parsing the lexicon and replaying the answers takes a moment: keep it off the main thread.
            let (bank, estimator) = try await Task.detached(priority: .userInitiated) {
                let bank = try WordBank.loadBundled()
                return (bank, Self.makeEstimator(bank: bank, responses: responses, prior: prior))
            }.value
            self.bank = bank
            self.estimator = estimator
            estimate = estimator.answered > 0 ? estimator.estimate() : nil
            loadState = .ready
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    /// Installs the lexicon and replays the saved answers into the estimator.
    func install(_ bank: WordBank) {
        self.bank = bank
        rebuildEstimator()
        loadState = .ready
    }

    private func rebuildEstimator() {
        guard let bank else { return }
        let estimator = Self.makeEstimator(bank: bank, responses: player.responses, prior: player.profile.prior)
        self.estimator = estimator
        estimate = estimator.answered > 0 ? estimator.estimate() : nil
    }

    nonisolated private static func makeEstimator(bank: WordBank, responses: [ResponseRecord],
                                                  prior: EstimatorPrior) -> VocabularyEstimator {
        var estimator = VocabularyEstimator(histogram: bank.histogram, universe: bank.universeSize, prior: prior)
        for response in responses where response.counts {
            estimator.add(difficulty: response.difficulty, outcome: response.outcome)
        }
        return estimator
    }

    // MARK: Profile & settings

    func completeOnboarding(profile: Profile) {
        player.profile = profile
        player.onboarded = true
        rebuildEstimator()
        save()
    }

    func setProfile(_ profile: Profile) {
        guard profile != player.profile else { return }
        player.profile = profile
        save()
        guard let bank else { return }
        let responses = player.responses
        Task {
            var estimator = await Task.detached(priority: .userInitiated) {
                Self.makeEstimator(bank: bank, responses: responses, prior: profile.prior)
            }.value
            guard player.profile == profile else { return }
            // Answers given while recomputing.
            for response in player.responses.dropFirst(responses.count) where response.counts {
                estimator.add(difficulty: response.difficulty, outcome: response.outcome)
            }
            self.estimator = estimator
            estimate = estimator.answered > 0 ? estimator.estimate() : nil
        }
    }

    func settingsChanged() {
        Haptics.enabled = player.settings.haptics
        save()
    }

    /// Schedules or cancels the daily reminder; switches it off if notifications are refused.
    func updateReminder() async {
        if player.settings.reminder {
            let scheduled = await Reminders.schedule(hour: player.settings.reminderHour,
                                                     minute: player.settings.reminderMinute)
            if !scheduled {
                player.settings.reminder = false
                reminderDenied = true
            }
        } else {
            Reminders.cancel()
        }
        save()
    }

    func resetProgress() {
        var fresh = PlayerData()
        fresh.settings = player.settings
        fresh.profile = player.profile
        fresh.onboarded = true
        player = fresh
        toasts.removeAll()
        rebuildEstimator()
        save()
    }

    // MARK: Questions

    /// Next word to ask: adaptive (Thompson sampling) with an exploratory word every sixth question.
    func nextWord(for mode: GameMode, questionIndex: Int, excluding sessionWords: Set<Int>) -> Word? {
        guard let bank, let estimator else { return nil }
        let target: Double
        if mode != .chrono, questionIndex % 6 == 5 {
            target = Double.random(in: bank.difficultyRange, using: &generator)
        } else {
            let successRate: Double
            switch mode {
            case _ where questionIndex < 3: successRate = 0.8
            case .chrono: successRate = 0.75
            case .free: successRate = 0.68
            default: successRate = 0.62
            }
            target = estimator.targetDifficulty(successRate: successRate, using: &generator)
        }
        let excluded = player.seen.union(sessionWords)
        return WordPicker.pick(near: target, in: bank, excluding: excluded, using: &generator)
            ?? WordPicker.pick(near: target, in: bank, excluding: sessionWords, using: &generator)
    }

    var dueReviewWords: [Word] {
        guard let bank else { return [] }
        let now = Date()
        return player.carnet
            .filter { !$0.mastered && $0.due <= now }
            .sorted { $0.due < $1.due }
            .compactMap { bank.word(id: $0.wordID) }
    }

    func carnetWords(mastered: Bool) -> [CarnetItem] {
        guard let bank else { return [] }
        return player.carnet
            .filter { $0.mastered == mastered }
            .sorted { $0.added > $1.added }
            .compactMap { entry in bank.word(id: entry.wordID).map { CarnetItem(entry: entry, word: $0) } }
    }

    /// A word revealed outside the quiz (word of the day) no longer measures anything.
    func markSeen(_ word: Word) {
        guard !player.seen.contains(word.id) else { return }
        player.seen.insert(word.id)
        save()
    }

    func removeFromCarnet(_ wordID: Int) {
        player.carnet.removeAll { $0.wordID == wordID }
        save()
    }

    // MARK: Answers

    /// Saves an answer and returns the XP earned.
    @discardableResult
    func record(_ outcome: AnswerOutcome, word: Word, mode: GameMode, streak: Int) -> Int {
        let now = Date()
        let levelBefore = XPLevel.level(for: player.xp)
        registerActivity(at: now)
        let wasSeen = player.seen.contains(word.id)
        player.seen.insert(word.id)
        player.totalAnswered += 1
        player.bestStreak = max(player.bestStreak, streak)

        var reward = 0
        if outcome == .correct {
            player.totalCorrect += 1
            reward = XPLevel.reward(for: word, streak: streak)
            player.xp += reward
            if mode != .review, word.popularity < (rarestKnownWord?.popularity ?? 1) {
                player.rarestKnownID = word.id
            }
        }

        let counts = mode.refinesEstimate && !(mode == .daily && wasSeen)
        player.responses.append(ResponseRecord(wordID: word.id, difficulty: word.difficulty,
                                               outcome: outcome, date: now, counts: counts))
        if counts, var estimator {
            estimator.add(difficulty: word.difficulty, outcome: outcome)
            self.estimator = estimator
            estimate = estimator.estimate()
        }
        updateCarnet(word: word, outcome: outcome, mode: mode, now: now)
        celebrateGoalIfReached()
        let level = XPLevel.level(for: player.xp)
        if level > levelBefore {
            Haptics.celebrate()
            toasts.append(Toast(title: "Niveau \(level) atteint !", detail: "Les mots rares rapportent plus d'XP.",
                                symbol: "star.circle.fill"))
        }
        celebrateTitleIfNew()
        checkBadges()
        save()
        return reward
    }

    private func celebrateTitleIfNew() {
        guard let estimate, estimate.answered >= QuizSession.testLength else { return }
        let title = VocabularyTitle.title(for: estimate.median)
        guard title.minimum > player.bestTitleMinimum else { return }
        let isFirst = player.bestTitleMinimum < 0
        player.bestTitleMinimum = title.minimum
        Haptics.celebrate()
        toasts.append(Toast(title: isFirst ? "Ton titre : \(title.name)" : "Nouveau titre : \(title.name) !",
                            detail: title.blurb, symbol: title.symbol))
    }

    func finishSession(mode: GameMode, outcomes: [AnswerOutcome], score: Int, completed: Bool) {
        if mode == .test, completed { player.testsCompleted += 1 }
        if mode == .daily, completed, player.dailyResults[DayKey.today] == nil {
            player.dailyResults[DayKey.today] = DailyResult(day: DayKey.today, outcomes: outcomes)
        }
        if mode == .chrono { player.chronoBest = max(player.chronoBest, score) }
        if mode.refinesEstimate, !outcomes.isEmpty { recordHistoryPoint() }
        checkBadges()
        save()
    }

    private func updateCarnet(word: Word, outcome: AnswerOutcome, mode: GameMode, now: Date) {
        guard let index = player.carnet.firstIndex(where: { $0.wordID == word.id }) else {
            if outcome != .correct {
                player.carnet.append(CarnetEntry(wordID: word.id, added: now, box: 0, due: now, mastered: false))
            }
            return
        }
        if outcome != .correct {
            player.carnet[index].box = 0
            player.carnet[index].due = now
            player.carnet[index].mastered = false
        } else if mode == .review {
            let box = player.carnet[index].box + 1
            player.carnet[index].box = box
            if box >= CarnetEntry.intervals.count {
                player.carnet[index].mastered = true
            } else {
                player.carnet[index].due = now.addingTimeInterval(CarnetEntry.intervals[box])
            }
        }
    }

    private func registerActivity(at now: Date) {
        let calendar = Calendar.current
        if let last = player.lastActiveDate {
            if calendar.isDate(last, inSameDayAs: now) {
                // already counted today
            } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                      calendar.isDate(last, inSameDayAs: yesterday) {
                player.dayStreak += 1
            } else {
                player.dayStreak = 1
            }
        } else {
            player.dayStreak = 1
        }
        player.lastActiveDate = now
        player.bestDayStreak = max(player.bestDayStreak, player.dayStreak)
        let key = DayKey.of(now)
        if player.todayKey != key {
            player.todayKey = key
            player.todayCount = 0
        }
        player.todayCount += 1
    }

    private func celebrateGoalIfReached() {
        guard player.todayCount >= player.settings.dailyGoal, player.goalCelebratedKey != player.todayKey else { return }
        player.goalCelebratedKey = player.todayKey
        Haptics.celebrate()
        toasts.append(Toast(title: "Objectif du jour atteint !",
                            detail: "\(player.settings.dailyGoal) mots aujourd'hui. Reviens demain pour ta série.",
                            symbol: "target"))
    }

    private func recordHistoryPoint() {
        guard let estimate, estimate.answered >= 10 else { return }
        let point = EstimatePoint(date: Date(), median: estimate.median, low: estimate.low, high: estimate.high)
        if let last = player.history.last, Calendar.current.isDate(last.date, inSameDayAs: point.date) {
            player.history[player.history.count - 1] = point
        } else {
            player.history.append(point)
        }
    }

    private func checkBadges() {
        let satisfied = player.satisfiedBadges(estimate: estimate, rarestPopularity: rarestKnownWord?.popularity)
        for badge in Badge.all where satisfied.contains(badge.id) && player.badges[badge.id] == nil {
            player.badges[badge.id] = Date()
            Haptics.celebrate()
            toasts.append(Toast(title: "Badge débloqué : \(badge.title)", detail: badge.detail, symbol: badge.symbol))
        }
    }

    // MARK: Derived values

    var rarestKnownWord: Word? {
        player.rarestKnownID.flatMap { bank?.word(id: $0) }
    }

    var vocabularyTitle: VocabularyTitle? {
        estimate.map { VocabularyTitle.title(for: $0.median) }
    }

    /// Day streak displayed on the home screen (0 once broken).
    var currentDayStreak: Int {
        guard let last = player.lastActiveDate else { return 0 }
        let calendar = Calendar.current
        return calendar.isDateInToday(last) || calendar.isDateInYesterday(last) ? player.dayStreak : 0
    }

    var todayCount: Int { player.todayKey == DayKey.today ? player.todayCount : 0 }

    var todaysDailyResult: DailyResult? { player.dailyResults[DayKey.today] }

    var wordOfTheDay: Word? {
        bank.flatMap { DailyChallenge.wordOfTheDay(for: DayKey.today, in: $0) }
    }

    /// Probability of knowing a word according to its rank: the player vs. an average French speaker.
    func knowledgeCurve(samples: Int = 60) -> [CurvePoint] {
        guard let bank, let estimator, bank.words.count > samples else { return [] }
        let step = Double(bank.words.count - 1) / Double(samples - 1)
        let words = (0..<samples).map { bank.words[Int((Double($0) * step).rounded())] }
        let known = estimator.knowledge(at: words.map(\.difficulty))
        return zip(words, known).map { CurvePoint(rank: $0.id, player: $1, average: $0.popularity) }
    }

    // MARK: Storage

    /// Writes the progress in the background, in order, without blocking the game.
    func save() {
        let snapshot = player
        let url = storeURL
        saveQueue.async {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
            } catch {
                print("Lexicomètre : sauvegarde impossible (\(error))")
            }
        }
    }

    /// Waits for the pending writes.
    func flush() {
        saveQueue.sync {}
    }

    private static func read(from url: URL) -> PlayerData? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PlayerData.self, from: data)
    }
}
