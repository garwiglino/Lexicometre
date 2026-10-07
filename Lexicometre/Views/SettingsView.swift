import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var profile: Binding<Profile> {
        Binding(get: { model.player.profile }, set: { model.setProfile($0) })
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: model.player.settings.reminderHour,
                                      minute: model.player.settings.reminderMinute,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                model.player.settings.reminderHour = parts.hour ?? 19
                model.player.settings.reminderMinute = parts.minute ?? 0
            })
    }

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Picker("Le français est", selection: profile) {
                    Text("Ma langue maternelle").tag(Profile.native)
                    Text("Une langue que j'apprends").tag(Profile.learner)
                    Text("Non précisé").tag(Profile.unspecified)
                }
            } header: {
                Text("Profil")
            } footer: {
                Text("Règle le point de départ de l'estimation. Tes réponses sont conservées.")
            }

            Section {
                Toggle("Vibrations", isOn: $model.player.settings.haptics)
                Picker("Objectif quotidien", selection: $model.player.settings.dailyGoal) {
                    ForEach([10, 20, 30, 50, 100], id: \.self) { goal in
                        Text("\(goal) mots").tag(goal)
                    }
                }
            } header: {
                Text("Jeu")
            }

            Section {
                Toggle("Rappel quotidien", isOn: $model.player.settings.reminder)
                if model.player.settings.reminder {
                    DatePicker("Heure du rappel", selection: reminderTime, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Un rappel par jour pour garder ta série et ne pas rater le défi du jour.")
            }

            Section {
                NavigationLink(value: HomeRoute.about) {
                    Label("Comment est calculé mon score ?", systemImage: "info.circle")
                }
                if let url = URL(string: "https://fr.wiktionary.org") {
                    Link(destination: url) {
                        Label("Wiktionnaire, le dictionnaire libre", systemImage: "book")
                    }
                }
            } header: {
                Text("À propos")
            }

            Section {
                Button("Réinitialiser ma progression", role: .destructive) {
                    confirmReset = true
                }
            } footer: {
                Text("Lexicomètre \(version)")
            }
        }
        .navigationTitle("Réglages")
        .onChange(of: model.player.settings) { oldValue, newValue in
            model.settingsChanged()
            if oldValue.reminder != newValue.reminder
                || oldValue.reminderHour != newValue.reminderHour
                || oldValue.reminderMinute != newValue.reminderMinute {
                Task { await model.updateReminder() }
            }
        }
        .confirmationDialog("Effacer toute ta progression ?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Tout effacer", role: .destructive) {
                model.resetProgress()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Score, historique, carnet, badges et séries seront supprimés.")
        }
        .alert("Notifications refusées", isPresented: $model.reminderDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Autorise les notifications de Lexicomètre dans les Réglages de l'iPhone pour recevoir le rappel.")
        }
    }
}

struct AboutView: View {
    @Environment(AppModel.self) private var model

    private var universe: String {
        Format.number(model.bank?.universeSize ?? 43_315)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AboutSection(symbol: "books.vertical.fill", title: "Le lexique",
                             text: "Le score porte sur \(universe) mots : les lemmes de la base Lexique 3.83, dont les fréquences sont mesurées dans des livres et des sous-titres de films, qui possèdent un article dans le Wiktionnaire. Noms propres et formes conjuguées sont exclus : « manger », « mangeait » et « mangé » comptent pour un seul mot.")
                AboutSection(symbol: "chart.bar.xaxis", title: "La difficulté des mots",
                             text: "Chaque mot reçoit une difficulté calculée à partir de sa fréquence et, pour plus de 30 000 d'entre eux, du pourcentage de francophones qui en connaissent le sens (normes de connaissance de Lexique).")
                AboutSection(symbol: "function", title: "L'algorithme",
                             text: "À chaque réponse, un modèle statistique issu de la psychométrie (théorie de la réponse à l'item) met à jour trois choses : ton niveau, la pente de ta courbe de connaissance et ta tendance à deviner. Le mot suivant est choisi là où ta réponse sera la plus instructive. Ton score est la somme, sur les \(universe) mots, de la probabilité que tu connaisses chacun d'eux.")
                AboutSection(symbol: "hand.raised.fill", title: "Pourquoi « Je ne sais pas » ?",
                             text: "Avec trois définitions, on tombe juste une fois sur trois au hasard. L'algorithme en tient compte, mais une réponse honnête est bien plus informative. Elle ne casse d'ailleurs pas ta série.")
                AboutSection(symbol: "scope", title: "La précision",
                             text: "L'intervalle affiché contient ton score réel avec 80 % de confiance. Il se resserre avec chaque mot joué en test, en mode libre ou au défi du jour. Le contre-la-montre et les révisions ne comptent pas : la pression du temps et les mots déjà vus fausseraient la mesure.")
                AboutSection(symbol: "c.circle", title: "Sources et licences",
                             text: "Définitions et exemples : Wiktionnaire (ses contributeurs, licence CC BY-SA), via l'export du Dictionnaire des francophones. Fréquences et normes de connaissance : Lexique 3.83 (Boris New, Christophe Pallier et coll., licence CC BY-SA 4.0). Les données de l'application sont partagées sous la même licence.")
            }
            .padding(16)
            .readableWidth()
        }
        .background(AppBackground())
        .navigationTitle("Comment ça marche")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AboutSection: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(Theme.violet)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }
}
