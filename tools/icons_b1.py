# Lot 1 : sport, bien-être, maison & jardin, nature & animaux
import math
from build_icon_pack import *
import build_icon_pack as B
FUR, FUR2, STEEL, STEEL2 = '#C9A27C', '#A97F5A', '#9AB0BA', '#6F8794'
ORANGE = '#F0875A'
def clip(i, shape, inner): return f'<clipPath id="{i}">{shape}</clipPath><g clip-path="url(#{i})">{inner}</g>'
def pent(cx, cy, r, f):
    return PG(' '.join(f'{cx + r*math.cos(math.radians(-90+72*k)):.1f},{cy + r*math.sin(math.radians(-90+72*k)):.1f}' for k in range(5)), f)
def flame(cx, cy, s=1.0):
    return (f'<g transform="translate({cx} {cy}) scale({s}) translate(-48 -48)">' +
            P('M48 10 C58 28 74 36 70 58 C68 74 58 84 48 84 C36 84 26 74 26 58 C26 46 34 38 38 26 C42 32 45 22 48 10 Z', ORANGE) +
            P('M48 44 C54 54 60 58 58 68 C57 76 52 80 48 80 C42 80 38 76 38 68 C38 62 44 56 46 50 Z', Y1) + '</g>')

# ---------- Sport ----------
add('petanque', 'Pétanque', 'petanque boules cochonnet jeu de boules apero sortie',
    ground() + C(34, 60, 24, STEEL, STEEL2, 3) + S('M16 54 Q34 44 52 54', STEEL2, 3) + S('M18 68 Q34 78 50 68', STEEL2, 3) + S('M24 46 Q30 42 38 43', W, 4) +
    C(72, 70, 15, '#B7C6CD', STEEL2, 3) + S('M62 64 Q72 58 82 64', STEEL2, 3) + C(76, 34, 8, Y1, Y2, 2.5), 'Sport')
add('tennis', 'Tennis', 'tennis raquette balle sport jeu',
    clip('tn', '<ellipse cx="38" cy="38" rx="24" ry="29" transform="rotate(35 38 38)"/>',
         ''.join(L(x, -10, x, 110, G3, 2.5) for x in range(14, 66, 8)) + ''.join(L(-10, y, 110, y, G3, 2.5) for y in range(6, 72, 8))) +
    E(38, 38, 24, 29, 'none', 35, G2, 6) + L(56, 62, 76, 86, N1, 9) + L(60, 66, 66, 60, N2, 5) +
    C(74, 24, 12, '#D5E06B') + S('M65 18 Q73 26 83 21', W, 3) + S('M65 31 Q75 24 83 30', W, 3), 'Sport')
add('golf', 'Golf', 'golf drapeau trou balle parcours green',
    E(48, 82, 40, 9, G1) + E(48, 80, 40, 7, G2) + L(54, 12, 54, 78, N2, 4) + PG('54,12 82,24 54,38', P2) + C(30, 76, 6, W, OUT, 2) + E(54, 79, 8, 2.5, K), 'Sport')
add('dance', 'Danse', 'danse dancer bal musique soiree rythme',
    ground() + C(46, 18, 9, P1) + S('M46 28 L46 40', P1, 8) + P('M46 34 L28 66 Q46 74 64 66 Z', P2) + S('M42 36 L26 22', P1, 6) + S('M52 38 L70 48', P1, 6) + S('M38 68 L34 86', P1, 7) + S('M56 68 L64 84', P1, 7) +
    PG(star_pts(78, 22, 7, 3), Y1) + E(82, 36, 4, 3, G2) + L(86, 36, 86, 22, G2, 2.5), 'Sport')
add('football', 'Football', 'football foot ballon sport match',
    C(48, 48, 36, W, K, 3.5) + pent(48, 48, 12, K) + ''.join(L(round(48 + 12 * math.cos(math.radians(-90 + 72 * k)), 1), round(48 + 12 * math.sin(math.radians(-90 + 72 * k)), 1),
        round(48 + 30 * math.cos(math.radians(-90 + 72 * k)), 1), round(48 + 30 * math.sin(math.radians(-90 + 72 * k)), 1), K, 3) for k in range(5)) +
    ''.join(pent(round(48 + 33 * math.cos(math.radians(-90 + 72 * k + 36)), 1), round(48 + 33 * math.sin(math.radians(-90 + 72 * k + 36)), 1), 5, K) for k in range(5)), 'Sport')

# ---------- Bien-être ----------
add('spa', 'Bain détente', 'bain baignoire spa detente relaxation douche bulles',
    C(30, 34, 10, B3, B1, 2.5) + C(48, 22, 13, B3, B1, 2.5) + C(64, 36, 8, B3, B1, 2.5) + C(76, 24, 5, B3, B1, 2) +
    P('M10 50 H86 Q86 78 68 78 H28 Q10 78 10 50 Z', W, OUT, 3) + R(10, 46, 76, 8, G1, 4) + L(24, 78, 22, 86, N1, 5) + L(72, 78, 74, 86, N1, 5), 'Bien-être')
add('stones', 'Galets zen', 'galets pierres zen massage equilibre detente meditation',
    E(48, 76, 34, 11, '#9AA7A2') + E(48, 58, 26, 10, '#B7C2BC') + E(48, 43, 18, 8, '#8A9791') + E(48, 31, 11, 6, '#CBD3CE') + E(44, 71, 14, 3, '#B8C4BE') + S('M62 24 Q74 14 80 22 Q74 28 62 24', G1, 4), 'Bien-être')
add('tea', 'Thé', 'the tisane infusion theiere boisson pause',
    S('M36 24 q-5 -6 0 -11', G1, 4) + S('M48 22 q-5 -6 0 -11', G1, 4) + R(34, 28, 22, 8, P1, 4) + C(45, 26, 4, Y1) +
    S('M18 50 Q6 54 16 70', P2, 6) + P('M64 48 Q88 44 84 26 Q76 40 62 40 Z', P2) + E(44, 58, 28, 22, P2) + E(40, 52, 12, 6, P1, -20) + R(26, 78, 38, 6, N1, 3), 'Bien-être')
add('candle', 'Bougie', 'bougie ambiance detente relaxation soiree lumiere',
    E(48, 86, 28, 5, G3) + R(36, 42, 24, 42, Y3, 4, Y2, 2.5) + L(48, 30, 48, 42, N2, 3) + P('M48 8 Q62 26 48 38 Q34 26 48 8 Z', ORANGE) + P('M48 20 Q54 28 48 35 Q42 28 48 20 Z', Y1), 'Bien-être')
add('health', 'Santé', 'sante medecin rendez-vous docteur soin pharmacie consultation',
    R(34, 12, 28, 72, RED, 9) + R(12, 34, 72, 28, RED, 9) + S('M20 48 H36 L42 36 L52 60 L58 48 H76', W, 4), 'Bien-être')
add('water', 'Eau', 'eau hydratation boire goutte pluie verre',
    P('M48 8 C48 8 20 42 20 60 A28 28 0 0 0 76 60 C76 42 48 8 48 8 Z', B1, B2, 3) + S('M34 62 Q36 72 45 76', W, 4.5), 'Bien-être')

# ---------- Maison & jardin ----------
add('mower', 'Tondeuse', 'tondeuse pelouse gazon jardin tonte robot',
    S('M20 82 q2 -9 5 0 M34 84 q2 -8 5 0 M72 84 q2 -9 5 0', G1, 3) + S('M68 40 L84 14', N2, 5) + L(78, 14, 92, 14, N2, 5) +
    P('M14 62 Q14 40 40 40 H70 V62 Z', P2) + R(14, 58, 60, 10, P1, 4) + C(28, 72, 11, '#5B6B63') + C(28, 72, 4, G3) + C(64, 72, 11, '#5B6B63') + C(64, 72, 4, G3) + R(34, 33, 16, 8, N2, 3), 'Maison & jardin')
add('hammer', 'Bricolage', 'bricolage marteau outil reparation travaux atelier',
    f'<g transform="rotate(40 48 48)">' + R(43, 30, 10, 58, N1, 4) + R(22, 14, 52, 20, STEEL, 5) + R(22, 14, 14, 20, STEEL2, 5) + R(60, 14, 14, 20, STEEL2, 5) + '</g>', 'Maison & jardin')
add('roller', 'Peinture murs', 'peinture rouleau murs travaux renovation decoration',
    R(12, 14, 62, 22, P2, 9) + R(12, 14, 62, 8, P1, 4) + S('M74 26 H84 V50 H50 V60', STEEL2, 5) + R(44, 58, 12, 28, N1, 5) + P('M20 36 q2 10 5 0 M40 36 q2 14 5 0', P1), 'Maison & jardin')
add('firewood', 'Bois de chauffage', 'bois buches chauffage cheminee hiver stockage fendre',
    R(12, 58, 72, 22, N1, 11) + R(12, 34, 72, 22, '#A07B5A', 11) + C(24, 69, 10, Y3, N2, 2.5) + C(24, 69, 5, 'none', N1, 2) + C(24, 45, 10, Y3, N2, 2.5) + C(24, 45, 5, 'none', N1, 2) + L(44, 40, 76, 40, N2, 2.5) + L(40, 64, 72, 64, '#6E5848', 2.5) + P('M60 24 Q70 12 78 22 Q70 22 60 24', G1), 'Maison & jardin')
add('fireplace', 'Cheminée', 'cheminee feu foyer hiver soiree chaleur',
    R(8, 14, 80, 12, N2, 3) + R(14, 24, 68, 62, '#B5705C', 4) + ''.join(L(14, y, 82, y, '#8F5546', 2) for y in (38, 52, 66, 80)) + P('M28 86 V52 Q28 34 48 34 Q68 34 68 52 V86 Z', '#3F3A36') + flame(48, 66, .5), 'Maison & jardin')
add('laundry', 'Lessive', 'lessive linge machine laver menage buanderie',
    R(18, 10, 60, 78, W, 8, OUT, 3) + L(18, 28, 78, 28, OUT, 2.5) + C(30, 19, 3.5, P2) + C(42, 19, 3.5, Y1) + C(48, 58, 22, B3, B2, 4) + S('M34 60 Q42 50 48 58 T62 56', W, 3.5), 'Maison & jardin')
add('vacuum', 'Aspirateur robot', 'aspirateur robot menage nettoyage sol poussiere',
    C(48, 52, 36, W, OUT, 3) + C(48, 52, 27, '#DDE7E2') + C(48, 52, 10, G2) + C(48, 52, 4, W) + S('M22 30 Q30 22 40 20', G1, 4) + S('M70 80 q8 -6 14 0', G3, 3), 'Maison & jardin')
add('rake', 'Râteau', 'rateau jardin feuilles automne ramasser nettoyer',
    L(48, 8, 48, 62, N1, 6) + R(18, 58, 60, 8, STEEL, 3) + ''.join(L(x, 66, x, 84, STEEL2, 4) for x in (24, 36, 48, 60, 72)) + E(80, 82, 8, 4, ORANGE, -20) + E(14, 80, 7, 3.5, Y2, 20), 'Maison & jardin')
add('wheelbarrow', 'Brouette', 'brouette jardin terre transport compost travaux',
    E(46, 34, 26, 8, '#8B735E') + P('M14 36 H78 L66 66 H30 Z', G2) + S('M70 40 L90 28', N1, 6) + L(40, 66, 30, 86, N1, 5) + L(66, 62, 74, 86, N1, 5) + C(28, 74, 12, '#5B6B63') + C(28, 74, 4, G3), 'Maison & jardin')
add('greenhouse', 'Serre', 'serre potager culture semis jardin tomates',
    P('M10 84 V46 L48 14 L86 46 V84 Z', B3, B2, 3) + L(48, 14, 48, 84, B2, 2.5) + L(10, 46, 86, 46, B2, 2.5) + L(29, 30, 29, 84, B2, 2) + L(67, 30, 67, 84, B2, 2) + C(24, 76, 7, G1) + C(36, 78, 6, G2) + C(60, 77, 7, G1) + C(72, 77, 6, P2), 'Maison & jardin')

# ---------- Nature & animaux ----------
add('deer', 'Cerf', 'cerf chevreuil biche faune foret animal sauvage',
    S('M38 40 Q30 22 20 18 M30 29 Q22 28 16 22 M58 40 Q66 22 76 18 M66 29 Q74 28 80 22', N2, 4.5) + E(28, 48, 10, 5, FUR, -35) + E(68, 48, 10, 5, FUR, 35) + E(48, 58, 17, 24, FUR) + E(48, 74, 9, 7, '#F2DDC3') + C(48, 77, 4, K) + C(41, 56, 3.5, K) + C(55, 56, 3.5, K), 'Nature & animaux')
add('bird', 'Oiseau', 'oiseau rouge-gorge mesange faune jardin nid chant',
    L(10, 80, 86, 80, N1, 5) + S('M20 78 Q30 72 40 78', G1, 4) + E(48, 52, 26, 22, FUR2) + C(70, 40, 14, FUR2) + E(52, 58, 15, 14, ORANGE) + P('M82 38 L94 42 L82 46 Z', Y1) + C(72, 37, 3, K) + P('M22 50 L8 40 L10 58 Z', FUR2) + L(44, 74, 44, 80, Y2, 3) + L(56, 74, 56, 80, Y2, 3), 'Nature & animaux')
add('owl', 'Hibou', 'hibou chouette nuit faune foret oiseau',
    PG('22,26 36,34 26,44', FUR2) + PG('74,26 60,34 70,44', FUR2) + E(48, 54, 28, 32, FUR2) + E(48, 64, 17, 20, '#F2DDC3') + C(36, 44, 12, W, K, 2.5) + C(60, 44, 12, W, K, 2.5) + C(36, 44, 5, K) + C(60, 44, 5, K) + PG('48,48 43,56 53,56', Y1) +
    S('M40 66 q4 3 8 0 M48 66 q4 3 8 0 M44 74 q4 3 8 0', FUR, 2.5) + L(22, 86, 74, 86, N1, 5), 'Nature & animaux')
add('squirrel', 'Écureuil', 'ecureuil faune foret noisette animal arbre',
    P('M52 84 Q92 78 86 40 Q82 18 62 22 Q74 36 66 54 Q60 68 52 70 Z', '#C9784F') + P('M60 26 Q72 30 74 46', '#E0A47F') + E(38, 66, 17, 22, '#C9784F') + E(34, 72, 9, 12, '#F2DDC3') + C(34, 40, 13, '#C9784F') + PG('24,32 28,16 36,28', '#C9784F') + PG('38,30 46,16 48,32', '#C9784F') + C(30, 40, 3, K) + E(26, 46, 3, 2.5, K) + C(46, 66, 6, FUR) + P('M42 62 q4 -5 8 0', N2), 'Nature & animaux')
def spikes():
    pts = []
    n = 14
    for k in range(n + 1):
        a = math.radians(180 + 180 * k / n)
        pts.append((48 + 38 * math.cos(a), 74 + 44 * math.sin(a)))
        a2 = math.radians(180 + 180 * (k + .5) / n)
        if k < n: pts.append((48 + 28 * math.cos(a2), 74 + 33 * math.sin(a2)))
    return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
add('hedgehog', 'Hérisson', 'herisson faune jardin animal nuit automne',
    P('M10 76 Q10 30 52 30 Q86 30 88 76 Z', '#8B735E', N2, 2.5) + P(spikes(), '#8B735E', N2, 2) + P('M8 78 Q12 52 34 54 Q44 66 34 78 Z', '#F2DDC3') + C(14, 70, 4, K) + C(26, 62, 3, K) + ''.join(L(x, 72, x - 1, 84, N2, 4) for x in (40, 62)), 'Nature & animaux')
add('fox', 'Renard', 'renard faune foret animal sauvage roux',
    P('M10 14 L36 32 H60 L86 14 L84 54 Q48 96 12 54 Z', '#E8924F') + P('M14 52 Q48 92 82 52 Q62 62 48 48 Q34 62 14 52 Z', W) + PG('14,18 30,30 16,40', K) + PG('82,18 66,30 80,40', K) + C(48, 74, 5, K) + C(34, 46, 3.5, K) + C(62, 46, 3.5, K), 'Nature & animaux')
add('butterfly', 'Papillon', 'papillon insecte jardin printemps fleurs nature',
    E(30, 32, 22, 18, P1, -30) + E(66, 32, 22, 18, P1, 30) + E(32, 62, 16, 14, B1, 25) + E(64, 62, 16, 14, B1, -25) + C(26, 30, 6, W) + C(70, 30, 6, W) + R(44, 22, 8, 56, N2, 4) + S('M46 24 Q40 10 32 8 M50 24 Q56 10 64 8', N2, 3), 'Nature & animaux')
add('bee', 'Abeille', 'abeille miel ruche pollen jardin insecte butinage',
    E(30, 32, 16, 10, B3, -30, B1, 2.5) + E(52, 26, 16, 10, B3, 20, B1, 2.5) + E(50, 56, 26, 20, Y1) + R(40, 38, 8, 36, K, 3) + R(54, 38, 8, 36, K, 3) + C(24, 56, 11, K) + C(20, 54, 2.5, W) + PG('76,56 90,56 76,62', K) + S('M18 46 Q12 38 8 40', K, 2.5), 'Nature & animaux')
add('mushroom', 'Champignon', 'champignon cepe cueillette foret automne bois ceuillette',
    P('M34 50 H62 Q68 84 60 86 H36 Q28 84 34 50 Z', '#F2DDC3', N1, 2.5) + P('M10 52 Q10 14 48 14 Q86 14 86 52 Q86 58 80 58 H16 Q10 58 10 52 Z', '#B5703F') + E(36, 30, 10, 5, '#D79B6B', -25) + E(24, 88, 14, 3, G1) + P('M70 86 q4 -10 8 0', G1, None), 'Nature & animaux')
add('walnut', 'Noix', 'noix noyer perigord recolte automne fruit sec',
    E(48, 54, 29, 32, FUR, None) + E(48, 54, 29, 32, 'none', 0, N1, 3) + S('M48 22 Q40 54 48 86', N1, 3) + S('M30 40 Q36 46 32 56 M64 40 Q58 46 62 58', N1, 2.5) + E(34, 36, 7, 4, '#E6CBA4', -30) + P('M62 24 Q76 8 88 16 Q80 28 62 24', G1) + L(62, 24, 78, 18, G2, 2), 'Nature & animaux')
add('sunflower', 'Tournesol', 'tournesol fleur ete jardin champ soleil',
    S('M48 56 V90', G2, 6) + E(32, 76, 14, 5, G1, -25) + ''.join(E(round(48 + 28 * math.cos(math.radians(a)), 1), round(36 + 28 * math.sin(math.radians(a)), 1), 11, 5.5, Y1, a) for a in range(0, 360, 30)) + C(48, 36, 17, '#7A5A3A') + C(42, 30, 3, '#5E4A3E') + C(54, 32, 3, '#5E4A3E') + C(46, 42, 3, '#5E4A3E') + C(55, 42, 3, '#5E4A3E'), 'Nature & animaux')
add('cat', 'Chat', 'chat animal compagnon felin maison',
    PG('18,16 38,30 20,46', '#B8A99A') + PG('78,16 58,30 76,46', '#B8A99A') + PG('21,24 33,32 23,40', P1) + PG('75,24 63,32 73,40', P1) + E(48, 56, 32, 28, '#B8A99A') + S('M40 34 L42 44 M48 32 V42 M56 34 L54 44', '#8F8174', 3) + E(35, 54, 5, 6, '#6B8E5A') + E(61, 54, 5, 6, '#6B8E5A') + E(35, 54, 1.8, 5, K) + E(61, 54, 1.8, 5, K) + PG('44,64 52,64 48,69', P2) +
    S('M48 69 V73 M42 74 Q48 78 54 74', K, 2.5) + L(10, 66, 28, 68, '#8F8174', 2) + L(10, 74, 28, 72, '#8F8174', 2) + L(86, 66, 68, 68, '#8F8174', 2) + L(86, 74, 68, 72, '#8F8174', 2), 'Nature & animaux')
