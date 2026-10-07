import SwiftUI

enum Theme {
    static let violet = Color(red: 0.42, green: 0.32, blue: 0.95)
    static let magenta = Color(red: 0.74, green: 0.29, blue: 0.86)
    static let flame = Color(red: 1.0, green: 0.48, blue: 0.16)
    static let correct = Color(red: 0.16, green: 0.72, blue: 0.40)
    static let wrong = Color(red: 0.93, green: 0.26, blue: 0.30)

    static let gradient = LinearGradient(colors: [violet, magenta],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
    static let warmGradient = LinearGradient(colors: [Color(red: 1.0, green: 0.62, blue: 0.20), Color(red: 0.96, green: 0.30, blue: 0.42)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let freshGradient = LinearGradient(colors: [Color(red: 0.15, green: 0.70, blue: 0.62), Color(red: 0.20, green: 0.48, blue: 0.92)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing)

    static func wordFont(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }
}

enum Format {
    static let french = Locale(identifier: "fr_FR")

    /// "31 200"
    static func number(_ value: Int) -> String {
        value.formatted(.number.locale(french))
    }

    /// "72 %"
    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))\u{202F}%"
    }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(french))
    }
}

enum Markdown {
    /// Renders the **bold** of the examples.
    static func attributed(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            LinearGradient(colors: [Theme.violet.opacity(0.14), Theme.magenta.opacity(0.04), .clear],
                           startPoint: .top, endPoint: .center)
        }
        .ignoresSafeArea()
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }

    /// Keeps lines readable on iPad.
    func readableWidth(_ width: CGFloat = 640) -> some View {
        frame(maxWidth: width)
            .frame(maxWidth: .infinity)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = Theme.gradient

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Theme.violet.opacity(0.25), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.violet)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(Theme.violet.opacity(configuration.isPressed ? 0.2 : 0.12),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Buttons drawn on the violet gradient.
struct OnGradientButtonStyle: ButtonStyle {
    var filled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(filled ? Theme.violet : .white)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(filled ? Color.white : Color.white.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Shrinks a little under the finger.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
