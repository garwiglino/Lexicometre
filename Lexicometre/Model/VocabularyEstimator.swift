import Foundation

enum AnswerOutcome: String, Codable, Sendable {
    case correct
    case wrong
    /// "Je ne sais pas"
    case unknown
}

struct VocabularyEstimate: Equatable, Sendable {
    /// Posterior median of the number of known words.
    var median: Double
    /// 80 % credible interval.
    var low: Double
    var high: Double
    var universe: Int
    var answered: Int

    /// Half-width of the 80 % interval relative to the estimate (0.08 means ±8 %).
    var precision: Double { median > 0 ? (high - low) / 2 / median : 1 }
    /// Share of the whole lexicon.
    var share: Double { universe > 0 ? median / Double(universe) : 0 }

    var displayValue: Int { Self.round(median) }
    var displayLow: Int { Self.round(low) }
    var displayHigh: Int { Self.round(high) }

    static func round(_ value: Double) -> Int {
        let step = value >= 2_000 ? 100.0 : 10.0
        return Int((value / step).rounded() * step)
    }
}

/// Prior belief on the ability before any answer.
struct EstimatorPrior: Codable, Equatable, Sendable {
    var mean: Double
    var sd: Double

    static let native = EstimatorPrior(mean: 0, sd: 1.5)
    static let learner = EstimatorPrior(mean: -4, sd: 2.5)
    static let unspecified = EstimatorPrior(mean: -1, sd: 2.5)
}

/// Bayesian estimate of the vocabulary size.
///
/// Each word has a difficulty `b` calibrated on French speakers (Lexique 3.83 norms).
/// The player knows a word with probability σ(a · (θ − b)); ability θ, slope a and the
/// propensity c to guess instead of answering "je ne sais pas" are estimated on a grid.
/// A known word gets the right definition (1 − slip − unsure), a wrong one (slip) or a
/// "je ne sais pas" (unsure); an unknown word gets a guess (c, right one time in three) or
/// a "je ne sais pas" (1 − c). The vocabulary is Σ σ(a · (θ − b)) over every word of the lexicon.
struct VocabularyEstimator: Sendable {
    static let thetas: [Double] = (0...360).map { -10 + Double($0) * 0.05 }
    static let slopes: [Double] = [0.5, 0.7, 1.0, 1.4, 2.0]
    static let slopePrior: [Double] = [0.1, 0.2, 0.4, 0.2, 0.1]
    static let guessRates: [Double] = [0.05, 0.2, 0.4, 0.6, 0.8, 1.0]
    static let guessPrior: [Double] = [0.15, 0.15, 0.15, 0.15, 0.2, 0.2]
    static let slip = 0.05
    static let unsure = 0.02
    static let chance = 1.0 / 3.0
    /// Tempered likelihood: keeps the intervals honest when the model is imperfect.
    static let temper = 0.8

    let universe: Int
    /// Expected vocabulary of each (θ, a) cell; cell = t * slopes.count + a.
    private let vocabulary: [Double]
    private let cellsByVocabulary: [Int]
    /// Log posterior of each (θ, a, c) cell; index = cell * guessRates.count + c.
    private var logPosterior: [Double]
    private(set) var answered = 0

    init(histogram: DifficultyHistogram, universe: Int, prior: EstimatorPrior) {
        let slopeCount = Self.slopes.count
        let guessCount = Self.guessRates.count
        let bins = histogram.bins
        var vocabulary = [Double](repeating: 0, count: Self.thetas.count * slopeCount)
        var logPosterior = [Double](repeating: 0, count: vocabulary.count * guessCount)
        for (t, theta) in Self.thetas.enumerated() {
            let z = (theta - prior.mean) / prior.sd
            for (a, slope) in Self.slopes.enumerated() {
                let cell = t * slopeCount + a
                var total = 0.0
                for bin in bins {
                    total += bin.count / (1 + exp(-slope * (theta - bin.center)))
                }
                vocabulary[cell] = total
                for c in 0..<guessCount {
                    logPosterior[cell * guessCount + c] =
                        -0.5 * z * z + log(Self.slopePrior[a]) + log(Self.guessPrior[c])
                }
            }
        }
        self.universe = universe
        self.vocabulary = vocabulary
        self.cellsByVocabulary = vocabulary.indices.sorted { vocabulary[$0] < vocabulary[$1] }
        self.logPosterior = logPosterior
    }

    mutating func add(difficulty: Double, outcome: AnswerOutcome) {
        let slopeCount = Self.slopes.count
        let guessCount = Self.guessRates.count
        for (t, theta) in Self.thetas.enumerated() {
            for (a, slope) in Self.slopes.enumerated() {
                let known = 1 / (1 + exp(-slope * (theta - difficulty)))
                let base = (t * slopeCount + a) * guessCount
                for (c, guess) in Self.guessRates.enumerated() {
                    let likelihood: Double
                    switch outcome {
                    case .correct:
                        likelihood = known * (1 - Self.slip - Self.unsure) + (1 - known) * guess * Self.chance
                    case .wrong:
                        likelihood = known * Self.slip + (1 - known) * guess * (1 - Self.chance)
                    case .unknown:
                        likelihood = known * Self.unsure + (1 - known) * (1 - guess)
                    }
                    logPosterior[base + c] += Self.temper * log(max(likelihood, 1e-300))
                }
            }
        }
        answered += 1
    }

    /// Posterior weight of each (θ, a) cell, guess propensity integrated out. Sums to 1.
    private func cellWeights() -> [Double] {
        let guessCount = Self.guessRates.count
        let maxLog = logPosterior.max() ?? 0
        var weights = [Double](repeating: 0, count: vocabulary.count)
        var total = 0.0
        for cell in weights.indices {
            var weight = 0.0
            for c in 0..<guessCount {
                weight += exp(logPosterior[cell * guessCount + c] - maxLog)
            }
            weights[cell] = weight
            total += weight
        }
        return weights.map { $0 / total }
    }

    func estimate() -> VocabularyEstimate {
        let weights = cellWeights()
        var cumulative = 0.0
        var low: Double?
        var median: Double?
        var high: Double?
        for cell in cellsByVocabulary {
            cumulative += weights[cell]
            if low == nil, cumulative >= 0.1 { low = vocabulary[cell] }
            if median == nil, cumulative >= 0.5 { median = vocabulary[cell] }
            if cumulative >= 0.9 {
                high = vocabulary[cell]
                break
            }
        }
        let fallback = vocabulary[cellsByVocabulary.last ?? 0]
        return VocabularyEstimate(median: median ?? fallback, low: low ?? fallback,
                                  high: high ?? fallback, universe: universe, answered: answered)
    }

    /// Draws (θ, a) from the posterior.
    func sampleAbility<G: RandomNumberGenerator>(using generator: inout G) -> (theta: Double, slope: Double) {
        let weights = cellWeights()
        let slopeCount = Self.slopes.count
        var remaining = Double.random(in: 0..<1, using: &generator)
        var chosen = weights.count - 1
        for (cell, weight) in weights.enumerated() {
            remaining -= weight
            if remaining <= 0 {
                chosen = cell
                break
            }
        }
        return (Self.thetas[chosen / slopeCount], Self.slopes[chosen % slopeCount])
    }

    /// Difficulty of a word the player should know with probability `successRate`
    /// under an ability drawn from the posterior (Thompson sampling).
    func targetDifficulty<G: RandomNumberGenerator>(successRate: Double, using generator: inout G) -> Double {
        let (theta, slope) = sampleAbility(using: &generator)
        return theta - log(successRate / (1 - successRate)) / slope
    }

    /// Posterior mean probability of knowing a word of each given difficulty.
    func knowledge(at difficulties: [Double]) -> [Double] {
        let weights = cellWeights()
        let slopeCount = Self.slopes.count
        var result = [Double](repeating: 0, count: difficulties.count)
        for (cell, weight) in weights.enumerated() where weight > 1e-7 {
            let theta = Self.thetas[cell / slopeCount]
            let slope = Self.slopes[cell % slopeCount]
            for (i, difficulty) in difficulties.enumerated() {
                result[i] += weight / (1 + exp(-slope * (theta - difficulty)))
            }
        }
        return result
    }
}
