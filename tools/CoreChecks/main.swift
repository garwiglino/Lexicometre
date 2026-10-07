// Checks of the app logic outside of iOS (Linux or macOS):
//   tools/run_core_checks.sh
import Foundation

var failures = 0
func check(_ condition: Bool, _ message: String) {
    if !condition {
        failures += 1
        print("ÉCHEC : \(message)")
    }
}

struct SimulatedPlayer {
    var theta: Double
    var slope: Double
    var guessing: Double   // probability of guessing an unknown word instead of "je ne sais pas"
    var generator = SystemRandomNumberGenerator()

    mutating func answer(_ question: Question) -> Int? {
        let known = 1 / (1 + exp(-slope * (theta - question.word.difficulty)))
        if Double.random(in: 0..<1, using: &generator) < known {
            return Double.random(in: 0..<1, using: &generator) < 0.97
                ? question.correctIndex : (question.correctIndex + 1) % 3
        }
        if Double.random(in: 0..<1, using: &generator) < guessing { return Int.random(in: 0..<3, using: &generator) }
        return nil
    }

    func trueVocabulary(_ bank: WordBank) -> Double {
        bank.histogram.bins.reduce(0) { $0 + $1.count / (1 + exp(-slope * (theta - $1.center))) }
    }
}

@MainActor
func runAll(tsvPath: String) async {
    let start = Date()
    let text = try! String(contentsOfFile: tsvPath, encoding: .utf8)
    let bank = try! WordBank(text: text)
    print("Lexique : \(bank.words.count) mots de quiz, univers \(bank.universeSize), chargé en \(String(format: "%.2f", Date().timeIntervalSince(start))) s")
    check(bank.universeSize == bank.histogram.counts.reduce(0, +), "l'histogramme couvre tout l'univers")
    check(bank.words.count > 20_000, "assez de mots de quiz")
    check(zip(bank.words, bank.words.dropFirst()).allSatisfy { $0.difficulty <= $1.difficulty }, "mots triés par difficulté")
    check(zip(bank.words, bank.words.dropFirst()).allSatisfy { $0.id < $1.id }, "le rang suit la difficulté")
    check(Set(bank.words.map(\.id)).count == bank.words.count, "identifiants uniques")
    check(bank.word(id: bank.words[100].id)?.text == bank.words[100].text, "recherche par identifiant")

    // Text matching mirrors the Python build script.
    check(TextMatching.reusesStem(of: "chanteur", in: "Personne qui chante."), "radical réutilisé détecté")
    check(TextMatching.reusesStem(of: "mélancolique", in: "Qui est atteint de mélancolie."), "accents ignorés")
    check(!TextMatching.reusesStem(of: "comprendre", in: "Comprimer fortement."), "pas de faux positif")
    check(!TextMatching.reusesStem(of: "chat", in: "Mammifère carnivore félin de taille moyenne."), "définition saine")

    // Questions.
    var generator = SystemRandomNumberGenerator()
    var lengthRatios: [Double] = []
    let questionStart = Date()
    for _ in 0..<3_000 {
        let word = bank.words.randomElement(using: &generator)!
        let question = QuestionFactory.make(for: word, in: bank, using: &generator)
        check(question.options.count == 3, "trois définitions")
        check(Set(question.options).count == 3, "définitions distinctes pour \(word.text)")
        check(question.options[question.correctIndex] == word.definition, "bonne réponse en place")
        for option in question.options where option != word.definition {
            check(!TextMatching.reusesStem(of: word.text, in: option), "leurre sans le radical de \(word.text)")
            lengthRatios.append(Double(option.count) / Double(word.definition.count))
        }
    }
    let perQuestion = Date().timeIntervalSince(questionStart) / 3_000 * 1_000
    lengthRatios.sort()
    print("Questions : \(String(format: "%.2f", perQuestion)) ms/question, ratio de longueur des leurres médian \(String(format: "%.2f", lengthRatios[lengthRatios.count / 2]))")

    // Daily challenge is reproducible.
    let a = DailyChallenge.questions(for: "2026-10-06", in: bank)
    let b = DailyChallenge.questions(for: "2026-10-06", in: bank)
    let c = DailyChallenge.questions(for: "2026-10-07", in: bank)
    check(a.count == 10, "10 mots au défi")
    check(a.map(\.word.id) == b.map(\.word.id) && a.map(\.options) == b.map(\.options), "défi reproductible")
    check(a.map(\.word.id) != c.map(\.word.id), "défi différent le lendemain")
    print("Défi du 2026-10-06 : " + a.map { "\($0.word.text) (\(Int($0.word.popularity * 100)) %)" }.joined(separator: ", "))
    if let word = DailyChallenge.wordOfTheDay(for: "2026-10-06", in: bank) {
        print("Mot du jour : \(word.text) — \(word.definition)")
    }

    // Estimator speed.
    var estimator = VocabularyEstimator(histogram: bank.histogram, universe: bank.universeSize, prior: .native)
    let estimatorStart = Date()
    for i in 0..<200 { estimator.add(difficulty: Double(i % 9) - 5, outcome: i % 3 == 0 ? .wrong : .correct) }
    _ = estimator.estimate()
    print("Estimateur : \(String(format: "%.2f", Date().timeIntervalSince(estimatorStart) / 200 * 1_000)) ms/réponse")

    // Full games with simulated players.
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lexicometre-checks-\(UUID().uuidString)")
    var errors: [Double] = []
    let profiles: [(Double, Double, Double, Profile)] = [
        (0.0, 1.0, 0.3, .native), (1.2, 1.0, 1.0, .native), (-1.5, 0.8, 0.5, .native),
        (2.0, 1.4, 0.2, .native), (-4.5, 1.0, 0.3, .learner), (0.5, 0.7, 0.0, .native),
    ]
    for (index, profile) in profiles.enumerated() {
        let url = directory.appendingPathComponent("p\(index).json")
        let app = AppModel(storeURL: url)
        app.install(bank)
        app.completeOnboarding(profile: profile.3)
        var player = SimulatedPlayer(theta: profile.0, slope: profile.1, guessing: profile.2)
        let session = QuizSession(mode: .test, app: app)
        session.start()
        var asked = Set<Int>()
        while !session.isFinished {
            guard let question = session.question else { break }
            check(!asked.contains(question.word.id), "pas de mot répété")
            asked.insert(question.word.id)
            if let choice = player.answer(question) { session.choose(choice) } else { session.dontKnow() }
            session.next()
        }
        check(session.answeredCount == QuizSession.testLength, "test de 40 questions")
        let truth = player.trueVocabulary(bank)
        let estimate = app.estimate!
        errors.append(abs(estimate.median - truth) / truth)
        print(String(format: "Joueur θ=%+.1f a=%.1f devine=%.1f : réel %6.0f, estimé %6d [%d – %d] ±%.0f %%, %@",
                     profile.0, profile.1, profile.2, truth, estimate.displayValue, estimate.displayLow,
                     estimate.displayHigh, estimate.precision * 100, app.vocabularyTitle?.name ?? "-"))
        check(app.player.testsCompleted == 1, "test comptabilisé")
        check(app.player.history.count == 1, "point d'historique enregistré")
        check(app.player.carnet.count == session.wrongCount + session.unknownCount, "erreurs ajoutées au carnet")

        // Saved progress is read back identically.
        app.flush()
        let reopened = AppModel(storeURL: url)
        reopened.install(bank)
        check(reopened.player.responses.count == app.player.responses.count, "progression relue")
        check(abs((reopened.estimate?.median ?? 0) - estimate.median) < 1, "estimation identique après relecture")

        if index == 0 {
            // Review mode: answering right moves words up the Leitner boxes.
            let review = QuizSession(mode: .review, app: app)
            review.start()
            let due = review.length ?? 0
            check(due == min(app.player.carnet.count, QuizSession.reviewLength), "révisions dues")
            while !review.isFinished, let question = review.question {
                review.choose(question.correctIndex)
                review.next()
            }
            check(app.player.carnet.filter { $0.box == 1 }.count == due, "mots passés en boîte 1")
            check(app.dueReviewWords.count == app.player.carnet.count - due, "plus dus avant demain")

            // Daily challenge: 10 questions, saved once.
            let daily = QuizSession(mode: .daily, app: app)
            daily.start()
            while !daily.isFinished, let question = daily.question {
                daily.choose(question.correctIndex)
                daily.next()
            }
            check(app.todaysDailyResult?.score == 10, "défi enregistré : \(app.todaysDailyResult?.emojiLine ?? "-")")
            check(app.player.badges["daily_perfect"] != nil, "badge défi parfait")
            check(app.player.badges["first_test"] != nil, "badge premier test")

            // Chrono: questions keep coming, finish records the score.
            let chrono = QuizSession(mode: .chrono, app: app)
            chrono.start()
            for _ in 0..<12 {
                guard let question = chrono.question else { break }
                chrono.choose(question.correctIndex)
                chrono.next()
            }
            chrono.finish()
            check(app.player.chronoBest == 12, "record du chrono")
            check(chrono.isNewChronoRecord, "nouveau record signalé")
            check(app.currentDayStreak == 1, "série de jours")
            check(app.todayCount == app.player.totalAnswered, "compteur du jour")
            let curve = app.knowledgeCurve()
            check(curve.count == 60 && curve.first!.player > curve.last!.player, "courbe de connaissance décroissante")

            // Changing the profile recomputes the estimate in the background with the same answers.
            let before = app.estimate!
            app.setProfile(.learner)
            for _ in 0..<50 where app.estimate == before {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            check(app.estimate != before && app.estimate!.answered == before.answered, "profil changé, estimation recalculée")
            app.setProfile(.native)
            for _ in 0..<50 where app.estimate?.median != before.median {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            check(abs(app.estimate!.median - before.median) < 1, "retour au profil initial")
        }
    }
    errors.sort()
    print(String(format: "Erreur relative médiane après 40 questions : %.1f %%", errors[errors.count / 2] * 100))
    try? FileManager.default.removeItem(at: directory)
}

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Lexicometre/Resources/mots.tsv"
Task { @MainActor in
    await runAll(tsvPath: path)
    print(failures == 0 ? "✅ Toutes les vérifications passent." : "❌ \(failures) vérification(s) en échec.")
    exit(failures == 0 ? 0 : 1)
}
RunLoop.main.run()
