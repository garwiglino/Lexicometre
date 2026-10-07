"""Parse the Dictionnaire des francophones export of the Wiktionnaire (TriG)
and dump one JSON line per word: written form, POS, gender, ordered senses.

Usage: python3 extract_ddf.py <folder of .trig files> wikt_words.jsonl
Source: https://gitlab.com/mnemotix/ddf/ddf-wiktionnaire (18nov2020.zip, unzipped)."""
import json, os, re, sys, time, glob

SRC_DIR, OUT = sys.argv[1], sys.argv[2]

TOKEN = re.compile(r'''
    (?P<iri><[^>\s]*>)
  | (?P<lit3>"""(?:[^"\\]|\\.|"(?!""))*""")(?:@(?P<lang3>[A-Za-z\-]+)|\^\^\S+)?
  | (?P<lit>"(?:[^"\\\n]|\\.)*")(?:@(?P<lang>[A-Za-z\-]+)|\^\^[^\s;,]+)?
  | (?P<pname>[A-Za-z][\w\-]*:(?:[\w\-]+(?:\.[\w\-]+)*)?)
  | (?P<a>\ba\b)
  | (?P<punct>[;,.{}])
  | (?P<prefix>@prefix[^\n]*\n)
''', re.X)

UNESC = re.compile(r'\\(.)')
def unescape(s):
    return UNESC.sub(lambda m: {'n': '\n', 't': '\t', 'r': ''}.get(m.group(1), m.group(1)), s)

def short(iri):
    # keep '<kind>/<hash>' from data.dictionnairedesfrancophones.org IRIs
    i = iri.rfind('/', 0, iri.rfind('/'))
    return iri[i + 1:-1]

WANTED = {
    'ontolex:canonicalForm', 'ontolex:writtenRep', 'ddf:hasPartOfSpeech', 'ddf:hasGender',
    'ontolex:sense', 'core:definition', 'lexicog:usageExample', 'rdf:value',
    'ddf:hasDomain', 'ddf:hasTemporality', 'ddf:hasRegister', 'ddf:hasLocalisation',
    'ddf:hasGlossary', 'ddf:hasSociolect', 'ddf:hasTextualGenre', 'ddf:hasFrequency',
    'ddf:hasGrammaticalConstraint', 'ddf:hasTransitivity', 'ddf:hasNumber', 'a',
}
TAG_PREDS = {'ddf:hasDomain', 'ddf:hasTemporality', 'ddf:hasRegister', 'ddf:hasLocalisation',
             'ddf:hasGlossary', 'ddf:hasSociolect', 'ddf:hasTextualGenre', 'ddf:hasFrequency',
             'ddf:hasGrammaticalConstraint', 'ddf:hasTransitivity', 'ddf:hasNumber'}

word_form, form_text, word_pos, word_gender, word_type = {}, {}, {}, {}, {}
word_senses = {}          # word -> list of (seq, sense)
sense_def, sense_ex, sense_tags, ex_text = {}, {}, {}, {}
seq = 0

def obj_value(m):
    if m.group('iri') is not None:
        return short(m.group('iri'))
    if m.group('lit3') is not None:
        return unescape(m.group('lit3')[3:-3])
    if m.group('lit') is not None:
        return unescape(m.group('lit')[1:-1])
    return m.group(0)

def handle(s, p, o):
    global seq
    if p == 'ontolex:canonicalForm': word_form[s] = o
    elif p == 'ontolex:writtenRep': form_text[s] = o
    elif p == 'ddf:hasPartOfSpeech': word_pos[s] = o.split(':')[-1]
    elif p == 'ddf:hasGender': word_gender[s] = o.split(':')[-1]
    elif p == 'ontolex:sense':
        seq += 1; word_senses.setdefault(s, []).append((seq, o))
    elif p == 'core:definition': sense_def[s] = o
    elif p == 'lexicog:usageExample':
        seq += 1; sense_ex.setdefault(s, []).append((seq, o))
    elif p == 'rdf:value': ex_text[s] = o
    elif p in TAG_PREDS: sense_tags.setdefault(s, []).append(p.split(':')[1][3:] + '=' + o.split('/')[-1].split(':')[-1])
    elif p == 'a':
        if o in ('ontolex:Word', 'ontolex:MultiWordExpression'): word_type[s] = o.split(':')[1]

t0 = time.time()
for path in sorted(glob.glob(os.path.join(SRC_DIR, '*.trig'))):
    text = open(path, encoding='utf-8').read()
    state, subj, pred, n = 'S', None, None, 0
    for m in TOKEN.finditer(text):
        k = m.lastgroup
        if k == 'prefix': continue
        if k == 'punct':
            c = m.group('punct')
            if c == '{': state = 'S'; subj = None
            elif c == '}': state = 'S'
            elif c == '.': state = 'S'
            elif c == ';': state = 'P'
            elif c == ',': state = 'O'
            continue
        if state == 'S':
            subj = obj_value(m); state = 'P'
        elif state == 'P':
            pred = m.group(0); state = 'O'
        elif state == 'O':
            if pred in WANTED:
                handle(subj, pred, obj_value(m)); n += 1
            state = 'X'
    print(f'{os.path.basename(path)}: {n} triples kept, {time.time()-t0:.0f}s', flush=True)
    del text

with open(OUT, 'w', encoding='utf-8') as out:
    kept = 0
    for w, f in word_form.items():
        txt = form_text.get(f)
        if not txt: continue
        senses = []
        for _, sid in sorted(word_senses.get(w, [])):
            d = sense_def.get(sid)
            if d is None: continue
            exs = [ex_text[e] for _, e in sorted(sense_ex.get(sid, [])) if e in ex_text][:2]
            senses.append({'d': d, 't': sense_tags.get(sid, []), 'x': exs})
        rec = {'w': txt, 'p': word_pos.get(w), 'g': word_gender.get(w), 'k': word_type.get(w), 's': senses}
        out.write(json.dumps(rec, ensure_ascii=False) + '\n'); kept += 1
print('words written', kept, 'senses', len(sense_def), 'examples', len(ex_text), f'{time.time()-t0:.0f}s')
