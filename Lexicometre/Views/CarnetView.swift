import SwiftUI

/// Words missed during the games, to review with spaced repetition.
struct CarnetView: View {
    @Environment(AppModel.self) private var model
    @State private var showMastered = false
    @State private var search = ""
    @State private var session: QuizSession?

    private var items: [CarnetItem] {
        let all = model.carnetWords(mastered: showMastered)
        guard !search.isEmpty else { return all }
        let query = TextMatching.fold(search)
        return all.filter { TextMatching.fold($0.word.text).contains(query) }
    }

    var body: some View {
        List {
            Section {
                Picker("Affichage", selection: $showMastered) {
                    Text("À réviser").tag(false)
                    Text("Appris").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if !showMastered {
                Section {
                    let due = model.dueReviewWords.count
                    Button {
                        session = QuizSession(mode: .review, app: model)
                    } label: {
                        Label(due > 0 ? "Réviser \(due) mot\(due > 1 ? "s" : "")" : "Aucune révision due",
                              systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(PrimaryButtonStyle(gradient: Theme.freshGradient))
                    .disabled(due == 0)
                    .opacity(due == 0 ? 0.5 : 1)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } footer: {
                    Text("Un mot réussi revient dans 1, 3 puis 7 jours. Après quatre réussites, il passe dans « Appris ».")
                }
            }

            Section {
                if items.isEmpty {
                    Text(showMastered ? "Aucun mot appris pour l'instant." : "Ton carnet est vide : les mots manqués s'y ajoutent automatiquement.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { item in
                        NavigationLink(value: item.word) {
                            CarnetRow(entry: item.entry, word: item.word)
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { items[$0].id }
                        ids.forEach { model.removeFromCarnet($0) }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Rechercher un mot")
        .navigationTitle("Carnet")
        .fullScreenCover(item: $session) { session in
            QuizView(session: session)
                .environment(model)
        }
    }
}

private struct CarnetRow: View {
    let entry: CarnetEntry
    let word: Word

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(word.text)
                    .font(Theme.wordFont(size: 19))
                Text(word.grammar)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !entry.mastered {
                    HStack(spacing: 3) {
                        ForEach(0..<CarnetEntry.intervals.count, id: \.self) { index in
                            Circle()
                                .fill(index < entry.box ? Theme.correct : Color.primary.opacity(0.12))
                                .frame(width: 7, height: 7)
                        }
                    }
                    .accessibilityLabel("\(entry.box) révision\(entry.box > 1 ? "s" : "") réussie\(entry.box > 1 ? "s" : "")")
                }
            }
            Text(word.definition)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}

struct WordDetailView: View {
    let word: Word
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(word.grammar.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.violet)
                    Text(word.text)
                        .font(Theme.wordFont(size: 40))
                        .minimumScaleFactor(0.5)
                    RarityMeter(popularity: word.popularity)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Définition")
                        .font(.headline)
                    Text(word.definition)
                        .font(.body)
                }
                .card()
                if let example = word.example {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Exemple")
                            .font(.headline)
                        Text(Markdown.attributed(example))
                            .font(.body)
                            .italic()
                    }
                    .card()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label("Connu par environ \(Format.percent(word.popularity)) des francophones", systemImage: "person.3.fill")
                    Label("Rang \(Format.number(word.rank)) sur \(Format.number(model.bank?.universeSize ?? 0)) mots, du plus courant au plus rare",
                          systemImage: "number")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .card()
                if let url = word.wiktionaryURL {
                    Link(destination: url) {
                        Label("Lire l'article du Wiktionnaire", systemImage: "safari")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(16)
            .readableWidth()
        }
        .background(AppBackground())
        .navigationTitle(word.text)
        .navigationBarTitleDisplayMode(.inline)
    }
}
