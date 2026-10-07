import SwiftUI

/// End of a game.
struct SessionSummaryView: View {
    let session: QuizSession
    let onDone: () -> Void
    @Environment(AppModel.self) private var model
    @State private var confetti = false

    private var shouldCelebrate: Bool {
        switch session.mode {
        case .test: session.isLastQuestion
        case .daily: session.correctCount >= 8
        case .chrono: session.isNewChronoRecord && session.correctCount > 0
        case .free, .review: session.answeredCount >= 10 && session.correctCount * 10 >= session.answeredCount * 7
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                switch session.mode {
                case .test, .free:
                    EstimateSummary(session: session)
                case .daily:
                    if let result = model.todaysDailyResult, session.isLastQuestion {
                        DailyResultContent(result: result)
                            .card(padding: 22)
                    } else {
                        InfoCard(symbol: "calendar.badge.exclamationmark", title: "Défi interrompu",
                                 text: "Termine les \(DailyChallenge.length) mots pour enregistrer ton score du jour.")
                    }
                case .chrono:
                    ChronoSummary(session: session)
                case .review:
                    ReviewSummary(session: session)
                }

                SessionNumbers(session: session)

                if let word = session.rarestKnown, word.popularity < 0.6 {
                    RareWordCard(word: word)
                }
                if !session.missedWords.isEmpty, session.mode != .review {
                    MissedWordsCard(words: session.missedWords)
                }

                Button(action: onDone) {
                    Text("Terminer")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
            }
            .padding(18)
            .readableWidth()
        }
        .scrollIndicators(.hidden)
        .overlay {
            if confetti { ConfettiView() }
        }
        .task {
            guard shouldCelebrate else { return }
            confetti = true
            Haptics.celebrate()
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            confetti = false
        }
    }
}

private struct EstimateSummary: View {
    let session: QuizSession
    @Environment(AppModel.self) private var model
    @State private var shown = 0.0
    @State private var curve: [AppModel.CurvePoint] = []

    var body: some View {
        if let estimate = model.estimate {
            VStack(spacing: 16) {
                EstimateHero(estimate: estimate, start: session.startEstimate,
                             isTest: session.mode == .test, shown: shown)
                TitleCard(title: VocabularyTitle.title(for: estimate.median))
                LexiconShareCard(estimate: estimate)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Repères")
                        .font(.headline)
                    BenchmarkScale(value: estimate.median, universe: estimate.universe)
                }
                .card()
                if !curve.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ta connaissance selon la rareté des mots")
                            .font(.headline)
                        KnowledgeChart(points: curve, universe: estimate.universe)
                    }
                    .card()
                }
                ShareEstimateButton(estimate: estimate)
                if estimate.precision > 0.06 {
                    Text("Précision actuelle : ±\(Format.percent(estimate.precision)). Chaque mot joué en mode libre ou au défi du jour l'affine.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .onAppear {
                curve = model.knowledgeCurve()
                withAnimation(.easeOut(duration: 1.8)) {
                    shown = Double(estimate.displayValue)
                }
            }
        } else {
            InfoCard(symbol: "hourglass", title: "Encore quelques mots",
                     text: "Réponds à quelques questions de plus pour obtenir une estimation.")
        }
    }
}

private struct EstimateHero: View {
    let estimate: VocabularyEstimate
    let start: VocabularyEstimate?
    let isTest: Bool
    let shown: Double

    private var deltaText: String? {
        guard let start, start.answered >= 10 else { return nil }
        let delta = estimate.displayValue - start.displayValue
        if delta == 0 { return nil }
        let amount = Format.number(abs(delta))
        return delta > 0 ? "+\(amount) par rapport au début de la partie" : "−\(amount) par rapport au début de la partie"
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(isTest ? "Résultat du test" : "Ton estimation")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.75))
            Text("Tu connais environ")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
            CountingText(value: shown, font: .system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("mots de français")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("entre \(Format.number(estimate.displayLow)) et \(Format.number(estimate.displayHigh)) (80 % de confiance)")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            if let deltaText {
                Text(deltaText)
                    .font(.footnote.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.18)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Theme.violet.opacity(0.3), radius: 16, y: 8)
    }
}

private struct TitleCard: View {
    let title: VocabularyTitle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: title.symbol)
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Theme.warmGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.name)
                        .font(.title3.bold())
                    Text(title.blurb)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let next = VocabularyTitle.next(after: title) {
                Text("Prochain titre : \(next.name), à partir de \(Format.number(next.minimum)) mots.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

private struct LexiconShareCard: View {
    let estimate: VocabularyEstimate

    var body: some View {
        HStack(spacing: 16) {
            ProgressRing(progress: estimate.share, lineWidth: 11) {
                Text(Format.percent(estimate.share))
                    .font(.headline.bold())
                    .monospacedDigit()
            }
            .frame(width: 84, height: 84)
            VStack(alignment: .leading, spacing: 4) {
                Text("du lexique français")
                    .font(.headline)
                Text("\(Format.number(estimate.displayValue)) mots sur les \(Format.number(estimate.universe)) que compte notre lexique de référence.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

private struct ChronoSummary: View {
    let session: QuizSession
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "stopwatch.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.warmGradient)
            Text("\(session.correctCount)")
                .font(.system(size: 76, weight: .heavy, design: .rounded))
                .monospacedDigit()
            Text(session.correctCount > 1 ? "bonnes réponses en 60 secondes" : "bonne réponse en 60 secondes")
                .font(.headline)
            if session.isNewChronoRecord {
                Label("Nouveau record !", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.flame)
                    .padding(.top, 4)
            } else {
                Text("Record : \(model.player.chronoBest)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .card(padding: 24)
    }
}

private struct ReviewSummary: View {
    let session: QuizSession

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 38))
                .foregroundStyle(Theme.freshGradient)
            Text("\(session.correctCount)/\(session.answeredCount)")
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .monospacedDigit()
            Text("mots retrouvés")
                .font(.headline)
            Text("Un mot réussi revient dans 1, 3 puis 7 jours. Après quatre réussites, il est appris.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 24)
    }
}

private struct SessionNumbers: View {
    let session: QuizSession
    @Environment(AppModel.self) private var model

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatTile(value: "\(session.correctCount)", label: "justes",
                     symbol: "checkmark.circle.fill", accent: Theme.correct)
            StatTile(value: "\(session.wrongCount)", label: "erreurs",
                     symbol: "xmark.circle.fill", accent: Theme.wrong)
            StatTile(value: "\(session.unknownCount)", label: "je ne sais pas",
                     symbol: "questionmark.circle.fill", accent: .orange)
            StatTile(value: "\(session.bestStreak)", label: "meilleure série",
                     symbol: "flame.fill", accent: Theme.flame)
            StatTile(value: "+\(session.xpGained)", label: "XP gagnés",
                     symbol: "star.fill", accent: .yellow)
            StatTile(value: "\(XPLevel.level(for: model.player.xp))", label: "niveau",
                     symbol: "chart.bar.fill")
        }
    }
}

private struct RareWordCard: View {
    let word: Word

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ton mot le plus rare", systemImage: "sparkles")
                .font(.caption.bold())
                .foregroundStyle(Theme.violet)
            Text(word.text)
                .font(Theme.wordFont(size: 28))
            Text(word.definition)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Connu par environ \(Format.percent(word.popularity)) des francophones.")
                .font(.footnote.bold())
                .foregroundStyle(Theme.flame)
        }
        .card()
    }
}

private struct MissedWordsCard: View {
    let words: [Word]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("À retenir")
                    .font(.headline)
                Spacer()
                Label("Dans ton carnet", systemImage: "bookmark.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(words.prefix(12)) { word in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(word.text)
                            .font(Theme.wordFont(size: 19))
                        Text(word.grammar)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(word.definition)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .card()
    }
}

struct InfoCard: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 36))
                .foregroundStyle(Theme.violet)
            Text(title)
                .font(.title3.bold())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 24)
    }
}

/// The player's score among indicative landmarks.
struct BenchmarkScale: View {
    let value: Double
    let universe: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 10)
                    Capsule()
                        .fill(Theme.gradient)
                        .frame(width: max(10, width * fraction(value)), height: 10)
                    ForEach(Benchmark.all) { benchmark in
                        Capsule()
                            .fill(Color.primary.opacity(0.3))
                            .frame(width: 2, height: 18)
                            .offset(x: width * fraction(Double(benchmark.value)) - 1)
                    }
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Theme.violet, lineWidth: 4))
                        .offset(x: width * fraction(value) - 9)
                }
                .frame(height: 22)
            }
            .frame(height: 22)
            ForEach(Benchmark.all) { benchmark in
                let reached = value >= Double(benchmark.value)
                HStack {
                    Image(systemName: reached ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(reached ? Theme.correct : Color.secondary)
                    Text(benchmark.label)
                    Spacer()
                    Text("≈ \(Format.number(benchmark.value))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
            Text("Repères indicatifs, sur la même échelle que ton score.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func fraction(_ amount: Double) -> CGFloat {
        CGFloat(min(max(amount / Double(max(universe, 1)), 0), 1))
    }
}
