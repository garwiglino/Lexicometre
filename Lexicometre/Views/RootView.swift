import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            switch model.loadState {
            case .loading:
                SplashView()
                    .transition(.opacity)
            case .failed(let message):
                ContentUnavailableView("Lexique indisponible", systemImage: "exclamationmark.triangle",
                                       description: Text(message))
            case .ready:
                if model.player.onboarded {
                    HomeView()
                        .transition(.opacity)
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: model.loadState)
        .animation(.easeInOut(duration: 0.35), value: model.player.onboarded)
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 20) {
                AppLogo(size: 96)
                Text("Lexicomètre")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                ProgressView()
            }
        }
    }
}

struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                AppLogo(size: 92)
                    .padding(.top, 30)
                VStack(spacing: 10) {
                    Text("Combien de mots\nconnais-tu ?")
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                    Text("Le Lexicomètre estime ton vocabulaire parmi les \(Format.number(model.bank?.universeSize ?? 43_000)) mots du français courant.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                VStack(alignment: .leading, spacing: 18) {
                    FeatureRow(symbol: "text.magnifyingglass", title: "Un mot, trois définitions",
                               text: "Choisis la bonne. Chaque réponse ajuste la difficulté du mot suivant.")
                    FeatureRow(symbol: "hand.raised.fill", title: "Ne devine pas",
                               text: "« Je ne sais pas » rend l'estimation plus juste et ne casse pas ta série.")
                    FeatureRow(symbol: "chart.line.uptrend.xyaxis", title: "Une mesure qui s'affine",
                               text: "Test, mode libre, défi du jour, contre-la-montre : chaque mot précise ton score.")
                }
                .card(padding: 20)
                VStack(spacing: 12) {
                    Text("Le français, pour toi, c'est…")
                        .font(.headline)
                    Button {
                        model.completeOnboarding(profile: .native)
                    } label: {
                        Label("Ma langue maternelle", systemImage: "house.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button {
                        model.completeOnboarding(profile: .learner)
                    } label: {
                        Label("Une langue que j'apprends", systemImage: "graduationcap.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Text("Cela règle seulement le point de départ de l'algorithme.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .readableWidth(560)
        }
        .background(AppBackground())
    }
}
