import Charts
import SwiftUI

/// Probability of knowing a word according to its rank: the player vs. an average French speaker.
struct KnowledgeChart: View {
    let points: [AppModel.CurvePoint]
    let universe: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Chart {
                ForEach(points) { point in
                    LineMark(x: .value("Rang", Double(point.rank)),
                             y: .value("Connaissance", point.average),
                             series: .value("Courbe", "Moyenne"))
                        .foregroundStyle(Color.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        .interpolationMethod(.monotone)
                }
                ForEach(points) { point in
                    LineMark(x: .value("Rang", Double(point.rank)),
                             y: .value("Connaissance", point.player),
                             series: .value("Courbe", "Toi"))
                        .foregroundStyle(Theme.violet)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .interpolationMethod(.monotone)
                }
            }
            .chartYScale(domain: 0...1)
            .chartXScale(domain: 0...Double(universe))
            .chartYAxis {
                AxisMarks(values: [0, 0.25, 0.5, 0.75, 1]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let share = value.as(Double.self) {
                            Text(Format.percent(share))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: 10_000)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let rank = value.as(Double.self) {
                            Text(rank == 0 ? "0" : "\(Int(rank / 1_000)) k")
                        }
                    }
                }
            }
            .frame(height: 190)

            HStack(spacing: 16) {
                legend(color: Theme.violet, dashed: false, text: "Toi")
                legend(color: .secondary, dashed: true, text: "Francophone moyen")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("Axe horizontal : mots du plus courant au plus rare.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func legend(color: Color, dashed: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .stroke(color, style: StrokeStyle(lineWidth: 3, dash: dashed ? [4, 3] : []))
                .frame(width: 22, height: 3)
            Text(text)
        }
    }
}

/// Estimated vocabulary over time.
struct HistoryChart: View {
    let points: [EstimatePoint]

    var body: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(x: .value("Date", point.date, unit: .day),
                         yStart: .value("Bas", point.low),
                         yEnd: .value("Haut", point.high))
                    .foregroundStyle(Theme.violet.opacity(0.15))
            }
            ForEach(points) { point in
                LineMark(x: .value("Date", point.date, unit: .day),
                         y: .value("Mots", point.median))
                    .foregroundStyle(Theme.violet)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                PointMark(x: .value("Date", point.date, unit: .day),
                          y: .value("Mots", point.median))
                    .foregroundStyle(Theme.violet)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let words = value.as(Double.self) {
                        Text(Format.number(Int(words)))
                    }
                }
            }
        }
        .frame(height: 180)
    }
}
