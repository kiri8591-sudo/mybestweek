#!/usr/bin/env python3
"""Régénère assets/fonts/*.ttf (Nunito Sans, Lora) : instances statiques + sous-ensemble latin, depuis les polices
variables Google Fonts. Usage : python3 tools/make_fonts.py <dossier contenant NS.ttf NSI.ttf LO.ttf LOI.ttf>
  NS/NSI = NunitoSans[YTLC,opsz,wdth,wght].ttf (roman / italique) ; LO/LOI = Lora[wght].ttf (roman / italique)
Nécessite : pip install fonttools"""
import os, sys
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset
src = sys.argv[1]; out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'fonts')
os.makedirs(out, exist_ok=True)
UNI = (list(range(0x20, 0x7F)) + list(range(0xA0, 0x100)) + [0x131, 0x152, 0x153, 0x178, 0x2C6, 0x2DA, 0x2DC, 0x2013, 0x2014, 0x2018, 0x2019, 0x201A, 0x201C, 0x201D,
       0x201E, 0x2020, 0x2021, 0x2022, 0x2026, 0x2030, 0x2039, 0x203A, 0x20AC, 0x2122, 0x2190, 0x2191, 0x2192, 0x2193, 0x2212, 0x2713, 0xD7])
def build(path, axes, name):
    f = TTFont(os.path.join(src, path)); defaults = {a.axisTag: a.defaultValue for a in f['fvar'].axes}
    inst = instancer.instantiateVariableFont(f, {**defaults, **axes}, inplace=False)
    o = subset.Options(); o.layout_features = ['*']; o.name_IDs = ['*']; o.notdef_outline = True
    s = subset.Subsetter(o); s.populate(unicodes=UNI); s.subset(inst); inst.save(os.path.join(out, name + '.ttf'))
for n, w in (('Regular', 400), ('Medium', 500), ('SemiBold', 600), ('Bold', 700), ('ExtraBold', 800)): build('NS.ttf', {'wght': w, 'wdth': 100}, 'NunitoSans-' + n)
for n, w in (('Italic', 400), ('BoldItalic', 700)): build('NSI.ttf', {'wght': w, 'wdth': 100}, 'NunitoSans-' + n)
for n, w in (('Regular', 400), ('Medium', 500), ('SemiBold', 600), ('Bold', 700)): build('LO.ttf', {'wght': w}, 'Lora-' + n)
for n, w in (('Italic', 400), ('BoldItalic', 700)): build('LOI.ttf', {'wght': w}, 'Lora-' + n)
