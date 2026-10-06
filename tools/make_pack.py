#!/usr/bin/env python3
"""Génère le pack : SVG sources + PNG 192 px (assets/icons/pack/) + table Dart (icon_pack_table.txt).
Usage : python3 tools/make_pack.py   (nécessite cairosvg)"""
import os, sys, importlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cairosvg, build_icon_pack as B
for mod in ('icons_b1', 'icons_b2'):
    if os.path.exists(os.path.join(os.path.dirname(os.path.abspath(__file__)), mod + '.py')): importlib.import_module(mod)
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = os.path.join(root, 'assets', 'icons', 'pack'); src = os.path.join(root, 'tools', 'icon_pack_src')
os.makedirs(out, exist_ok=True); os.makedirs(src, exist_ok=True)
for i, (label, kw, body, cat) in B.I.items():
    assert cat, f'catégorie manquante : {i}'
    svg = B.svg(body)
    open(os.path.join(src, i + '.svg'), 'w', encoding='utf-8').write(svg)
    cairosvg.svg2png(bytestring=svg.encode(), write_to=os.path.join(out, i + '.png'), output_width=192, output_height=192)
import re, unicodedata
q = lambda t: t.replace("'", "’")
fold = lambda t: re.sub(r'[^a-z0-9 ]+', ' ', ''.join(ch for ch in unicodedata.normalize('NFD', t.lower()) if unicodedata.category(ch) != 'Mn'))
table = '\n'.join("  _PackIcon('%s', '%s', '%s')," % (i, q(l), (k + ' ' + fold(c)).strip()) for i, (l, k, _, c) in B.I.items()) + '\n'
open(os.path.join(root, 'tools', 'icon_pack_table.txt'), 'w', encoding='utf-8').write(table)
dart = os.path.join(root, 'lib', 'parts', 'icon_pack.part.dart')
if os.path.exists(dart):
    t = open(dart, encoding='utf-8').read()
    a = t.index('const List<_PackIcon> _packIcons = [') + len('const List<_PackIcon> _packIcons = [\n'); b = t.index('];', a)
    open(dart, 'w', encoding='utf-8').write(t[:a] + table + t[b:])
print(len(B.I), 'icônes générées')
