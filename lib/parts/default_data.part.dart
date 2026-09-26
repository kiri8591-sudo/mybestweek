part of '../main.dart';

// V9.06 — Données initiales de l'application.
// Extraction architecturale uniquement : comportement conservé.

List<Activity> _defaultActivities() => [
        // Programme générique : les journées « Sport » sont ensuite déclinées
        // automatiquement à partir de la liste ci-dessous.
        Activity(
          id: 'sport',
          name: 'Sport',
          emoji: '🏃',
          category: 'Sport',
          duration: 120,
          frequency: 3,
          priority: 5,
          preferredDays: [0, 1, 3],
          sportWeight: 10,
          sportDailyDurations: const {0: 120, 1: 120, 3: 120},
          isSportProgram: true,
        ),

        // TAI CHI — 30 min, 2 fois/semaine, en alternance.
        Activity(id: 'sport-tai-chi-fit-to-go', name: 'Tai Chi Fit to go — David Dorian Ross', emoji: '🧘', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'tai-chi-fit', sportGroupFrequency: 2),
        Activity(id: 'sport-tai-chi-fit-flow', name: 'Tai Chi Fit Flow — David Dorian Ross', emoji: '🧘', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'tai-chi-fit', sportGroupFrequency: 2),
        Activity(id: 'sport-tai-chi-fit-strength', name: 'Tai Chi Fit strength — David Dorian Ross', emoji: '🧘', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'tai-chi-fit', sportGroupFrequency: 2),
        Activity(id: 'sport-tai-chi-fit-over-50', name: 'Tai Chi Fit over 50 — David Dorian Ross', emoji: '🧘', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'tai-chi-fit', sportGroupFrequency: 2),

        // QI GONG — 30 min, 2 fois/semaine, en alternance.
        Activity(id: 'sport-qi-energy', name: 'Qi Gong for energy — Lee Holden', emoji: '🌿', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'qi-gong', sportGroupFrequency: 2),
        Activity(id: 'sport-qi-anxiety', name: 'Qi Gong for anxiety — Lee Holden', emoji: '🌿', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'qi-gong', sportGroupFrequency: 2),
        Activity(id: 'sport-qi-upper-back', name: 'Qi Gong for upper back — Lee Holden', emoji: '🌿', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'qi-gong', sportGroupFrequency: 2),
        Activity(id: 'sport-qi-introduction', name: 'Qi Gong introduction — Lee Holden', emoji: '🌿', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'qi-gong', sportGroupFrequency: 2),
        Activity(id: 'sport-qi-healthy-joints', name: 'Qi Gong for healthy joints — Lee Holden', emoji: '🌿', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'qi-gong', sportGroupFrequency: 2),

        // YANG TAI CHI — 30 min, 1 fois/semaine. Part 2 reste volontairement
        // dans la rotation mais sera favorisée plus tard par l’historique.
        Activity(id: 'sport-yang-tai-chi-part-1', name: 'Yang tai chi part 1', emoji: '☯️', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'yang-tai-chi', sportGroupFrequency: 1),
        Activity(id: 'sport-yang-tai-chi-part-2', name: 'Yang tai chi part 2 — plus tard', emoji: '☯️', category: 'Sport', duration: 30, frequency: 1, priority: 2, sportWeight: 3, sportGroup: 'yang-tai-chi', sportGroupFrequency: 1, activeInSportRotation: false),

        // ROUTINES COURTES — fréquence propre respectée indépendamment des
        // journées Sport composites.
        Activity(id: 'sport-bluetens', name: 'Bluetens session', emoji: '⚡', category: 'Sport', duration: 10, frequency: 7, priority: 4, sportWeight: 6),
        Activity(id: 'sport-betterme', name: 'BetterMe session', emoji: '💪', category: 'Sport', duration: 30, frequency: 2, priority: 4, sportWeight: 7),
        Activity(id: 'sport-fiton', name: 'Fit On session', emoji: '🏋️', category: 'Sport', duration: 30, frequency: 2, priority: 4, sportWeight: 7),
        Activity(id: 'sport-yoga', name: 'Yoga et yoga Égyptien session', emoji: '🧘', category: 'Sport', duration: 30, frequency: 2, priority: 4, sportWeight: 7),
        Activity(id: 'sport-weasyo', name: 'Weasyo session', emoji: '🤸', category: 'Sport', duration: 15, frequency: 5, priority: 4, sportWeight: 6),
        Activity(id: 'sport-seven-minutes-chi', name: '7 minutes chi', emoji: '🌿', category: 'Sport', duration: 10, frequency: 7, priority: 4, sportWeight: 6),
        Activity(id: 'sport-foodvisor-gym', name: 'Foodvisor gym session', emoji: '🏋️', category: 'Sport', duration: 20, frequency: 2, priority: 4, sportWeight: 7),
        Activity(id: 'sport-meditation', name: 'Méditation', emoji: '🧘', category: 'Sport', duration: 10, frequency: 7, priority: 3, sportWeight: 5),
        Activity(id: 'sport-coherence', name: 'Cohérence cardiaque', emoji: '💗', category: 'Sport', duration: 10, frequency: 3, priority: 3, sportWeight: 5),
        Activity(id: 'sport-bike-cotignac', name: 'Vélo appartement à Cotignac', emoji: '🚴', category: 'Sport', duration: 30, frequency: 5, priority: 5, sportWeight: 8),
        Activity(id: 'sport-nordic-walk', name: 'Marche Nordique', emoji: '🥾', category: 'Sport', duration: 45, frequency: 3, priority: 5, sportWeight: 9),
        Activity(id: 'sport-kegel', name: 'Kegel exercices', emoji: '🌸', category: 'Sport', duration: 10, frequency: 7, priority: 3, sportWeight: 4),
        Activity(id: 'sport-five-tibetan', name: '5 Tibétain', emoji: '☀️', category: 'Sport', duration: 15, frequency: 3, priority: 4, sportWeight: 6),
        Activity(id: 'sport-pushup-abs', name: 'Challenge pompes et abdos · 10 → 100 répétitions', emoji: '💪', category: 'Sport', duration: 15, frequency: 3, priority: 4, sportWeight: 7),

        // Autres activités de la semaine.
        Activity(
          id: 'piano',
          name: 'Piano',
          emoji: '🎹',
          category: 'Loisir',
          period: 'Après-midi',
          duration: 120,
          frequency: 5,
          priority: 5,
          preferredDays: [0, 1, 2, 3, 4],
        ),
        Activity(
          id: 'reading',
          name: 'Lecture',
          emoji: '📖',
          category: 'Culture',
          period: 'Soir',
          duration: 45,
          frequency: 6,
          priority: 3,
        ),
        Activity(
          id: 'market',
          name: 'Marché de Sarlat',
          emoji: '🧺',
          category: 'Sortie',
          period: 'Matin',
          duration: 90,
          frequency: 1,
          priority: 3,
          preferredDays: [2],
        ),
        Activity(
          id: 'friends',
          name: 'Moment convivial',
          emoji: '🥂',
          category: 'Social',
          period: 'Soir',
          duration: 120,
          frequency: 1,
          priority: 4,
          preferredDays: [5],
        ),
      ];
