"""Join Lexique 3.83 (frequencies + knowledge norms) with the Wiktionnaire
(definitions, examples) and write the word bank bundled in the iOS app.

Usage: python3 build_dataset.py Lexique383.utf8.tsv wikt_words.jsonl mots.tsv [--stats]

Output (UTF-8 TSV):
  #N=<number of words of the lexicon>
  #H=<start>,<width>,<counts...>   histogram of the difficulty of all those words
  rank  word  pos  gender  difficulty  definition  example     (one line per quiz word)
rank = position of the lemma among all N lemmas, from the best known to the rarest;
difficulty = -logit(share of French speakers who know the word).
"""
import csv, collections, html, json, math, re, sys, unicodedata

LEXIQUE, WIKT, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
STATS = '--stats' in sys.argv

# ---------------------------------------------------------------- helpers
def fold(s):
    s = s.lower().replace('œ', 'oe').replace('æ', 'ae').replace('’', "'")
    return ''.join(c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn')

def key(s):
    return s.lower().replace('œ', 'oe').replace('æ', 'ae').replace('’', "'")

TOKEN = re.compile(r"[a-zà-öø-ÿœæ]+", re.I)

def lcp(a, b):
    n = 0
    for x, y in zip(a, b):
        if x != y: break
        n += 1
    return n

def self_referential(word, text):
    """True when the definition reuses the headword or its stem (giveaway)."""
    w = fold(word)
    parts = [p for p in TOKEN.findall(w) if len(p) >= 3] or [w]
    for t in TOKEN.findall(fold(text)):
        if len(t) < 3: continue
        for p in parts:
            if t == p: return True
            l = lcp(t, p)
            if l >= max(4, math.ceil(0.6 * min(len(t), len(p)))): return True
    return False

TAG_RE = re.compile(r'<[^>]+>')
NOTE_RE = re.compile(r'(?:—\s*)?<b>\s*Note\s*:.*$', re.S | re.I)
LEAD_PAREN = re.compile(r'^\s*(?:\([^()]{1,100}\)\s*[.,:]?\s*)+')
TEMPLATE_RE = re.compile(r'\{\{[^{}]*\}\}?')
SPACES = re.compile(r'\s+')

FORM_OF = re.compile(r'^(pluriel|féminin|masculin|variante|ancienne orthographe|orthographe|graphie|'
                     r'participe|forme|première personne|deuxième personne|troisième personne|'
                     r'abréviation|sigle|acronyme|définition manquante|nom de famille|prénom|'
                     r'gentilé|singulier de|apocope|aphérèse|diminutif de|augmentatif|'
                     r'troncation|ellipse de|par ellipse|symbole|mauvaise orthographe|faute|erreur|nom donné à|marque déposée)', re.I)

def clean_def(raw):
    s = NOTE_RE.sub('', raw)
    s = TEMPLATE_RE.sub('', s)
    s = TAG_RE.sub('', s)
    s = html.unescape(s)
    s = SPACES.sub(' ', s).strip()
    s = LEAD_PAREN.sub('', s).strip()
    s = s.strip(' —-–:;,')
    if not s: return ''
    if s[-1] not in '.!?…': s += '.'
    s = s[0].upper() + s[1:]
    s = s.replace(' .', '.').replace(' ,', ',')
    s = re.sub(r'(?<!\.)\.\.(?!\.)', '.', s)
    s = re.sub(r'^[&(]\s+', '', s).replace(' & ', ' et ')
    if s and s[0].islower(): s = s[0].upper() + s[1:]
    return s

def clean_example(raw, word):
    if 'manquante' in raw: return ''
    s = raw.replace('<br />', ' ').replace('<br/>', ' ')
    s = re.sub(r'</?b>', '\x01', s)
    s = TAG_RE.sub('', s)
    s = html.unescape(s)
    s = SPACES.sub(' ', s).strip()
    parts = s.split('\x01')
    if len(parts) % 2 == 0: return ''           # unbalanced bold
    out = ''.join(('**' + p.strip() + '**') if i % 2 else p for i, p in enumerate(parts))
    out = out.replace('** **', ' ').strip()
    if '**' not in out: return ''
    if len(out) > 150 or len(out) < 12: return ''
    if any(c in out for c in '{}[]|'): return ''
    return out

BAD_TAGS = ('Temporality=obsoleteUsage', 'Temporality=outdatedUsage', 'Temporality=archaicUsage',
            'Frequency=rarelyUsed', 'Frequency=veryRarelyUsed', 'Frequency=hapax',
            'Register=vulgarRegister', 'Register=veryInformalRegister', 'Register=childishRegister')

def sense_score(tags):
    s = 0
    for t in tags:
        if t in BAD_TAGS or t.startswith('Localisation') or t.startswith('Sociolect'): s += 10
        elif t == 'Register=informalRegister': s += 3
    return s

POS_MAP = {'NOM': 'noun', 'VER': 'verb', 'AUX': 'verb', 'ADJ': 'adjective', 'ADV': 'adverb'}
POS_CODE = {'noun': 'n', 'verb': 'v', 'adjective': 'adj', 'adverb': 'adv'}
GENDER_CODE = {'masculine': 'm', 'feminine': 'f', 'gender/epicene': 'mf'}
UNIVERSE_CGRAMS = ('NOM', 'VER', 'AUX', 'ADJ', 'ADV', 'PRE', 'CON', 'PRO', 'ART')

# ---------------------------------------------------------------- Lexique
rows = list(csv.reader(open(LEXIQUE, encoding='utf-8'), delimiter='\t', quoting=csv.QUOTE_NONE))
H = {h.split('_', 1)[1]: i for i, h in enumerate(rows[0])}
num = lambda s: float(s.replace(',', '.')) if s else 0.0
pairs = {}
for r in rows[1:]:
    k = (r[H['lemme']], r[H['cgram']])
    if k not in pairs:
        d = r[H['deflem']]; o = r[H['defobs']]
        pairs[k] = dict(films=num(r[H['freqlemfilms2']]), books=num(r[H['freqlemlivres']]),
                        deflem=num(d) if d else None, defobs=num(o) if o else None)
lemmas = collections.defaultdict(lambda: dict(freq=0.0, cg={}))
for (l, c), v in pairs.items():
    if not l or not c.startswith(UNIVERSE_CGRAMS): continue
    if any(ch.isdigit() for ch in l): continue
    f = (v['films'] + v['books']) / 2
    lemmas[l]['freq'] += f
    lemmas[l]['cg'][c] = dict(v, freq=f)

# ---------------------------------------------------------------- Wiktionnaire
wikt = collections.defaultdict(list)
for line in open(WIKT, encoding='utf-8'):
    r = json.loads(line)
    if r['p'] in (None, 'properNoun'): continue
    wikt[key(r['w'])].append(r)

universe = []
for l, info in lemmas.items():
    if len(l) < 2 and l not in ('à', 'a', 'y', 'ô', 'ô'): continue
    if key(l) not in wikt: continue
    if info['freq'] <= 0: continue
    universe.append(l)

# ---------------------------------------------------------------- ease ordering
# Shrink the Lexique knowledge norm (deflem: % of raters knowing the word) toward
# the value predicted from frequency, then sort by the resulting ease.
def logit(p): p = min(max(p, 1e-4), 1 - 1e-4); return math.log(p / (1 - p))
xs, ys = [], []
for l in universe:
    best = max(lemmas[l]['cg'].values(), key=lambda v: v['freq'])
    if best['deflem'] is not None and best['defobs']:
        xs.append(math.log10(lemmas[l]['freq'] + 1e-3)); ys.append(logit((best['deflem'] / 100 * best['defobs'] + 0.5) / (best['defobs'] + 1)))
mx, my = sum(xs) / len(xs), sum(ys) / len(ys)
b = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sum((x - mx) ** 2 for x in xs)
a = my - b * mx
print(f'ease regression: logit(known) = {a:.2f} + {b:.2f}*log10(freq)  (n={len(xs)})')
PRIOR_N = 12
LAPSE = 0.02          # raters who know a word but gave an incomplete definition
def ease(l):
    f = lemmas[l]['freq']
    lf = math.log10(f + 1e-3)
    p_pred = 1 / (1 + math.exp(-(a + b * lf)))
    best = max(lemmas[l]['cg'].values(), key=lambda v: v['freq'])
    if best['deflem'] is None or not best['defobs']:
        return logit(p_pred)
    n = best['defobs']; k = best['deflem'] / 100 * n
    p_obs = min((k + 0.5) / (n + 1) / (1 - LAPSE), 0.999)
    p_shr = (n * p_obs + PRIOR_N * p_pred) / (n + PRIOR_N)
    # the norms saturate for frequent words: trust frequency there, the norms below ~1/M
    w = min(max((math.log10(30) - lf) / math.log10(30), 0.0), 1.0)
    return logit(p_pred) + w * (logit(p_shr) - logit(p_pred))
EASE = {l: ease(l) for l in universe}
universe.sort(key=lambda l: (-EASE[l], -lemmas[l]['freq'], l))
rank = {l: i + 1 for i, l in enumerate(universe)}
N = len(universe)

# ---------------------------------------------------------------- choose a definition
OVERRIDES = {
    'déjeuner': ('n', 'm', 'Repas de midi.', ''),
}

def shorten(d, maxlen=170):
    if len(d) <= maxlen: return d
    i = d.find('. ')
    while i != -1 and d[max(0, i - 3):i].lower().endswith(('etc', ' m', 'j.-c', ' st')):
        i = d.find('. ', i + 1)
    if 25 <= i + 1 <= maxlen: return d[:i + 1]
    for cut in sorted((m.start() for m in re.finditer(r'[;,]', d[:maxlen - 1])), reverse=True):
        if cut < 60: break
        head = d[:cut].rstrip(' ;,.')
        if head.count('(') == head.count(')'): return head + '.'
    return None

SPECIALIST = {'heraldique', 'maconnerie', 'typographie', 'imprimerie', 'marine', 'fauconnerie', 'chasse',
              'peche', 'metrologie', 'liturgie', 'reliure', 'gravure', 'verrerie', 'versification',
              'vexillologie', 'numismatique', 'menuiserie', 'metallurgie', 'saliculture', 'usinage',
              'boucherie', 'armement', 'equitation', 'hippologie', 'viticulture', 'sylviculture', 'venerie'}
ANAPHORA = re.compile(r"\b(?:ce|cet|cette|ces)\s+(?!qui\b|que\b|qu'|dont\b|où\b|faisant\b)[a-zàâçéèêëîïôûùüÿœ\-]{3,}", re.I)

def pick_sense(l, entry):
    """Walk senses in Wiktionnaire order and return (definition, example) for the
    main sense, or None when the main sense is unusable for a fair quiz."""
    fallback = None
    for s in entry['s']:
        if '{{' in s['d']: reasons['template'] += 1; continue
        d = clean_def(s['d'])
        if not d or len(d) < 6 or 'manquante' in d: reasons['empty'] += 1; continue
        if FORM_OF.match(d) or d.startswith(('→', 'Voir ', 'Cf.')) or '→' in d: reasons['formof'] += 1; return None
        if sense_score(s['t']) >= 10: reasons['skip-tag'] += 1; continue
        d = shorten(d)
        if d is None: reasons['long'] += 1; return None
        if ANAPHORA.search(d[1:]): reasons['anaphora'] += 1; continue
        if any(t.startswith('Domain=') and t[7:] in SPECIALIST for t in s['t']): reasons['specialist'] += 1; return None
        if self_referential(l, d): reasons['selfref'] += 1; return None
        if any(c in d for c in '{}[]|=<>') or 'http' in d: reasons['markup'] += 1; return None
        if d.count('(') != d.count(')') or d.count('«') != d.count('»'): reasons['unbalanced'] += 1; continue
        ex = ''
        for x in s['x']:
            ex = clean_example(x, l)
            if ex: break
        if len(d.split()) < 2:
            # a one-word gloss ("Salutation.") makes a poor question: keep looking
            fallback = fallback or (d, ex)
            reasons['one-word'] += 1
            continue
        return d, ex
    return fallback

reasons = collections.Counter()
out_rows = []
for l in universe:
    if l in OVERRIDES:
        p, g, d, ex = OVERRIDES[l]
        out_rows.append((rank[l], l, p, g, f'{-EASE[l]:.2f}', d, ex)); continue
    cgs = sorted(lemmas[l]['cg'].items(), key=lambda kv: -kv[1]['freq'])
    top = cgs[0][1]['freq'] or 1e-9
    chosen = None
    for cg, v in cgs:
        if v['freq'] < 0.3 * top: break
        pos = POS_MAP.get(cg)
        if pos is None: continue
        for e in (e for e in wikt[key(l)] if e['p'] == pos and e['w'][:1] == e['w'][:1].lower()):
            r = pick_sense(l, e)
            if r:
                g = GENDER_CODE.get(e['g'], '') if pos == 'noun' else ''
                word = e['w'] if key(e['w']) == key(l) else l
                chosen = (rank[l], word, POS_CODE[pos], g, f'{-EASE[l]:.2f}', r[0], r[1])
                break
        if chosen: break
    if chosen: out_rows.append(chosen)
    else: reasons['noquiz'] += 1

with open(OUT, 'w', encoding='utf-8') as f:
    f.write(f'#N={N}\n')
    # histogram of the difficulty (-ease, logit units) of all N words of the universe
    lo, width = -8.0, 0.1
    counts = [0] * 150
    for l in universe:
        counts[min(max(int((-EASE[l] - lo) / width), 0), len(counts) - 1)] += 1
    f.write(f'#H={lo},{width},' + ','.join(map(str, counts)) + '\n')
    for r in out_rows:
        f.write('\t'.join(str(c).replace('\t', ' ').replace('\n', ' ') for c in r) + '\n')
print('universe N =', N, '| quiz words =', len(out_rows))
print(reasons.most_common())
if STATS:
    curve = collections.defaultdict(list)
    for l in universe:
        best = max(lemmas[l]['cg'].values(), key=lambda v: v['freq'])
        if best['deflem'] is not None: curve[min(rank[l] // 2500, 17)].append(best['deflem'])
    for k in sorted(curve): print(f'ranks {k*2500:>5}-{k*2500+2499:>5}: mean known {sum(curve[k])/len(curve[k]):5.1f}%  (n={len(curve[k])})')
    import random
    random.seed(4)
    bands = [(1, 1000), (1000, 3000), (3000, 6000), (6000, 10000), (10000, 15000), (15000, 20000), (20000, 25000), (25000, 30000), (30000, 35000), (35000, 40000), (40000, 50000)]
    for lo, hi in bands:
        sel = [r for r in out_rows if lo <= r[0] < hi]
        print(f'\n=== rank {lo}-{hi}: {len(sel)} quiz words / {hi-lo} ' )
        for r in random.sample(sel, min(6, len(sel))): print('  ', r[0], r[1], r[2], r[3], r[4], '|', r[5][:110], '|', r[6][:70])
