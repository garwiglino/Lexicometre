import SwiftUI

/// A burst of falling confetti, drawn with Canvas.
struct ConfettiView: View {
    private struct Piece {
        let x: Double
        let delay: Double
        let speed: Double
        let drift: Double
        let wobble: Double
        let spin: Double
        let width: Double
        let height: Double
        let color: Color
    }

    @State private var start = Date()
    @State private var pieces: [Piece] = ConfettiView.makePieces(count: 110)

    private static let palette: [Color] = [Theme.violet, Theme.magenta, Theme.flame, Theme.correct,
                                           Color(red: 0.98, green: 0.80, blue: 0.20), Color(red: 0.25, green: 0.60, blue: 0.98)]

    private static func makePieces(count: Int) -> [Piece] {
        (0..<count).map { _ in
            Piece(x: .random(in: 0...1),
                  delay: .random(in: 0...0.6),
                  speed: .random(in: 0.55...1.1),
                  drift: .random(in: -40...40),
                  wobble: .random(in: 2...5),
                  spin: .random(in: -6...6),
                  width: .random(in: 6...10),
                  height: .random(in: 9...15),
                  color: palette.randomElement() ?? Theme.violet)
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let y = -20 + t * piece.speed * size.height * 0.55
                    guard y < size.height + 20 else { continue }
                    let x = piece.x * size.width + sin(t * piece.wobble) * 18 + piece.drift * t
                    let fade = max(0, min(1, 3.2 - t))
                    var pieceContext = context
                    pieceContext.translateBy(x: x, y: y)
                    pieceContext.rotate(by: .radians(t * piece.spin))
                    pieceContext.opacity = fade
                    let rect = CGRect(x: -piece.width / 2, y: -piece.height / 2, width: piece.width, height: piece.height)
                    pieceContext.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
