import SwiftUI

/// Image shared after a test ("Je connais 31 200 mots").
struct ShareCardView: View {
    let estimate: VocabularyEstimate
    let title: VocabularyTitle

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                AppLogo(size: 36)
                Text("Lexicomètre")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            Spacer(minLength: 0)
            Text("Je connais environ")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.85))
            Text(Format.number(estimate.displayValue))
                .font(.system(size: 66, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
            Text("mots de français")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Label(title.name, systemImage: title.symbol)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(.white.opacity(0.18)))
            Text("soit \(Format.percent(estimate.share)) des \(Format.number(estimate.universe)) mots du lexique")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
            Spacer(minLength: 0)
            Text("Et toi, combien de mots connais-tu ?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(28)
        .frame(width: 360, height: 480)
        .background(Theme.gradient)
    }
}

/// Renders the card and offers it to the share sheet.
struct ShareEstimateButton: View {
    let estimate: VocabularyEstimate
    @State private var image: Image?

    private var message: String {
        "Je connais environ \(Format.number(estimate.displayValue)) mots de français d'après le Lexicomètre. Et toi ?"
    }

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, message: Text(message),
                          preview: SharePreview("Mon vocabulaire", image: image)) {
                    Label("Partager mon score", systemImage: "square.and.arrow.up")
                }
            } else {
                ShareLink(item: message) {
                    Label("Partager mon score", systemImage: "square.and.arrow.up")
                }
            }
        }
        .buttonStyle(SecondaryButtonStyle())
        .task(id: estimate.displayValue) { render() }
    }

    @MainActor
    private func render() {
        let card = ShareCardView(estimate: estimate, title: VocabularyTitle.title(for: estimate.median))
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            image = Image(uiImage: uiImage)
        }
    }
}
