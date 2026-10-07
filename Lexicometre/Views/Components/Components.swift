import SwiftUI

struct AppLogo: View {
    var size: CGFloat = 80

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(Theme.gradient)
            Text("Aa")
                .font(.system(size: size * 0.44, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .offset(y: -size * 0.04)
            Capsule()
                .fill(.white.opacity(0.85))
                .frame(width: size * 0.46, height: size * 0.06)
                .offset(y: size * 0.28)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.violet.opacity(0.35), radius: size * 0.12, y: size * 0.05)
        .accessibilityHidden(true)
    }
}

struct ProgressRing<Content: View>: View {
    var progress: Double
    var lineWidth: CGFloat = 10
    var style: AnyShapeStyle = AnyShapeStyle(Theme.gradient)
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(style, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            content
        }
    }
}

/// Day streak (home) or answer streak (quiz).
struct StreakBadge: View {
    let count: Int
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: count > 0 ? "flame.fill" : "flame")
                .foregroundStyle(count > 0 ? AnyShapeStyle(Theme.warmGradient) : AnyShapeStyle(Color.secondary))
                .symbolEffect(.bounce, value: count)
            Text("\(count)")
                .font(compact ? .subheadline.bold() : .headline)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(count)))
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 6 : 8)
        .background(Capsule().fill(Theme.flame.opacity(count > 0 ? 0.15 : 0.06)))
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: count)
    }
}

/// Five bars: how rare a word is.
struct RarityMeter: View {
    let popularity: Double

    private var level: Int {
        switch popularity {
        case 0.9...: 1
        case 0.7..<0.9: 2
        case 0.5..<0.7: 3
        case 0.25..<0.5: 4
        default: 5
        }
    }

    private var label: String {
        ["Très courant", "Courant", "Soutenu", "Rare", "Très rare"][level - 1]
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(1...5, id: \.self) { index in
                    Capsule()
                        .fill(index <= level ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color.primary.opacity(0.1)))
                        .frame(width: 14, height: 5)
                }
            }
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rareté : \(label)")
    }
}

/// A number that counts up when its value is animated.
struct CountingText: View, Animatable {
    var value: Double
    var font: Font

    nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(Format.number(Int(value.rounded())))
            .font(font)
            .monospacedDigit()
    }
}

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 9
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * 6), y: 0))
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    var accent: Color = Theme.violet

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(accent)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct FeatureRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.violet)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title3.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}

/// Banners for badges and goals, shown on top of the screen.
struct ToastOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack {
            if let toast = model.toasts.first {
                HStack(spacing: 12) {
                    Image(systemName: toast.symbol)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.warmGradient))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(toast.title).font(.subheadline.bold())
                        Text(toast.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { dismiss(toast) }
                .task(id: toast.id) {
                    try? await Task.sleep(nanoseconds: 2_800_000_000)
                    dismiss(toast)
                }
            }
            Spacer()
        }
        .padding(.top, 6)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: model.toasts.first?.id)
    }

    private func dismiss(_ toast: Toast) {
        if model.toasts.first?.id == toast.id {
            model.toasts.removeFirst()
        }
    }
}
