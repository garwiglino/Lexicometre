import Foundation
import Observation

/// One game: a series of questions in a given mode.
@MainActor
@Observable
final class QuizSession: Identifiable {
    enum Phase: Equatable {
        case asking
        case answered(outcome: AnswerOutcome, choice: Int?)
        case finished
    }

    static let testLength = 40
    static let chronoDuration: TimeInterval = 60
    static let reviewLength = 15

    let mode: GameMode
    let app: AppModel

    /// Number of questions, nil when the game goes on until the player stops (or the time is up).
    private(set) var length: Int?
    private(set) var question: Question?
    private(set) var phase: Phase = .asking
    private(set) var answeredCount = 0
    private(set) var streak = 0
    private(set) var bestStreak = 0
    private(set) var correctCount = 0
    private(set) var wrongCount = 0
    private(set) var unknownCount = 0
    private(set) var xpGained = 0
    private(set) var lastReward = 0
    private(set) var outcomes: [AnswerOutcome] = []
    private(set) var missedWords: [Word] = []
    private(set) var rarestKnown: Word?
    private(set) var startEstimate: VocabularyEstimate?
    private(set) var deadline: Date?
    private(set) var isNewChronoRecord = false
    private(set) var started = false

    @ObservationIgnored private var usedWords = Set<Int>()
    @ObservationIgnored private var queue: [Question] = []
    @ObservationIgnored private var generator = SystemRandomNumberGenerator()
    @ObservationIgnored private var clock: Task<Void, Never>?

    init(mode: GameMode, app: AppModel) {
        self.mode = mode
        self.app = app
        switch mode {
        case .test: length = Self.testLength
        case .daily: length = DailyChallenge.length
        case .free, .chrono, .review: length = nil
        }
    }

    var isFinished: Bool { phase == .finished }

    var isAnswered: Bool {
        if case .answered = phase { return true }
        return false
    }

    var answeredOutcome: AnswerOutcome? {
        if case .answered(let outcome, _) = phase { return outcome }
        return nil
    }

    var answeredChoice: Int? {
        if case .answered(_, let choice) = phase { return choice }
        return nil
    }

    /// The last question has been answered.
    var isLastQuestion: Bool {
        guard let length else { return false }
        return answeredCount >= length
    }

    /// Progress 0…1 for modes with a fixed length.
    var progress: Double {
        guard let length, length > 0 else { return 0 }
        return Double(answeredCount) / Double(length)
    }

    func start() {
        guard !started, let bank = app.bank else { return }
        started = true
        startEstimate = app.estimate
        switch mode {
        case .daily:
            queue = DailyChallenge.questions(for: DayKey.today, in: bank)
            length = queue.count
        case .review:
            queue = app.dueReviewWords.prefix(Self.reviewLength).map {
                QuestionFactory.make(for: $0, in: bank, using: &generator)
            }
            length = queue.count
        case .chrono:
            deadline = Date().addingTimeInterval(Self.chronoDuration)
            startClock()
        case .test, .free:
            break
        }
        advance()
    }

    func choose(_ index: Int) {
        guard case .asking = phase, let question else { return }
        resolve(index == question.correctIndex ? .correct : .wrong, choice: index)
    }

    func dontKnow() {
        guard case .asking = phase else { return }
        resolve(.unknown, choice: nil)
    }

    func next() {
        guard isAnswered else { return }
        advance()
    }

    /// Ends the game (last question answered, time up, or the player stops).
    func finish() {
        guard phase != .finished else { return }
        clock?.cancel()
        if mode == .chrono {
            isNewChronoRecord = correctCount > app.player.chronoBest
        }
        let completed = length.map { answeredCount >= $0 } ?? true
        if answeredCount > 0 || mode == .chrono {
            app.finishSession(mode: mode, outcomes: outcomes, score: correctCount, completed: completed)
        }
        phase = .finished
    }

    func timeRemaining(at date: Date) -> TimeInterval {
        guard let deadline else { return 0 }
        return max(0, deadline.timeIntervalSince(date))
    }

    // MARK: Private

    private var isTimeUp: Bool {
        deadline.map { Date() >= $0 } ?? false
    }

    private func resolve(_ outcome: AnswerOutcome, choice: Int?) {
        guard let question else { return }
        if isTimeUp {
            finish()
            return
        }
        switch outcome {
        case .correct:
            streak += 1
            correctCount += 1
            if question.word.popularity < (rarestKnown?.popularity ?? 1) { rarestKnown = question.word }
            Haptics.success()
        case .wrong:
            streak = 0
            wrongCount += 1
            missedWords.append(question.word)
            Haptics.error()
        case .unknown:
            // An honest "je ne sais pas" does not break the streak.
            unknownCount += 1
            missedWords.append(question.word)
            Haptics.soft()
        }
        bestStreak = max(bestStreak, streak)
        answeredCount += 1
        outcomes.append(outcome)
        lastReward = app.record(outcome, word: question.word, mode: mode, streak: streak)
        xpGained += lastReward
        phase = .answered(outcome: outcome, choice: choice)
    }

    private func advance() {
        if let length, answeredCount >= length {
            finish()
            return
        }
        if !queue.isEmpty {
            question = queue.removeFirst()
        } else if mode == .daily || mode == .review {
            finish()
            return
        } else if let bank = app.bank,
                  let word = app.nextWord(for: mode, questionIndex: answeredCount, excluding: usedWords) {
            question = QuestionFactory.make(for: word, in: bank, using: &generator)
        } else {
            finish()
            return
        }
        if let question { usedWords.insert(question.word.id) }
        phase = .asking
    }

    private func startClock() {
        clock = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard let self else { return }
                if self.isTimeUp {
                    self.finish()
                    return
                }
            }
        }
    }
}
