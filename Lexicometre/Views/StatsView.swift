import SwiftUI

struct StatsView: View {
    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LevelCard(xp: model.player.xp)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Évolution de ton vocabulaire")
                        .font(.headline)
                    if model.player.history.count >= 2 {
                        HistoryChart(points: model.player.history)
                    } else if let estimate = model.estimate, estimate.answered >= 10 {
                        Text("≈ \(Format.number(estimate.displayValue)) mots aujourd'hui. Reviens un autre jour pour voir ta courbe se dessiner.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Fais un test pour obtenir ta première estimation.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .card()

                LazyVGrid(columns: columns, spacing: 10) {
                    StatTile(value: Format.number(model.player.seen.count), label: "mots rencontrés", symbol: "eye.fill")
                    StatTile(value: Format.number(model.player.totalAnswered), label: "réponses", symbol: "hand.tap.fill")
                    StatTile(value: Format.percent(model.player.accuracy), label: "de bonnes réponses",
                             symbol: "checkmark.circle.fill", accent: Theme.correct)
                    StatTile(value: "\(model.player.bestStreak)", label: "meilleure série",
                             symbol: "flame.fill", accent: Theme.flame)
                    StatTile(value: "\(model.player.bestDayStreak) j", label: "record de jours d'affilée",
                             symbol: "calendar", accent: Theme.flame)
                    StatTile(value: "\(model.player.chronoBest)", label: "record au chrono",
                             symbol: "stopwatch.fill", accent: .orange)
                    StatTile(value: "\(model.player.testsCompleted)", label: "tests terminés", symbol: "flag.checkered")
                    StatTile(value: "\(model.player.carnet.filter(\.mastered).count)", label: "mots appris au carnet",
                             symbol: "brain.head.profile", accent: Theme.correct)
                }

                if let word = model.rarestKnownWord {
                    NavigationLink(value: word) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Ton mot le plus rare", systemImage: "diamond.fill")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.violet)
                            Text(word.text)
                                .font(Theme.wordFont(size: 26))
                                .foregroundStyle(.primary)
                            Text("Connu par environ \(Format.percent(word.popularity)) des francophones")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .card()
                    }
                    .buttonStyle(PressableStyle())
                }

                BadgeGrid(earned: model.player.badges)
            }
            .padding(16)
            .readableWidth()
        }
        .background(AppBackground())
        .navigationTitle("Statistiques")
    }
}

private struct LevelCard: View {
    let xp: Int

    var body: some View {
        let level = XPLevel.level(for: xp)
        HStack(spacing: 16) {
            ProgressRing(progress: XPLevel.progress(for: xp), lineWidth: 9,
                         style: AnyShapeStyle(Theme.warmGradient)) {
                VStack(spacing: 0) {
                    Text("niv.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(level)")
                        .font(.title2.bold())
                        .monospacedDigit()
                }
            }
            .frame(width: 78, height: 78)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Format.number(xp)) XP")
                    .font(.title3.bold())
                    .monospacedDigit()
                Text("Encore \(Format.number(XPLevel.threshold(of: level + 1) - xp)) XP avant le niveau \(level + 1).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Les mots rares et les longues séries rapportent davantage.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .card()
    }
}

private struct BadgeGrid: View {
    let earned: [String: Date]

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Badges")
                    .font(.headline)
                Spacer()
                Text("\(earned.count)/\(Badge.all.count)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Badge.all) { badge in
                    let unlocked = earned[badge.id] != nil
                    VStack(spacing: 6) {
                        Image(systemName: unlocked ? badge.symbol : "lock.fill")
                            .font(.title2)
                            .foregroundStyle(unlocked ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.secondary))
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(unlocked ? AnyShapeStyle(Theme.warmGradient)
                                                               : AnyShapeStyle(Color.primary.opacity(0.07))))
                        Text(badge.title)
                            .font(.caption.bold())
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(badge.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .opacity(unlocked ? 1 : 0.75)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .card()
    }
}
