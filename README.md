# Lexicomètre

**Combien de mots de français connais-tu ?** Un mot s'affiche, tu choisis sa définition parmi trois.
Un algorithme adaptatif estime, au fil des réponses, combien de mots tu connais parmi les
**43 315 mots du français courant**.

App iOS native en SwiftUI (iPhone et iPad, iOS 17 ou plus), 100 % hors ligne, en français.

## Fonctionnalités

- **Test complet** : 40 mots adaptatifs (environ 5 minutes). Résultat : nombre de mots connus,
  intervalle de confiance, part du lexique, titre (de « Graine de mots » à « Immortel »),
  repères (apprenant, collégien, adulte, étudiant…), courbe de connaissance selon la rareté,
  image de score à partager.
- **Mode libre** : des mots à l'infini, l'estimation s'affine en direct (affichée en haut de l'écran).
- **Défi du jour** : 10 mots, du plus courant au plus rare, identiques pour tout le monde ce jour-là,
  résultat partageable façon Wordle (🟩🟥⬜️).
- **Contre-la-montre** : 60 secondes pour enchaîner un maximum de bonnes réponses, avec record.
- **Carnet et révisions** : chaque mot manqué rejoint le carnet. Révision espacée (1, 3 puis
  7 jours) ; un mot est « appris » après quatre réussites.
- **Motivation** : séries de bonnes réponses (un « Je ne sais pas » honnête ne casse pas la série),
  jours d'affilée, objectif quotidien, XP et niveaux (les mots rares rapportent plus), 17 badges,
  mot du jour, rappel quotidien par notification, confettis et retours haptiques.
- Fiche de chaque mot : définition, exemple, rareté (« connu par 34 % des francophones »),
  lien vers le Wiktionnaire.

## Lancer l'app

Il faut un **Mac avec Xcode 16 ou plus récent** (gratuit sur le Mac App Store).

1. Ouvre `Lexicometre.xcodeproj`.
2. Choisis un simulateur (par exemple iPhone 16) puis lance avec **⌘R**.

Sur ton iPhone :

1. Branche l'iPhone et sélectionne-le comme destination dans Xcode.
2. Dans la cible *Lexicometre* → *Signing & Capabilities*, choisis ton équipe (un identifiant
   Apple gratuit suffit). Si Xcode refuse l'identifiant `fr.lexicometre.app`, remplace-le par un
   identifiant à toi (par exemple `fr.tonnom.lexicometre`).
3. ⌘R. Avec un compte gratuit, autorise le développeur sur l'iPhone (*Réglages → Général →
   VPN et gestion de l'appareil*). L'app doit alors être réinstallée tous les 7 jours ; un compte
   développeur payant lève cette limite et permet la publication (TestFlight, App Store).

Avec Xcode 15, régénère le projet avec [XcodeGen](https://github.com/yonaskolb/XcodeGen) :
`brew install xcodegen && xcodegen` (fichier `project.yml`).

## Version web

Le dossier `web/` contient un aperçu jouable dans le navigateur (test, mode libre, défi du jour,
contre-la-montre), avec le même lexique et le même algorithme. Pour l'héberger, place
`index.html`, `lexicore.js` et une copie de `Lexicometre/Resources/mots.tsv` renommée `mots.txt`
dans un même dossier servi en HTTP (par exemple `python3 -m http.server`).

## Comment le score est calculé

1. **Le lexique.** Les 43 315 lemmes de la base [Lexique 3.83](http://www.lexique.org)
   (fréquences mesurées dans des livres et des sous-titres de films) qui ont un article dans le
   Wiktionnaire. Les formes conjuguées ou accordées ne comptent pas à part : « manger »,
   « mangeait » et « mangé » sont un seul mot. Les noms propres sont exclus.
2. **La difficulté de chaque mot.** Elle combine la fréquence du mot et, pour plus de
   30 000 mots, les normes de Lexique : le pourcentage de francophones qui savent le définir.
3. **Le modèle.** L'app suit un modèle de réponse à l'item (psychométrie) :
   P(connaître un mot) = σ(a·(θ − difficulté)). Elle estime sur une grille bayésienne ton niveau θ,
   la pente a de ta courbe et ta tendance à deviner, en tenant compte des trois choix (une chance
   sur trois de tomber juste au hasard), des erreurs d'inattention et des « Je ne sais pas ».
4. **Les questions.** Chaque mot est choisi là où ta réponse est la plus instructive (échantillonnage
   de Thompson), avec un mot d'exploration toutes les six questions. Les deux leurres sont des
   définitions de mots de même nature (nom, verbe…), de difficulté et de longueur proches, qui ne
   reprennent pas le radical du mot demandé.
5. **Le score.** C'est la somme, sur les 43 315 mots, de la probabilité que tu connaisses chacun,
   avec un intervalle de crédibilité à 80 %. Toutes tes réponses (test, mode libre, défi du jour)
   s'accumulent : la précision s'améliore à chaque partie. Le contre-la-montre et les révisions ne
   comptent pas (pression du temps, mots déjà vus).

Sur des joueurs simulés, l'erreur médiane est de l'ordre de 6 % après 40 questions pour un
francophone natif. Pour un apprenant qui devine beaucoup, l'estimation est plus incertaine : d'où l'intérêt
du bouton « Je ne sais pas ».

## Organisation du code

```
Lexicometre/
  LexicometreApp.swift          point d'entrée
  Model/                        logique, sans interface (testable hors iOS)
    WordBank.swift              chargement du lexique (Resources/mots.tsv)
    VocabularyEstimator.swift   modèle bayésien et estimation
    QuestionFactory.swift       questions, leurres, défi du jour, mot du jour
    QuizSession.swift           déroulement d'une partie (5 modes)
    AppModel.swift              état global, progression, carnet, badges, sauvegarde
    PlayerData.swift            données sauvegardées (JSON local)
    Levels.swift, Badges.swift  titres, repères, XP, badges
  Views/                        écrans SwiftUI (accueil, quiz, résultats, stats, carnet, réglages)
  Resources/mots.tsv            23 726 mots de quiz + distribution des 43 315 mots
web/                            aperçu jouable dans le navigateur (même algorithme)
tools/
  extract_ddf.py, build_dataset.py   génération de mots.tsv
  CoreChecks/, run_core_checks.sh     vérifications de la logique (parties simulées)
  make_icon.py                        icône de l'app
```

`./tools/run_core_checks.sh` compile la partie `Model/` avec un banc d'essai et joue des parties
complètes avec des joueurs simulés (fonctionne sur macOS et Linux).

## Régénérer les données

1. Lexique 3.83 : `Lexique383.tsv` depuis lexique.org (ou le paquet Python `pylexique`, qui
   l'embarque), converti en UTF-8.
2. Wiktionnaire : export du Dictionnaire des francophones,
   [gitlab.com/mnemotix/ddf/ddf-wiktionnaire](https://gitlab.com/mnemotix/ddf/ddf-wiktionnaire)
   (`18nov2020.zip`, à décompresser).
3. `python3 tools/extract_ddf.py dossier_trig/ wikt_words.jsonl`
4. `python3 tools/build_dataset.py Lexique383.utf8.tsv wikt_words.jsonl Lexicometre/Resources/mots.tsv --stats`

## Sources et licences des données

- Définitions et exemples : **Wiktionnaire**, par ses contributeurs, sous licence
  [CC BY-SA](https://creativecommons.org/licenses/by-sa/4.0/deed.fr), via l'export du
  Dictionnaire des francophones.
- Fréquences et normes de connaissance : **Lexique 3.83**, Boris New, Christophe Pallier
  et coll., sous licence [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.fr).

Le fichier `mots.tsv` qui en est dérivé est partagé sous la même licence CC BY-SA 4.0 ; l'écran
« Comment ça marche » de l'app crédite ces sources.
