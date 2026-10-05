#!/usr/bin/env python3
"""Pack d'icônes MyBestWeek : dessine 52 icônes (SVG) et les exporte en PNG 192 px
dans assets/icons/pack/. Lancer : python3 tools/build_icon_pack.py   (nécessite cairosvg)
Style : aplats doux, sans fond, lisibles en mode clair comme en mode sombre."""
import math, os, cairosvg

G1, G2, G3 = '#7D988D', '#5F8F78', '#B8D4C4'
P1, P2, P3 = '#E8A38C', '#C27D68', '#F6D5C5'
Y1, Y2, Y3 = '#F0C36D', '#C99236', '#FBE7B5'
B1, B2, B3 = '#7FA3B8', '#4F6F85', '#CFE2EC'
N1, N2, W, K, OUT = '#8B735E', '#5E4A3E', '#FFFDF9', '#3F4B45', '#9DB5A8'
LV, LV2, RED = '#B8A3C9', '#806B88', '#E07A7A'

def L(x1, y1, x2, y2, c, w=7): return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{c}" stroke-width="{w}" stroke-linecap="round"/>'
def S(d, c, w=7): return f'<path d="{d}" fill="none" stroke="{c}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'
def C(x, y, r, f, s=None, w=3): return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{f}"' + (f' stroke="{s}" stroke-width="{w}"' if s else '') + '/>'
def E(x, y, rx, ry, f, rot=0, s=None, w=3): return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{f}" transform="rotate({rot} {x} {y})"' + (f' stroke="{s}" stroke-width="{w}"' if s else '') + '/>'
def R(x, y, w_, h, f, rx=0, s=None, sw=3): return f'<rect x="{x}" y="{y}" width="{w_}" height="{h}" rx="{rx}" fill="{f}"' + (f' stroke="{s}" stroke-width="{sw}"' if s else '') + '/>'
def P(d, f, s=None, w=3): return f'<path d="{d}" fill="{f}"' + (f' stroke="{s}" stroke-width="{w}" stroke-linejoin="round"' if s else '') + '/>'
def PG(pts, f, s=None, w=3): return f'<polygon points="{pts}" fill="{f}"' + (f' stroke="{s}" stroke-width="{w}" stroke-linejoin="round"' if s else '') + '/>'
def ground(): return E(48, 88, 26, 3, G3)
def head(x, y, r=8): return C(x, y, r, P1)
def star_pts(cx, cy, ro, ri, n=5):
    pts = []
    for i in range(2 * n):
        a = -math.pi / 2 + i * math.pi / n; r = ro if i % 2 == 0 else ri
        pts.append(f'{cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}')
    return ' '.join(pts)
def rays(cx, cy, r1, r2, n, c, w=6):
    return ''.join(L(round(cx + r1 * math.cos(2 * math.pi * i / n), 1), round(cy + r1 * math.sin(2 * math.pi * i / n), 1),
                     round(cx + r2 * math.cos(2 * math.pi * i / n), 1), round(cy + r2 * math.sin(2 * math.pi * i / n), 1), c, w) for i in range(n))
def blob(circles, f, o=OUT):  # nuage / forme crème avec contour
    return ''.join(C(x, y, r + 2.2, o) for x, y, r in circles) + ''.join(C(x, y, r, f) for x, y, r in circles)

I = {}
def add(i, label, kw, body): I[i] = (label, kw, body)

add('taichi', 'Tai Chi', 'tai chi taichi qi gong qigong souplesse equilibre arts martiaux',
    ground() + S('M48 34 V58', G2, 10) + S('M48 42 Q30 40 20 54', G1, 7) + S('M48 40 Q66 34 76 20', G1, 7) + S('M48 58 L30 80', G2, 8) + S('M48 58 L68 80', G2, 8) + head(48, 22))
add('walk', 'Marche', 'marche promenade balade randonnee walk pas',
    ground() + S('M51 32 L46 58', G2, 10) + S('M49 38 L36 52', G1, 7) + S('M51 38 L63 50', G1, 7) + S('M46 58 L36 80', G2, 8) + S('M46 58 L60 70 L58 82', G2, 8) + head(52, 20))
add('run', 'Course', 'course running jogging footing courir',
    ground() + S('M54 32 L44 56', G2, 10) + S('M50 38 L38 46 L30 38', G1, 7) + S('M52 38 L66 46 L74 40', G1, 7) + S('M44 56 L58 68 L52 82', G2, 8) + S('M44 56 L32 70 L20 68', G2, 8) + head(57, 20))
add('yoga', 'Yoga', 'yoga meditation relaxation lotus zen detente respiration pilates',
    R(14, 80, 68, 7, G3, 3) + S('M48 36 V58', G2, 10) + S('M48 44 L30 62', G1, 7) + S('M48 44 L66 62', G1, 7) + S('M22 72 Q48 56 74 72', G2, 10) + C(26, 74, 5, P1) + C(70, 74, 5, P1) + head(48, 25))
add('stretch', 'Étirements', 'etirement stretching gym gymnastique souplesse echauffement mouvement',
    ground() + S('M48 36 V58', G2, 10) + S('M48 42 L32 18', G1, 7) + S('M48 42 L64 18', G1, 7) + S('M48 58 L38 82', G2, 8) + S('M48 58 L58 82', G2, 8) + head(48, 26))
add('bike', 'Vélo', 'velo bicyclette cyclisme bike',
    C(25, 64, 15, 'none', G2, 6) + C(71, 64, 15, 'none', G2, 6) + S('M25 64 L42 64 L36 42 L62 42 L71 64', P2, 6) + S('M42 64 L62 42', P2, 6) + S('M62 42 L66 32 L74 32', N2, 5) + L(30, 40, 42, 40, N2, 6) + C(42, 64, 4, Y1))
add('swim', 'Natation', 'natation piscine nager swim eau aquagym',
    C(62, 38, 8, P1) + S('M60 48 L40 36', G1, 8) + S('M16 62 Q26 54 36 62 T56 62 T76 62 T92 62', B1, 6) + S('M10 78 Q20 70 30 78 T50 78 T70 78 T90 78', B2, 6) + S('M62 46 L70 56', G2, 8))
add('dumbbell', 'Renforcement', 'muscu renforcement musculation haltere force fitness poids',
    L(30, 48, 66, 48, N2, 7) + R(16, 30, 10, 36, P2, 4) + R(26, 36, 8, 24, P1, 3) + R(70, 30, 10, 36, P2, 4) + R(62, 36, 8, 24, P1, 3))
add('piano', 'Piano', 'piano clavier musique touches gamme',
    R(10, 22, 76, 12, P2, 4) + R(10, 30, 76, 46, W, 6, OUT, 3) + ''.join(L(x, 34, x, 76, OUT, 2) for x in (24, 38, 52, 66)) +
    ''.join(R(x, 32, 9, 28, K, 2) for x in (19, 33, 57, 71)))
add('book', 'Lecture', 'lecture livre lire roman bibliotheque etude',
    P('M48 30 Q32 22 12 26 V70 Q32 66 48 74 Z', W, OUT, 3) + P('M48 30 Q64 22 84 26 V70 Q64 66 48 74 Z', W, OUT, 3) + R(44, 28, 8, 47, G2, 3) + R(12, 70, 72, 6, G2, 3) +
    L(20, 36, 38, 38, G3, 3) + L(20, 46, 38, 48, G3, 3) + L(58, 38, 76, 36, G3, 3) + L(58, 48, 76, 46, G3, 3) + P('M66 26 V44 L71 40 L76 44 V25 Z', P2))
add('basket', 'Marché', 'marche panier courses legumes fruits approvisionnement sarlat',
    S('M26 48 Q48 6 70 48', N1, 5) + C(34, 40, 9, P2) + C(56, 36, 11, G1) + P('M64 40 L78 24 L80 44 Z', '#EE9B4A') + P('M18 46 H78 L70 78 Q69 82 64 82 H32 Q27 82 26 78 Z', '#D9A55B', Y2, 3) +
    S('M24 58 H72 M28 70 H68', Y2, 3) + L(38, 48, 36, 80, Y2, 3) + L(58, 48, 60, 80, Y2, 3))
add('coffee', 'Pause café', 'cafe the pause boisson tasse petit dejeuner gouter',
    S('M36 30 q-6 -7 0 -13', G1, 4) + S('M48 30 q-6 -7 0 -13', G1, 4) + S('M60 30 q-6 -7 0 -13', G1, 4) + E(46, 84, 32, 5, G3) +
    P('M24 40 H68 V60 Q68 78 46 78 Q24 78 24 60 Z', W, OUT, 3) + E(46, 40, 22, 5, N1) + S('M68 46 Q84 46 82 58 Q80 68 66 66', N1, 5))
add('toast', 'Apéro entre amis', 'ami amis apero convivial soiree moment social sortie fete trinquer',
    f'<g transform="rotate(-16 34 62)">' + P('M24 22 H46 L42 52 Q35 58 28 52 Z', B3, B2, 3) + L(35, 56, 35, 76, B2, 4) + L(26, 78, 44, 78, B2, 4) + '</g>' +
    f'<g transform="rotate(16 62 62)">' + P('M52 22 H74 L70 52 Q63 58 56 52 Z', P3, P2, 3) + L(63, 56, 63, 76, P2, 4) + L(54, 78, 72, 78, P2, 4) + '</g>' +
    PG(star_pts(48, 14, 8, 3.5), Y1) + PG(star_pts(24, 12, 4.5, 2), Y2) + PG(star_pts(72, 12, 4.5, 2), Y2))
add('music', 'Musique', 'musique note chant ecoute melodie',
    P('M36 24 L72 16 V30 L36 38 Z', G1) + S('M36 66 V24', G2, 6) + S('M72 58 V16', G2, 6) + E(29, 68, 10, 8, G2, -20) + E(65, 60, 10, 8, G2, -20))
add('sun', 'Soleil', 'soleil beau temps ete lumiere matin ete chaleur',
    rays(48, 48, 28, 40, 8, Y2) + C(48, 48, 19, Y1))
add('moon', 'Lune', 'lune nuit soir coucher dormir',
    P('M58 12 A36 36 0 1 0 84 62 A28 28 0 1 1 58 12 Z', Y1, Y2, 3) + PG(star_pts(70, 24, 7, 3), Y1) + PG(star_pts(80, 42, 4.5, 2), Y2))
add('heart', 'Cœur', 'coeur amour famille affection ami bonheur',
    P('M48 84 C6 54 12 18 33 18 C41 18 46 24 48 30 C50 24 55 18 63 18 C84 18 90 54 48 84 Z', RED) + E(30, 34, 6, 9, '#F7B8B8', 30))
add('house', 'Maison', 'maison domicile bricolage menage interieur rangement habitat',
    R(66, 20, 9, 18, N1, 2) + R(20, 46, 56, 36, Y3, 4, OUT, 3) + P('M8 52 L48 16 L88 52 Z', P2) + R(41, 60, 15, 22, N1, 3) + R(26, 56, 11, 11, B3, 2, B2, 2) + R(60, 56, 11, 11, B3, 2, B2, 2))
add('flower', 'Fleur', 'fleur jardin printemps bouquet jardinage floral',
    S('M48 50 V88', G2, 6) + E(34, 74, 12, 5, G1, -30) + E(62, 70, 12, 5, G1, 30) +
    ''.join(C(round(48 + 17 * math.cos(math.radians(a)), 1), round(34 + 17 * math.sin(math.radians(a)), 1), 11, P1) for a in range(0, 360, 60)) + C(48, 34, 10, Y1))
add('tree', 'Arbre', 'arbre foret bois nature promenade bois jardin',
    R(43, 56, 10, 30, N1, 3) + C(32, 50, 16, G1) + C(64, 50, 16, G1) + C(48, 34, 22, G1) + C(40, 28, 7, G3) + C(60, 52, 6, G2))
add('dog', 'Chien', 'chien promenade animal compagnon toutou',
    E(20, 50, 10, 20, N1, 12) + E(76, 50, 10, 20, N1, -12) + E(48, 52, 26, 24, '#E6C9A0') + E(48, 64, 15, 11, W) + E(48, 56, 7, 5, K) + C(37, 44, 4, K) + C(59, 44, 4, K) + S('M48 60 V66 M41 68 Q48 74 55 68', K, 3) + E(48, 73, 4, 3, P1))
add('paw', 'Patte', 'patte animal chien chat empreinte',
    E(48, 64, 20, 16, G2) + E(24, 44, 8, 11, G2, -20) + E(40, 30, 8, 11, G2, -6) + E(56, 30, 8, 11, G2, 6) + E(72, 44, 8, 11, G2, 20))
add('camera', 'Photo', 'photo appareil photographie image souvenir cliche',
    R(34, 20, 26, 14, G2, 4) + R(10, 28, 76, 48, G2, 9) + C(48, 53, 17, W) + C(48, 53, 12, B2) + C(44, 49, 3.5, W) + C(75, 40, 3.5, Y1))
add('cooking', 'Cuisine', 'cuisine cuisiner recette repas chef gateau plat',
    blob([(32, 34, 14), (48, 28, 15), (64, 34, 14)], W) + R(30, 40, 36, 30, W, 4) + R(30, 66, 36, 14, W, 4, OUT, 3) + L(40, 50, 40, 62, G3, 3) + L(56, 50, 56, 62, G3, 3))
add('film', 'Cinéma', 'film cinema video serie spectacle soiree tele',
    R(14, 38, 68, 42, '#5B6B63', 6) + f'<g transform="rotate(-10 14 36)">' + R(14, 22, 68, 14, N2, 3) + ''.join(P(f'M{x} 22 h8 l-6 14 h-8 z', W) for x in (22, 42, 62)) + '</g>' + P('M42 50 L62 59 L42 68 Z', Y1))
add('mountain', 'Randonnée', 'randonnee montagne sentier rando paysage nature sortie',
    C(72, 24, 9, Y1) + P('M4 82 L34 32 L52 62 L64 46 L92 82 Z', G2) + P('M34 32 L44 49 L38 46 L34 52 L28 46 L24 49 Z', W) + P('M4 82 H92 V88 H4 Z', G1))
add('calendar', 'Calendrier', 'calendrier agenda date rendez-vous planning semaine jour',
    R(14, 20, 68, 62, W, 8, OUT, 3) + P('M14 28 Q14 20 22 20 H74 Q82 20 82 28 V38 H14 Z', P2) + R(28, 12, 7, 16, N2, 3) + R(61, 12, 7, 16, N2, 3) +
    ''.join(R(22 + 15 * c, 46 + 12 * r, 10, 8, G3, 2) for r in range(3) for c in range(4) if (r, c) != (1, 2)) + R(52, 58, 10, 8, Y1, 2))
add('star', 'Étoile', 'etoile priorite favori important reussite',
    PG(star_pts(48, 52, 38, 17), Y1, Y2, 4))
add('target', 'Objectif', 'objectif cible but defi challenge mission',
    C(46, 52, 34, P2) + C(46, 52, 26, W) + C(46, 52, 18, P2) + C(46, 52, 10, W) + C(46, 52, 4, P2) + L(48, 50, 80, 18, N2, 5) + P('M72 12 L84 12 L84 24 L78 22 L74 18 Z', N2))
add('trophy', 'Trophée', 'trophee coupe victoire record medaille reussite palmares',
    S('M28 26 H16 Q14 46 32 50', Y2, 5) + S('M68 26 H80 Q82 46 64 50', Y2, 5) + P('M26 16 H70 V40 Q70 64 48 64 Q26 64 26 40 Z', Y1) + R(43, 62, 10, 12, Y2, 2) + R(30, 74, 36, 10, N1, 4) + PG(star_pts(48, 38, 11, 5), W))
add('flame', 'Flamme', 'flamme feu serie streak motivation energie',
    P('M48 6 C58 24 80 34 76 58 C74 76 62 88 48 88 C32 88 20 76 20 58 C20 44 30 36 36 22 C40 30 44 18 48 6 Z', '#F0875A') + P('M48 40 C54 52 64 56 62 68 C60 78 54 82 48 82 C40 82 34 76 34 68 C34 60 42 54 44 46 C46 50 47 44 48 40 Z', Y1))
add('timer', 'Minuteur', 'minuteur chrono temps duree horloge minutes',
    R(42, 8, 12, 9, G2, 3) + L(48, 16, 48, 22, G2, 5) + L(72, 24, 78, 18, G2, 6) + C(48, 54, 30, W, G2, 5) + P('M48 54 V28 A26 26 0 0 1 74 54 Z', G3) + L(48, 54, 48, 34, K, 5) + L(48, 54, 62, 62, K, 5) + C(48, 54, 4, K))
add('check', 'Validé', 'valide fait termine ok check reussi realise',
    C(48, 48, 38, G1) + S('M30 49 L43 62 L67 36', W, 10))
add('bulb', 'Idée', 'idee astuce conseil coach lumiere conseil',
    rays(48, 38, 30, 38, 8, Y2, 4) + C(48, 38, 22, Y1) + P('M40 54 H56 V64 H40 Z', Y3) + R(38, 62, 20, 14, N1, 4) + L(42, 82, 54, 82, N2, 5) + S('M42 44 L48 36 L54 44', W, 3.5))
add('gift', 'Cadeau', 'cadeau anniversaire surprise fete present',
    S('M48 32 Q34 8 28 22 Q26 32 48 32 Q70 32 68 22 Q62 8 48 32', Y1, 5) + R(18, 42, 60, 42, P1, 4) + R(14, 32, 68, 14, P2, 4) + R(43, 32, 10, 52, Y1, 2))
add('cake', 'Gourmandise', 'gateau dessert gourmandise cupcake anniversaire patisserie sucre',
    C(48, 20, 6, RED) + P('M20 54 Q18 34 48 32 Q78 34 76 54 Z', P3, P1, 3) + P('M22 52 H74 L68 84 H28 Z', P2) + ''.join(L(x, 56, x - 1, 80, P1, 3) for x in (36, 48, 60)))
add('watering', 'Arrosage', 'arrosage jardin arroser plantes jardinage potager',
    S('M26 44 Q40 14 54 44', B2, 5) + S('M60 56 L86 34', B2, 8) + R(20, 42, 44, 38, B1, 9) + R(78, 24, 12, 8, B2, 3) + P('M82 44 q4 8 0 12 q-4 -4 0 -12', B3) + P('M72 56 q4 8 0 12 q-4 -4 0 -12', B3))
add('sprout', 'Pousse', 'pousse plante semis potager planter jardin croissance',
    S('M48 62 V34', G2, 5) + E(34, 32, 15, 8, G1, -30) + E(63, 28, 15, 8, G1, 30) + P('M24 60 H72 L65 86 H31 Z', P2) + R(22, 56, 52, 9, P1, 3))
add('bear', 'Nounours', 'nounours ours mascotte peluche doudou coach',
    C(22, 28, 12, '#C9A27C') + C(74, 28, 12, '#C9A27C') + C(22, 28, 6, P1) + C(74, 28, 6, P1) + C(48, 54, 30, '#C9A27C') + E(48, 65, 15, 11, '#F2DDC3') + E(48, 58, 5.5, 4, K) + C(36, 46, 3.5, K) + C(60, 46, 3.5, K) + S('M48 62 V67 M42 69 Q48 74 54 69', K, 3) + E(30, 58, 5, 3, P1) + E(66, 58, 5, 3, P1))
add('sleep', 'Sieste', 'sieste repos dormir sommeil detente pause lit',
    P('M36 26 A28 28 0 1 0 56 76 A22 22 0 1 1 36 26 Z', Y1, Y2, 3) + S('M58 24 H74 L58 42 H74', G2, 5) + S('M72 10 H82 L72 22 H82', G1, 4))
add('weather', 'Météo', 'meteo temps nuage ciel pluie soleil',
    rays(62, 34, 20, 28, 8, Y2, 4) + C(62, 34, 14, Y1) + blob([(30, 62, 14), (48, 54, 18), (66, 62, 14), (48, 68, 14)], W))
add('mail', 'Message', 'message lettre courrier mail contact appel nouvelles famille',
    R(10, 24, 76, 50, W, 7, OUT, 3) + S('M12 30 L48 56 L84 30', OUT, 3) + P('M48 76 C28 62 32 48 41 48 C45 48 47 51 48 53 C49 51 51 48 55 48 C64 48 68 62 48 76 Z', RED))
add('palette', 'Peinture', 'peinture dessin art creation couleurs atelier aquarelle loisir creatif',
    P('M48 12 C24 12 8 30 10 50 C12 70 30 84 50 82 C60 81 58 72 64 70 C74 68 86 68 88 54 C90 30 72 12 48 12 Z', '#E9C99B', N1, 3) + C(30, 36, 7, P2) + C(50, 26, 7, Y1) + C(70, 36, 7, G1) + C(28, 58, 7, B1) + C(62, 56, 5, W))
add('yarn', 'Tricot', 'tricot laine couture aiguilles loisir creatif ouvrage broderie',
    C(44, 54, 28, LV) + S('M20 46 Q44 62 68 40 M18 60 Q44 76 70 56 M30 32 Q48 48 62 30', LV2, 3) + S('M70 76 Q82 84 88 70', LV2, 3) + L(56, 12, 86, 44, N1, 4) + C(56, 12, 4, N2))
add('headphones', 'Écoute', 'ecoute casque musique podcast radio audio',
    S('M20 56 V48 A28 28 0 0 1 76 48 V56', '#6A7A72', 7) + R(12, 50, 18, 30, G2, 8) + R(66, 50, 18, 30, G2, 8) + R(24, 54, 6, 22, G1, 3) + R(66, 54, 6, 22, G1, 3))
add('suitcase', 'Voyage', 'voyage valise vacances week-end sejour escapade',
    S('M36 34 V26 Q36 18 44 18 H52 Q60 18 60 26 V34', N2, 5) + R(12, 32, 72, 50, P2, 9) + R(28, 32, 6, 50, N2, 2) + R(62, 32, 6, 50, N2, 2) + C(48, 58, 8, Y1))
add('restaurant', 'Repas', 'repas restaurant diner dejeuner manger table cuisine sortie',
    C(48, 50, 28, W, OUT, 3) + C(48, 50, 17, 'none', OUT, 2) + ''.join(L(x, 14, x, 34, N1, 3) for x in (10, 15, 20)) + S('M10 34 Q15 44 20 34', N1, 3) + L(15, 42, 15, 84, N1, 4) + P('M78 14 C90 22 90 42 78 52 Z', N1) + L(78, 14, 78, 84, N1, 4))
add('broom', 'Ménage', 'menage balai nettoyage entretien rangement propre',
    L(70, 10, 46, 56, N1, 6) + f'<g transform="rotate(28 40 70)">' + P('M26 58 H54 L58 86 H22 Z', Y2) + ''.join(L(x, 66, x - 1, 84, Y1, 3) for x in (30, 38, 46)) + '</g>' + PG(star_pts(80, 40, 7, 3), Y1) + PG(star_pts(16, 34, 5, 2.2), G1))
add('notebook', 'Journal', 'journal carnet notes ecrire bilan historique cahier',
    R(20, 10, 54, 76, G1, 7) + R(20, 10, 12, 76, G2, 6) + L(42, 30, 64, 30, W, 3.5) + L(42, 42, 64, 42, W, 3.5) + L(42, 54, 58, 54, W, 3.5) +
    f'<g transform="rotate(32 76 56)">' + R(70, 22, 11, 46, Y1, 3) + P('M70 68 H81 L75.5 80 Z', P3) + R(70, 22, 11, 8, P2, 3) + '</g>')
add('pin', 'Lieu', 'lieu endroit adresse localisation carte sortie position',
    E(48, 86, 18, 3, G3) + P('M48 84 C20 54 24 12 48 12 C72 12 76 54 48 84 Z', P2) + C(48, 38, 12, W))
add('leaf', 'Feuille', 'feuille nature ecologie bien-etre plante vert',
    P('M16 78 C10 34 42 10 84 12 C86 52 64 82 16 78 Z', G1) + S('M16 78 Q42 50 66 30', G3, 4) + S('M40 56 L40 38 M52 46 L64 48', G3, 3))
add('smile', 'Bonne humeur', 'humeur ressenti sourire content bien emotion plaisir',
    C(48, 48, 38, Y1) + C(35, 40, 5, K) + C(61, 40, 5, K) + S('M30 58 Q48 76 66 58', K, 5) + E(26, 56, 6, 4, P1) + E(70, 56, 6, 4, P1))

def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">{body}</svg>'
if __name__ == '__main__':
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, 'assets', 'icons', 'pack'); src = os.path.join(root, 'tools', 'icon_pack_src')
    os.makedirs(out, exist_ok=True); os.makedirs(src, exist_ok=True)
    for i, (label, kw, body) in I.items():
        open(os.path.join(src, i + '.svg'), 'w', encoding='utf-8').write(svg(body))
        cairosvg.svg2png(bytestring=svg(body).encode(), write_to=os.path.join(out, i + '.png'), output_width=192, output_height=192)
    # table Dart : id, libellé, mots-clés
    lines = ["  _PackIcon('%s', '%s', '%s')," % (i, l.replace("'", "’"), k) for i, (l, k, _) in I.items()]
    open(os.path.join(root, 'tools', 'icon_pack_table.txt'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    print(len(I), 'icônes générées')
