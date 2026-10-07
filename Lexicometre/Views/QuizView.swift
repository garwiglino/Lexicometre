import SwiftUI

struct QuizView: View {
    let session: QuizSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()
            if session.isFinished {
                SessionSummaryView(session: session) { dismiss() }
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    QuizHeader(session: session, onClose: close)
                    if let question = session.question {
                        QuestionPage(session: session, question: question)
                            .id(question.id)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                    } else {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: session.question?.id)
        .animation(.easeInOut(duration: 0.3), value: session.isFinished)
        .overlay { ToastOverlay() }
        .onAppear { session.start() }
        .task(id: session.phase) { await autoAdvance() }
    }

    private func close() {
        if session.answeredCount == 0 {
            dismiss()
        } else {
            withAnimation { session.finish() }
        }
    }

    /// Against the clock, answers move on by themselves; elsewhere the player reads, then taps "Suivant".
    private func autoAdvance() async {
        guard session.mode == .chrono, session.isAnswered else { return }
        try? await Task.sleep(nanoseconds: 450_000_000)
        guard !Task.isCancelled, session.isAnswered else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { session.next() }
    }
}

// MARK: - Header

private struct QuizHeader: View {
    let session: QuizSession
    let onClose: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
                }
                .accessibilityLabel("Quitter")
                progress
                    .frame(maxWidth: .infinity)
                StreakBadge(count: session.streak, compact: true)
            }
            if session.mode == .test || session.mode == .free, let estimate = model.estimate, estimate.answered >= 5 {
                LiveEstimate(estimate: estimate, start: session.startEstimate)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .readableWidth()
    }

    @ViewBuilder private var progress: some View {
        if session.mode == .chrono {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                let remaining = session.timeRemaining(at: context.date)
                HStack(spacing: 10) {
                    ProgressView(value: remaining, total: QuizSession.chronoDuration)
                        .tint(remaining < 10 ? Theme.wrong : Theme.flame)
                    Text("\(Int(remaining.rounded(.up))) s")
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .foregroundStyle(remaining < 10 ? Theme.wrong : Color.primary)
                }
            }
        } else if let length = session.length {
            HStack(spacing: 10) {
                ProgressView(value: Double(session.answeredCount), total: Double(max(length, 1)))
                    .tint(Theme.violet)
                    .animation(.easeInOut, value: session.answeredCount)
                Text("\(min(session.answeredCount + (session.isAnswered ? 0 : 1), length))/\(length)")
                    .font(.subheadline.bold())
                    .monospacedDigit()
            }
        } else {
            Text("\(session.mode.title) · \(session.answeredCount) mot\(session.answeredCount > 1 ? "s" : "")")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
        }
    }
}

private struct LiveEstimate: View {
    let estimate: VocabularyEstimate
    let start: VocabularyEstimate?

    private var delta: Int {
        guard let start else { return 0 }
        return estimate.displayValue - start.displayValue
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speedometer")
                .foregroundStyle(Theme.violet)
            Text("≈ \(Format.number(estimate.displayValue)) mots")
                .contentTransition(.numericText(value: Double(estimate.displayValue)))
            Text("±\(Format.percent(estimate.precision))")
                .foregroundStyle(.secondary)
            if delta != 0 {
                Text(delta > 0 ? "+\(Format.number(delta))" : "−\(Format.number(-delta))")
                    .foregroundStyle(delta > 0 ? Theme.correct : Theme.wrong)
                    .contentTransition(.numericText(value: Double(delta)))
            }
        }
        .font(.footnote.weight(.semibold))
        .monospacedDigit()
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.violet.opacity(0.1)))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: estimate.displayValue)
    }
}

// MARK: - Question

private struct QuestionPage: View {
    let session: QuizSession
    let question: Question

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    WordCard(word: question.word)
                    VStack(spacing: 10) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                            OptionButton(letter: ["A", "B", "C"][index % 3], text: option, state: state(of: index)) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    session.choose(index)
                                }
                            }
                            // Right under the answer just tapped: the thumb is already there.
                            if session.mode != .chrono, session.answeredChoice == index {
                                NextButton(session: session)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }
                    if let outcome = session.answeredOutcome, session.mode != .chrono {
                        FeedbackPanel(session: session, word: question.word, outcome: outcome)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 20)
                .readableWidth()
            }
            .scrollIndicators(.hidden)
            BottomBar(session: session)
        }
    }

    private func state(of index: Int) -> OptionState {
        guard session.isAnswered else { return .idle }
        if index == question.correctIndex { return .correct }
        if index == session.answeredChoice { return .wrong }
        return .dimmed
    }
}

struct WordCard: View {
    let word: Word

    var body: some View {
        VStack(spacing: 10) {
            Text(word.grammar.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(Theme.violet)
            Text(word.text)
                .font(Theme.wordFont(size: 42))
                .lineLimit(1)
                .minimumScaleFactor(0.35)
                .padding(.horizontal, 8)
            RarityMeter(popularity: word.popularity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

enum OptionState {
    case idle
    case correct
    case wrong
    case dimmed
}

struct OptionButton: View {
    let letter: String
    let text: String
    let state: OptionState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Text(letter)
                    .font(.subheadline.bold())
                    .foregroundStyle(letterTextColor)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(letterFillColor))
                Text(text)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                if state == .correct {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.correct)
                        .transition(.scale.combined(with: .opacity))
                } else if state == .wrong {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.wrong)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(fillColor))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(strokeColor, lineWidth: 2))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(state == .dimmed ? 0.45 : 1)
            .modifier(ShakeEffect(animatableData: state == .wrong ? 1 : 0))
        }
        .buttonStyle(PressableStyle())
        .allowsHitTesting(state == .idle)
        .accessibilityLabel("Réponse \(letter) : \(text)")
    }

    private var fillColor: Color {
        switch state {
        case .correct: Theme.correct.opacity(0.14)
        case .wrong: Theme.wrong.opacity(0.12)
        case .idle, .dimmed: Color(.secondarySystemGroupedBackground)
        }
    }

    private var strokeColor: Color {
        switch state {
        case .correct: Theme.correct
        case .wrong: Theme.wrong
        case .idle: Color.primary.opacity(0.06)
        case .dimmed: Color.clear
        }
    }

    private var letterFillColor: Color {
        switch state {
        case .correct: Theme.correct
        case .wrong: Theme.wrong
        case .idle: Theme.violet.opacity(0.12)
        case .dimmed: Color.primary.opacity(0.06)
        }
    }

    private var letterTextColor: Color {
        switch state {
        case .correct, .wrong: .white
        case .idle: Theme.violet
        case .dimmed: .secondary
        }
    }
}

private struct FeedbackPanel: View {
    let session: QuizSession
    let word: Word
    let outcome: AnswerOutcome

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                Spacer(minLength: 0)
                if session.lastReward > 0 {
                    Text("+\(session.lastReward) XP")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.flame)
                }
            }
            Text(popularityText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if outcome != .correct || session.mode == .review, let example = word.example {
                Text(Markdown.attributed(example))
                    .font(.callout)
                    .italic()
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.violet.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if outcome != .correct, session.mode != .review {
                Label("Ajouté à ton carnet de révision", systemImage: "bookmark.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var title: String {
        switch outcome {
        case .correct:
            if session.streak >= 3 { return "Série de \(session.streak) !" }
            return ["Bravo !", "Exact !", "Bien vu !", "Parfait !"][session.answeredCount % 4]
        case .wrong:
            return "Raté !"
        case .unknown:
            return "Voici la réponse"
        }
    }

    private var symbol: String {
        switch outcome {
        case .correct: session.streak >= 3 ? "flame.fill" : "checkmark.seal.fill"
        case .wrong: "xmark.octagon.fill"
        case .unknown: "lightbulb.fill"
        }
    }

    private var color: Color {
        switch outcome {
        case .correct: session.streak >= 3 ? Theme.flame : Theme.correct
        case .wrong: Theme.wrong
        case .unknown: Color.orange
        }
    }

    private var popularityText: String {
        let share = Format.percent(word.popularity)
        if outcome == .correct, word.popularity < 0.5 {
            return "Seuls \(share) des francophones connaissent ce mot."
        }
        return "Mot connu par environ \(share) des francophones."
    }
}

/// Moves to the next word. It appears where the thumb just tapped.
private struct NextButton: View {
    let session: QuizSession

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { session.next() }
        } label: {
            HStack(spacing: 8) {
                Text(session.isLastQuestion ? "Voir le résultat" : "Suivant")
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}

private struct BottomBar: View {
    let session: QuizSession

    /// "Je ne sais pas" was tapped: "Suivant" takes its place, under the thumb.
    private var showsNext: Bool {
        session.isAnswered && session.mode != .chrono && session.answeredChoice == nil
    }

    var body: some View {
        // After tapping a definition, "Suivant" sits under it and this bar steps aside.
        if !session.isAnswered || session.mode == .chrono || showsNext {
            VStack(spacing: 0) {
                Divider().opacity(0.5)
                Group {
                    if showsNext {
                        NextButton(session: session)
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { session.dontKnow() }
                        } label: {
                            Label("Je ne sais pas", systemImage: "questionmark.circle")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(session.isAnswered)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .readableWidth()
            }
            .background(.bar)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
