#!/usr/bin/env python3
"""Ramène tailles de police, rayons et graisses sur les échelles AppType / AppRadius.
Usage : python3 tools/harmonize_tokens.py lib/parts/*.part.dart
- fontSize: 11.2            -> fontSize: AppType.label   (plus proche ; égalité -> valeur supérieure ; plancher 9)
- BorderRadius.circular(14) -> BorderRadius.circular(AppRadius.l)
- FontWeight.w900           -> FontWeight.w800"""
import re, sys
TYPE = [('micro', 9), ('caption', 9.5), ('small', 10.5), ('label', 11.5), ('body', 12.5), ('bodyL', 13.5),
        ('title', 15), ('titleL', 17), ('h2', 19), ('h1', 21), ('display', 24), ('hero', 28)]
RAD = [('xs', 6), ('s', 8), ('m', 12), ('l', 16), ('xl', 20), ('xxl', 24)]

def snap(v, scale):
    best = None
    for name, x in scale:
        d = abs(v - x)
        if best is None or d < best[0] or (d == best[0] and x > best[2]): best = (d, name, x)
    return best[1]

stats = {'font': 0, 'radius': 0, 'weight': 0, 'font_changed': 0}
def font(m):
    v = float(m.group(1))
    if v > 31: return m.group(0)       # tailles d'affichage exceptionnelles : inchangées
    stats['font'] += 1
    name = snap(max(v, 9), TYPE)
    if dict(TYPE)[name] != v: stats['font_changed'] += 1
    return f'fontSize: AppType.{name}'
def radius(m):
    v = float(m.group(1)); stats['radius'] += 1
    if v >= 28: return 'BorderRadius.circular(AppRadius.pill)'
    return f'BorderRadius.circular(AppRadius.{snap(max(v, 6), RAD)})'

for path in sys.argv[1:]:
    s = open(path, encoding='utf-8').read()
    s = re.sub(r'fontSize:\s*(\d+(?:\.\d+)?)(?![\d.])', font, s)
    s = re.sub(r'BorderRadius\.circular\((\d+(?:\.\d+)?)\)', radius, s)
    n = s.count('FontWeight.w900'); stats['weight'] += n
    s = s.replace('FontWeight.w900', 'FontWeight.w800')
    open(path, 'w', encoding='utf-8').write(s)
print(stats)
