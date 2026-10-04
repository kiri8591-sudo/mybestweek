#!/usr/bin/env python3
"""Remplace les Color(0x…) en dur par _colors.<rôle> (palette AppColors) et retire
automatiquement les `const` devenus invalides autour.
Usage : python3 tools/migrate_colors.py lib/parts/mon_ecran.part.dart [...] [--exact-only]
Sans --exact-only, les couleurs hors table sont classées d'après leur contexte (fond, texte/icône, bordure, ombre) et leur teinte.
Les couleurs absentes de MAP sont laissées intactes et listées en fin de rapport."""
import re, sys

MAP = {}
def reg(role, *hexes):
    for h in hexes: MAP[h.upper()] = role
reg('textStrong', '3F4B45', '33414A')
reg('textMuted', '6F7777', '7A807D', '717977', '596461', '55605B', '718077', '7A8580', '748079')
reg('textWarm', '77746D', '7A7770')
reg('textFaint', 'A8A39A', 'B8B4AC')
reg('accentText', '526B78'); reg('accentIcon', '6F8E80'); reg('accentFill', '7D988D')
reg('accentFillBorder', '6C887A'); reg('accentStrongText', '587163'); reg('accentOutline', '8EAA9D')
reg('accentSoftBorder', 'B8CCC1', 'BFCFC7')
reg('danger', 'C27D68', 'C67E67'); reg('warnText', '9A7566'); reg('warnBg', 'F8E7DF'); reg('warnBorder', 'E3AA95')
reg('goldText', 'A27432'); reg('goldBg', 'FFEBC8'); reg('goldBorder', 'E8C98B')
reg('card', 'FFFDF9', 'FFFEFC')
reg('surfaceSoft', 'F7F5EF', 'F8F7F2', 'F7F7F3', 'F6F4EE', 'F7FAF8')
reg('surfaceSunken', 'F1F0EC', 'F1EEE8', 'F4F5F2')
reg('tintSoft', 'EAF2ED', 'EAF1ED', 'F2F6F3')
reg('tintStrong', 'E5EEE9', 'E7EFEA', 'DCE9E2', 'E2ECE7')
reg('peachBg', 'FFF4EA'); reg('peachBorder', 'E7D4C6')
reg('border', 'E0DDD5', 'E8E4DB', 'DCD8CF', 'DCE2DE', 'D9DDD9', 'E0E5E1')
reg('borderStrong', 'DAD6CC', 'D3D0C8', 'CFCBC2')
reg('borderTint', 'D0DED7', 'D7E1DB', 'D4E0DA')
ALPHA = {'12000000': 'shadow', '09000000': 'shadowSoft'}

def skip_string(s, i):
    """i pointe sur l'ouverture d'une chaîne ; retourne l'index après la fermeture."""
    raw = i > 0 and s[i-1] == 'r'
    q = s[i]
    if s.startswith(q*3, i): q3 = q*3; i += 3
    else: q3 = q; i += 1
    while i < len(s):
        if s.startswith(q3, i): return i + len(q3)
        if s[i] == '\\' and not raw: i += 2; continue
        if s[i] == '$' and not raw and i+1 < len(s) and s[i+1] == '{':
            i = match(s, i+1) + 1; continue
        i += 1
    return i

def match(s, i):
    """i pointe sur ( [ { ; retourne l'index de la fermeture correspondante."""
    depth = 0
    while i < len(s):
        c = s[i]
        if c in '\'"': i = skip_string(s, i); continue
        if s.startswith('//', i): i = s.find('\n', i); i = len(s) if i < 0 else i; continue
        if s.startswith('/*', i): i = s.find('*/', i) + 2; continue
        if c in '([{': depth += 1
        elif c in ')]}':
            depth -= 1
            if depth == 0: return i
        i += 1
    raise ValueError('bracket')


# ---------- classification automatique par contexte + teinte (V12.4.1) ----------
def _hsl(v):
    r, g, b = int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16)
    mx, mn = max(r, g, b), min(r, g, b)
    return r, g, b, (mx + mn) / 510.0

def _enclosing(s, i):
    """(paramètre nommé, appel englobant) pour la couleur située en i."""
    depth = 0; k = i - 1; start = None
    while k >= 0:
        c = s[k]
        if c in ')]}': depth += 1
        elif c in '([{':
            if depth == 0: break
            depth -= 1
        elif c == ',' and depth == 0 and start is None: start = k
        elif c == ';' and depth == 0: return None, None, ';'
        k -= 1
    open_idx = k
    # début de l'argument courant
    depth = 0; j = i - 1
    while j > open_idx:
        c = s[j]
        if c in ')]}': depth += 1
        elif c in '([{': depth -= 1
        elif c == ',' and depth == 0: break
        j -= 1
    pm = re.match(r'\s*(\w+)\s*:', s[j + 1:i])
    param = pm.group(1) if pm else None
    call = None
    if open_idx >= 0 and s[open_idx] == '(':
        cm = re.search(r'([A-Za-z_][\w.]*)\s*(?:<[^()]*>)?\s*$', s[max(0, open_idx - 60):open_idx])
        call = cm.group(1) if cm else None
    return param, call, (s[open_idx] if open_idx >= 0 else '')

FG_CALLS = ('TextStyle', 'Icon', '_uiIcon', 'copyWith', 'GoogleFonts.')
def _kind(param, call, s, i):
    if param is None:
        # affectation : final border = cond ? Color(..) : Color(..)
        st = max(s.rfind(';', 0, i), s.rfind('{', 0, i), s.rfind('}', 0, i))
        nm = re.search(r'(\w+)\s*=\s*[^=;]*$', s[st + 1:i])
        if not nm or '=>' in s[st + 1:i]: return None
        n = nm.group(1).lower()
        if 'border' in n: return 'border'
        if any(x in n for x in ('background', 'bg', 'fill', 'surface', 'card')): return 'bg'
        if any(x in n for x in ('foreground', 'fg', 'text', 'icon', 'label')): return 'fg'
        return None
    p = param.lower()
    if call and call.startswith('BoxShadow') or p == 'shadowcolor': return 'shadow'
    if call in ('Border.all', 'BorderSide') or 'border' in p or call == 'Divider': return 'border'
    if p in ('foregroundcolor', 'foreground', 'iconcolor', 'textcolor', 'labelcolor'): return 'fg'
    if p in ('backgroundcolor', 'background', 'bg', 'fillcolor', 'selectedtilecolor', 'selectedcolor', 'tilecolor'): return 'bg'
    if p == 'color':
        if call and (call in FG_CALLS or call.startswith('GoogleFonts')): return 'fg'
        return 'bg'
    return None

def classify(v, kind):
    r, g, b, L = _hsl(v)
    if kind == 'shadow': return 'shadowSoft' if int(v[0:2], 16) <= 0x0E else 'shadow'
    greenish = g >= r + 6 and g >= b - 2
    bluish = b >= r + 8 and not greenish
    warm = r >= g + 8 and r >= b + 14
    red = warm and g - b <= 14 and r - g >= 14
    gold = warm and g - b >= 22 and L >= 0.8
    if kind == 'bg':
        if L < 0.45: return 'accentFill' if greenish else None
        if L < 0.80: return 'accentFill' if greenish else None
        if red and L >= 0.88: return 'warnBg'
        if gold: return 'goldBg'
        if warm and L >= 0.9 and (r - b) >= 14: return 'peachBg'
        if greenish or bluish: return 'tintSoft' if L >= 0.955 else 'tintStrong'
        if L >= 0.975: return 'card'
        if L >= 0.945: return 'surfaceSoft'
        if L >= 0.92: return 'surfaceSunken'
        return 'border'
    if kind == 'border':
        if red and L >= 0.7: return 'warnBorder'
        if gold or (warm and L >= 0.7 and g - b >= 20): return 'goldBorder' if L < 0.9 else 'peachBorder'
        if L < 0.6: return 'accentFillBorder' if greenish else None
        if L < 0.8: return 'accentSoftBorder' if greenish else 'borderStrong'
        if greenish or bluish: return 'borderTint'
        return 'border' if L >= 0.86 else 'borderStrong'
    if kind == 'fg':
        if L >= 0.80: return None
        if red: return 'danger'
        if warm and g - b >= 20 and L >= 0.45: return 'goldText'
        if warm: return 'textWarm' if L >= 0.34 else 'textStrong'
        if greenish and L >= 0.34 and (g - r) >= 12: return 'accentIcon'
        if bluish and L < 0.5 and (b - r) >= 14: return 'accentText'
        if L < 0.34: return 'textStrong'
        if L < 0.60: return 'textMuted'
        return 'textFaint'
    return None

def _in_darkmode_statement(s, i):
    st = max(s.rfind(';', 0, i), s.rfind('{', 0, i), s.rfind('}', 0, i))
    return '_darkMode' in s[max(st, i - 400):i]

def _is_param_default(s, i):
    return re.search(r'=\s*(?:const\s+)?$', s[max(0, i - 40):i]) is not None and _enclosing(s, i)[0] is None and re.search(r'[\w>?]\s+\w+\s*=\s*(?:const\s+)?$', s[max(0, i - 60):i]) is not None and s.rfind(';', 0, i) < s.rfind('(', 0, i)

CONST_RE = re.compile(r'\bconst\b\s*')
HEAD_RE = re.compile(r'[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?\s*(?:<[^()]*?>)?\s*(?=[(\[{])|(?:<[^()\[\]{}]*?>)?\s*(?=[\[{])')

def migrate(path):
    s = open(path, encoding='utf-8').read()
    color_re = re.compile(r'(?:\bconst\s+)?Color\(0x([0-9A-Fa-f]{8})\)')
    reps = []   # (start, end, text)
    unmapped = {}; todo = []; skipped = []
    for m in color_re.finditer(s):
        v = m.group(1).upper()
        if _in_darkmode_statement(s, m.start()) or _is_param_default(s, m.start()):
            skipped.append(s.count('\n', 0, m.start()) + 1); continue
        role = ALPHA.get(v) if v[:2] != 'FF' else MAP.get(v[2:])
        if role is None and AUTO:
            param, call, _ = _enclosing(s, m.start())
            kind = 'shadow' if v[:2] != 'FF' else _kind(param, call, s, m.start())
            role = classify(v[2:] if v[:2] == 'FF' else v, kind) if kind else None
        if role is None:
            unmapped[v] = unmapped.get(v, 0) + 1
            todo.append((s.count('\n', 0, m.start()) + 1, v)); continue
        reps.append((m.start(), m.end(), '_colors.' + role))
    # const englobants à retirer
    kill = set(); decl = []
    for cm in CONST_RE.finditer(s):
        hm = HEAD_RE.match(s, cm.end())
        if not hm: 
            # déclaration (static const x = …) : à signaler seulement si une couleur y figure
            continue
        op = hm.end()
        try: cl = match(s, op)
        except ValueError: continue
        for (a, b, _) in reps:
            if op <= a and b <= cl + 1 and not (cm.start() == a):
                kill.add((cm.start(), cm.end())); break
    edits = [(a, b, t) for a, b, t in reps] + [(a, b, '') for a, b in kill]
    # éviter les chevauchements : un const retiré qui est celui d'une couleur est déjà dans reps
    edits.sort(key=lambda e: (e[0], -e[1]))
    out = []; pos = 0
    for a, b, t in edits:
        if a < pos: continue
        out.append(s[pos:a]); out.append(t); pos = b
    out.append(s[pos:])
    open(path, 'w', encoding='utf-8').write(''.join(out))
    print(f'{path}: {len(reps)} migrées, {len(kill)} const retirés, {len(skipped)} ignorées (_darkMode / valeur par défaut), {len(todo)} restantes')
    for ln, v in todo: print(f'    reste ligne {ln}: 0x{v}')
    for ln in skipped: print(f'    ignorée ligne {ln}')

AUTO = '--exact-only' not in sys.argv
for p in [a for a in sys.argv[1:] if not a.startswith('--')]: migrate(p)
