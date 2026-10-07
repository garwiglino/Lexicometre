/* Lexicomètre — logique de jeu (portage web de Lexicometre/Model). */
(function (root) {
  'use strict';

  // ---------- Lexique ----------
  function parseBank(text) {
    const lines = text.split('\n');
    let universe = 0, hist = null;
    const words = [];
    for (const line of lines) {
      if (!line) continue;
      if (line.startsWith('#N=')) { universe = parseInt(line.slice(3), 10); continue; }
      if (line.startsWith('#H=')) {
        const v = line.slice(3).split(',').map(Number);
        hist = { start: v[0], width: v[1], counts: v.slice(2) };
        continue;
      }
      const f = line.split('\t');
      if (f.length < 6) continue;
      words.push({ id: +f[0], text: f[1], pos: f[2], gender: f[3] || null, b: +f[4], def: f[5], ex: f[6] || null });
    }
    words.sort((x, y) => x.b - y.b || x.id - y.id);
    const byPos = {};
    words.forEach((w, i) => { (byPos[w.pos] = byPos[w.pos] || []).push(i); });
    const bins = [];
    hist.counts.forEach((c, i) => { if (c > 0) bins.push([hist.start + (i + 0.5) * hist.width, c]); });
    return { universe, bins, words, byPos };
  }

  const popularity = (w) => 1 / (1 + Math.exp(w.b));
  const difficultyFor = (p) => Math.log((1 - p) / p);
  const GRAMMAR = { n: 'n.', v: 'v.', adj: 'adj.', adv: 'adv.' };
  const GENDER = { m: 'm.', f: 'f.', mf: 'm. et f.' };
  const FULL = { n: 'nom', v: 'verbe', adj: 'adjectif', adv: 'adverbe' };
  const FULL_GENDER = { m: 'masculin', f: 'féminin', mf: 'masculin et féminin' };
  function grammarShort(w) { return w.pos === 'n' && w.gender ? 'n. ' + GENDER[w.gender] : GRAMMAR[w.pos]; }
  function grammarLong(w) { return w.pos === 'n' && w.gender ? 'nom ' + FULL_GENDER[w.gender] : FULL[w.pos]; }

  function lowerBound(bank, b, positions) {
    let lo = 0, hi = positions ? positions.length : bank.words.length;
    while (lo < hi) {
      const mid = (lo + hi) >> 1;
      const w = bank.words[positions ? positions[mid] : mid];
      if (w.b < b) lo = mid + 1; else hi = mid;
    }
    return lo;
  }

  function wordsNear(bank, b, count, excluded) {
    const n = bank.words.length;
    let left = lowerBound(bank, b) - 1, right = left + 1;
    const out = [];
    while (out.length < count && (left >= 0 || right < n)) {
      let takeRight;
      if (left < 0) takeRight = true;
      else if (right >= n) takeRight = false;
      else takeRight = Math.abs(bank.words[right].b - b) <= Math.abs(b - bank.words[left].b);
      const w = bank.words[takeRight ? right++ : left--];
      if (!excluded || !excluded.has(w.id)) out.push(w);
    }
    return out;
  }

  // ---------- Texte ----------
  function fold(s) {
    return s.toLowerCase().replace(/œ/g, 'oe').replace(/æ/g, 'ae').normalize('NFD').replace(/[̀-ͯ]/g, '');
  }
  const tokens = (s) => fold(s).split(/[^a-z]+/).filter(Boolean);
  function lcp(a, b) { let i = 0; while (i < a.length && i < b.length && a[i] === b[i]) i++; return i; }
  function reusesStem(word, text) {
    const parts = tokens(word).filter((t) => t.length >= 3);
    const stems = parts.length ? parts : [fold(word)];
    for (const t of tokens(text)) {
      if (t.length < 3) continue;
      for (const s of stems) {
        if (t === s) return true;
        if (lcp(t, s) >= Math.max(4, Math.ceil(0.6 * Math.min(t.length, s.length)))) return true;
      }
    }
    return false;
  }

  // ---------- Hasard ----------
  function seeded(seedText) {
    let h = 2166136261;
    for (let i = 0; i < seedText.length; i++) { h ^= seedText.charCodeAt(i); h = Math.imul(h, 16777619); }
    let a = h >>> 0;
    return function () { // mulberry32
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  const pick = (arr, rnd) => arr[Math.floor(rnd() * arr.length)];
  function shuffle(arr, rnd) {
    for (let i = arr.length - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [arr[i], arr[j]] = [arr[j], arr[i]]; }
    return arr;
  }

  // ---------- Questions ----------
  function makeQuestion(bank, word, rnd) {
    const pool = bank.byPos[word.pos] || [];
    const chosen = [];
    const ok = (c) => c.id !== word.id && c.def !== word.def && !chosen.some((x) => x.id === c.id || x.def === c.def);
    if (pool.length > 3) {
      const center = lowerBound(bank, word.b, pool);
      let win = 60;
      for (let attempt = 0; attempt < 600 && chosen.length < 2; attempt++) {
        if (attempt > 0 && attempt % 60 === 0) win *= 2;
        const lo = Math.max(0, center - win), hi = Math.min(pool.length - 1, center + win);
        const c = bank.words[pool[lo + Math.floor(rnd() * (hi - lo + 1))]];
        if (!ok(c)) continue;
        const ratio = c.def.length / Math.max(word.def.length, 1);
        if (attempt < 300 && (ratio < 0.5 || ratio > 2)) continue;
        if (attempt < 120 && word.pos === 'n' && c.gender !== word.gender) continue;
        if (reusesStem(word.text, c.def)) continue;
        chosen.push(c);
      }
    }
    for (let i = 0; chosen.length < 2 && i < bank.words.length; i++) if (ok(bank.words[i])) chosen.push(bank.words[i]);
    const options = shuffle(chosen.map((c) => c.def).concat([word.def]), rnd);
    return { word, options, correct: options.indexOf(word.def) };
  }

  const LADDER = [0.97, 0.92, 0.85, 0.76, 0.66, 0.56, 0.46, 0.36, 0.26, 0.16];
  function dailyQuestions(bank, day) {
    const rnd = seeded('defi-' + day);
    const used = new Set();
    return LADDER.map((p) => {
      const w = pick(wordsNear(bank, difficultyFor(p), 30, used), rnd);
      used.add(w.id);
      return makeQuestion(bank, w, rnd);
    });
  }

  // ---------- Estimateur (mêmes paramètres que l'app iOS) ----------
  const THETAS = Array.from({ length: 361 }, (_, i) => -10 + i * 0.05);
  const SLOPES = [0.5, 0.7, 1.0, 1.4, 2.0], SLOPE_PRIOR = [0.1, 0.2, 0.4, 0.2, 0.1];
  const GUESS = [0.05, 0.2, 0.4, 0.6, 0.8, 1.0], GUESS_PRIOR = [0.15, 0.15, 0.15, 0.15, 0.2, 0.2];
  const SLIP = 0.05, UNSURE = 0.02, CHANCE = 1 / 3, TEMPER = 0.8;
  const PRIORS = { native: [0, 1.5], learner: [-4, 2.5], unspecified: [-1, 2.5] };
  const NA = SLOPES.length, NC = GUESS.length, NCELL = THETAS.length * NA;

  function Estimator(bank, profile) {
    const [mu, sd] = PRIORS[profile] || PRIORS.unspecified;
    this.universe = bank.universe;
    this.vocab = new Float64Array(NCELL);
    this.logp = new Float64Array(NCELL * NC);
    this.answered = 0;
    for (let t = 0; t < THETAS.length; t++) {
      const z = (THETAS[t] - mu) / sd;
      for (let a = 0; a < NA; a++) {
        const cell = t * NA + a;
        let v = 0;
        for (const [center, count] of bank.bins) v += count / (1 + Math.exp(-SLOPES[a] * (THETAS[t] - center)));
        this.vocab[cell] = v;
        for (let c = 0; c < NC; c++) this.logp[cell * NC + c] = -0.5 * z * z + Math.log(SLOPE_PRIOR[a]) + Math.log(GUESS_PRIOR[c]);
      }
    }
    this.order = Array.from({ length: NCELL }, (_, i) => i).sort((i, j) => this.vocab[i] - this.vocab[j]);
  }
  Estimator.prototype.add = function (b, outcome) {
    for (let t = 0; t < THETAS.length; t++) {
      for (let a = 0; a < NA; a++) {
        const known = 1 / (1 + Math.exp(-SLOPES[a] * (THETAS[t] - b)));
        const base = (t * NA + a) * NC;
        for (let c = 0; c < NC; c++) {
          const g = GUESS[c];
          let l;
          if (outcome === 'correct') l = known * (1 - SLIP - UNSURE) + (1 - known) * g * CHANCE;
          else if (outcome === 'wrong') l = known * SLIP + (1 - known) * g * (1 - CHANCE);
          else l = known * UNSURE + (1 - known) * (1 - g);
          this.logp[base + c] += TEMPER * Math.log(Math.max(l, 1e-300));
        }
      }
    }
    this.answered++;
  };
  Estimator.prototype.weights = function () {
    let max = -Infinity;
    for (let i = 0; i < this.logp.length; i++) if (this.logp[i] > max) max = this.logp[i];
    const w = new Float64Array(NCELL);
    let total = 0;
    for (let cell = 0; cell < NCELL; cell++) {
      let s = 0;
      for (let c = 0; c < NC; c++) s += Math.exp(this.logp[cell * NC + c] - max);
      w[cell] = s; total += s;
    }
    for (let cell = 0; cell < NCELL; cell++) w[cell] /= total;
    return w;
  };
  Estimator.prototype.estimate = function () {
    const w = this.weights();
    let cum = 0, low = null, median = null, high = null;
    for (const cell of this.order) {
      cum += w[cell];
      if (low === null && cum >= 0.1) low = this.vocab[cell];
      if (median === null && cum >= 0.5) median = this.vocab[cell];
      if (cum >= 0.9) { high = this.vocab[cell]; break; }
    }
    const last = this.vocab[this.order[this.order.length - 1]];
    median = median ?? last; low = low ?? last; high = high ?? last;
    return { median, low, high, universe: this.universe, answered: this.answered,
             precision: median > 0 ? (high - low) / 2 / median : 1 };
  };
  Estimator.prototype.target = function (rate, rnd) {
    const w = this.weights();
    let r = rnd(), cell = NCELL - 1;
    for (let i = 0; i < NCELL; i++) { r -= w[i]; if (r <= 0) { cell = i; break; } }
    const theta = THETAS[Math.floor(cell / NA)], slope = SLOPES[cell % NA];
    return theta - Math.log(rate / (1 - rate)) / slope;
  };
  Estimator.prototype.knowledge = function (bs) {
    const w = this.weights();
    const out = bs.map(() => 0);
    for (let cell = 0; cell < NCELL; cell++) {
      if (w[cell] < 1e-7) continue;
      const theta = THETAS[Math.floor(cell / NA)], slope = SLOPES[cell % NA];
      bs.forEach((b, i) => { out[i] += w[cell] / (1 + Math.exp(-slope * (theta - b))); });
    }
    return out;
  };

  function roundDisplay(v) { const step = v >= 2000 ? 100 : 10; return Math.round(v / step) * step; }

  const TITLES = [
    [0, 'Graine de mots', 'Les premiers mots germent. Chaque partie en fait pousser de nouveaux.'],
    [1500, 'Curieux', 'Tu maîtrises les mots du quotidien et tu en veux davantage.'],
    [4000, 'Explorateur', 'Tu circules à l’aise dans la langue courante.'],
    [9000, 'Voyageur des mots', 'Presse, romans, conversations : peu de choses t’échappent.'],
    [16000, 'Lecteur assidu', 'Un vocabulaire riche, nourri de lectures.'],
    [23000, 'Fin lettré', 'Tu manies les nuances et les mots choisis.'],
    [29000, 'Érudit', 'Ton lexique dépasse celui de la plupart des diplômés.'],
    [34000, 'Encyclopédiste', 'Même les mots rares et savants te sont familiers.'],
    [38000, 'Immortel', 'Digne de l’Académie française : une langue presque sans secret.'],
  ];
  function titleFor(v) { let t = TITLES[0]; for (const x of TITLES) if (x[0] <= v) t = x; return { min: t[0], name: t[1], blurb: t[2] }; }
  const BENCHMARKS = [['Débutant (A2)', 2000], ['Intermédiaire (B2)', 6000], ['Collégien', 15000], ['Adulte', 25000], ['Étudiant', 31500], ['Grand lecteur', 36000]];

  root.Lexi = { parseBank, popularity, difficultyFor, grammarShort, grammarLong, wordsNear, reusesStem, seeded, pick,
                makeQuestion, dailyQuestions, Estimator, roundDisplay, titleFor, BENCHMARKS, LADDER };
})(typeof window !== 'undefined' ? window : globalThis);
