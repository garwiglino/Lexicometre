import SwiftUI

enum HomeRoute: Hashable {
    case stats
    case carnet
    case settings
    case about
}

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var session: QuizSession?
    @State private var showDailyResult = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HeroCard(onTest: { start(.test) }, onFree: { start(.free) })

                    HStack(spacing: 12) {
                        DailyCard(result: model.todaysDailyResult) {
                            if model.todaysDailyResult == nil {
                                start(.daily)
                            } else {
                                showDailyResult = true
                            }
                        }
                        GoalCard(count: model.todayCount, goal: model.player.settings.dailyGoal)
                    }

                    SectionTitle(text: "Jouer")
                    ModeRow(title: GameMode.free.title,
                            subtitle: "Des mots à l'infini, ton score s'affine",
                            symbol: "infinity", gradient: Theme.gradient) { start(.free) }
                    ModeRow(title: GameMode.chrono.title,
                            subtitle: model.player.chronoBest > 0
                                ? "60 secondes · record \(model.player.chronoBest)" : "60 secondes, un max de mots",
                            symbol: "stopwatch.fill", gradient: Theme.warmGradient) { start(.chrono) }
                    let due = model.dueReviewWords.count
                    ModeRow(title: GameMode.review.title,
                            subtitle: due > 0 ? "\(due) mot\(due > 1 ? "s" : "") à revoir" : "Rien à revoir pour l'instant",
                            symbol: "arrow.triangle.2.circlepath", gradient: Theme.freshGradient,
                            badgeText: due > 0 ? "\(due)" : nil, isDisabled: due == 0) { start(.review) }

                    if let word = model.wordOfTheDay {
                        WordOfTheDayCard(word: word)
                    }

                    SectionTitle(text: "Progression")
                    HStack(spacing: 12) {
                        NavigationLink(value: HomeRoute.stats) {
                            ShortcutTile(title: "Statistiques", detail: "Niveau \(XPLevel.level(for: model.player.xp))",
                                         symbol: "chart.bar.fill")
                        }
                        NavigationLink(value: HomeRoute.carnet) {
                            ShortcutTile(title: "Carnet", detail: "\(model.player.carnet.count) mot\(model.player.carnet.count > 1 ? "s" : "")",
                                         symbol: "bookmark.fill")
                        }
                    }
                    .buttonStyle(PressableStyle())

                    NavigationLink(value: HomeRoute.about) {
                        Label("Comment est calculé mon score ?", systemImage: "info.circle")
                            .font(.footnote)
                    }
                    .padding(.top, 8)
                    Text("Définitions : Wiktionnaire · Fréquences : Lexique 3.83")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                .readableWidth()
            }
            .background(AppBackground())
            .navigationTitle("Lexicomètre")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    StreakBadge(count: model.currentDayStreak, compact: true)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: HomeRoute.settings) {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Réglages")
                }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .stats: StatsView()
                case .carnet: CarnetView()
                case .settings: SettingsView()
                case .about: AboutView()
                }
            }
            .navigationDestination(for: Word.self) { word in
                WordDetailView(word: word)
            }
        }
        .tint(Theme.violet)
        .overlay { ToastOverlay() }
        .fullScreenCover(item: $session) { session in
            QuizView(session: session)
                .environment(model)
        }
        .sheet(isPresented: $showDailyResult) {
            DailyResultSheet()
                .environment(model)
        }
    }

    private func start(_ mode: GameMode) {
        Haptics.tap()
        session = QuizSession(mode: mode, app: model)
    }
}

private struct HeroCard: View {
    @Environment(AppModel.self) private var model
    let onTest: () -> Void
    let onFree: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let estimate = model.estimate, estimate.answered >= 10 {
                Text("TON VOCABULAIRE")
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.8))
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Format.number(estimate.displayValue))
                        .font(.system(size: 54, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText(value: Double(estimate.displayValue)))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("mots")
                        .font(.title2.weight(.semibold))
                        .opacity(0.9)
                }
                .foregroundStyle(.white)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: estimate.displayValue)
                Text("\(Format.percent(estimate.share)) des \(Format.number(estimate.universe)) mots du français courant")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                HStack(spacing: 8) {
                    if let title = model.vocabularyTitle {
                        Label(title.name, systemImage: title.symbol)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(.white.opacity(0.2)))
                    }
                    Spacer(minLength: 0)
                    Label("±\(Format.percent(estimate.precision))", systemImage: "scope")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(.white.opacity(0.14)))
                }
                .foregroundStyle(.white)
                HStack(spacing: 10) {
                    Button(action: onTest) {
                        Label("Nouveau test", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(OnGradientButtonStyle(filled: false))
                    Button(action: onFree) {
                        Label("Affiner", systemImage: "scope")
                    }
                    .buttonStyle(OnGradientButtonStyle(filled: true))
                }
                .padding(.top, 4)
            } else {
                Text("Combien de mots connais-tu ?")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text("Un test adaptatif de \(QuizSession.testLength) mots, environ 5 minutes. Ton score s'affine ensuite à chaque partie.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                Button(action: onTest) {
                    Label("Commencer le test", systemImage: "play.fill")
                }
                .buttonStyle(OnGradientButtonStyle(filled: true))
                .padding(.top, 4)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Theme.violet.opacity(0.3), radius: 18, y: 8)
    }
}

private struct DailyCard: View {
    let result: DailyResult?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(Theme.flame)
                    Spacer()
                    if result != nil {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Theme.correct)
                    }
                }
                .font(.title3)
                Spacer(minLength: 0)
                Text("Défi du jour")
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let result {
                    Text("\(result.score)/\(DailyChallenge.length) · Partager")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(result.emojiLine)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else {
                    Text("\(DailyChallenge.length) mots · 1 min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

private struct GoalCard: View {
    let count: Int
    let goal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressRing(progress: Double(count) / Double(max(goal, 1)), lineWidth: 6,
                         style: AnyShapeStyle(Theme.warmGradient)) {
                Image(systemName: count >= goal ? "checkmark" : "target")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.flame)
            }
            .frame(width: 34, height: 34)
            Spacer(minLength: 0)
            Text("Objectif")
                .font(.headline)
            Text("\(min(count, goal))/\(goal) mots aujourd'hui")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ModeRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let gradient: LinearGradient
    var badgeText: String? = nil
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if let badgeText {
                    Text(badgeText)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.flame))
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .opacity(isDisabled ? 0.55 : 1)
        }
        .buttonStyle(PressableStyle())
        .disabled(isDisabled)
    }
}

private struct WordOfTheDayCard: View {
    @Environment(AppModel.self) private var model
    let word: Word

    var body: some View {
        NavigationLink(value: word) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Mot du jour", systemImage: "sparkles")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.violet)
                    Spacer()
                    Text(word.grammar)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(word.text)
                    .font(Theme.wordFont(size: 28))
                    .foregroundStyle(.primary)
                Text(word.definition)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .card()
        }
        .buttonStyle(PressableStyle())
        .onAppear { model.markSeen(word) }
    }
}

private struct ShortcutTile: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.violet)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Today's challenge: score, grid and sharing.
struct DailyResultSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if let result = model.todaysDailyResult {
                    DailyResultContent(result: result)
                } else {
                    ContentUnavailableView("Pas encore joué", systemImage: "calendar",
                                           description: Text("Le défi du jour t'attend."))
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle("Défi du jour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct DailyResultContent: View {
    let result: DailyResult

    private var comment: String {
        switch result.score {
        case 10: "Parfait ! Un sans-faute."
        case 8...9: "Superbe score !"
        case 6...7: "Très bien joué."
        case 4...5: "Pas mal du tout."
        default: "Les mots rares se méritent !"
        }
    }

    private var shareText: String {
        let date = Format.day(Date())
        return "Lexicomètre · Défi du \(date)\n\(result.emojiLine)\n\(result.score)/\(DailyChallenge.length)"
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("\(result.score)/\(DailyChallenge.length)")
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.gradient)
            Text(result.emojiLine)
                .font(.title2)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(comment)
                .font(.headline)
            ShareLink(item: shareText) {
                Label("Partager mon résultat", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PrimaryButtonStyle())
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text("Prochain défi dans \(Self.countdown(from: context.date))")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    static func countdown(from date: Date) -> String {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        let seconds = max(0, Int(tomorrow.timeIntervalSince(date)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
    }
}
