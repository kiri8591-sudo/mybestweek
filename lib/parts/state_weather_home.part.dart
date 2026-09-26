// V8.93 — Météo, éphéméride et identité de l’accueil
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _WeatherHomePart on _MaBelleSemaineAppState {
  String _dayMoment() {
    final hour = _clockNow.hour;
    if (hour < 12) return 'Bon matin ☀️';
    if (hour < 18) return 'Bon après-midi 🌿';
    if (hour < 22) return 'Bonne soirée 🌙';
    return 'Bonne nuit ✨';
  }

  String _clockText() {
    final h = _clockNow.hour.toString().padLeft(2, '0');
    final m = _clockNow.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _loadTodayNameday() async {
    final key = _todayDateKey();
    if (_todayNamedayDateKey == key && _todayNameday.trim().isNotEmpty) return;
    try {
      final d = DateTime.now();
      final url = Uri.parse('https://nominis.cef.fr/json/nominis.php?jour=${d.day}&mois=${d.month}&annee=${d.year}');
      final raw = await html.HttpRequest.getString(url.toString());
      final root = jsonDecode(raw);
      String value = '';
      if (root is Map) {
        final response = root['response'];
        if (response is Map) {
          final prenoms = response['prenoms'];
          if (prenoms is Map) {
            final majeurs = prenoms['majeurs'];
            if (majeurs is Map) value = majeurs.keys.take(3).join(', ');
          }
          if (value.isEmpty) {
            final saints = response['saints'];
            if (saints is Map) {
              final majeurs = saints['majeurs'];
              if (majeurs is Map) value = majeurs.keys.take(2).join(', ');
            }
          }
        }
      }
      if (value.isEmpty) value = 'Pas de fête répertoriée';
      if (!mounted) return;
      setState(() {
        _todayNameday = value;
        _todayNamedayDateKey = key;
      });
      _queueLocalStatePersist();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _todayNameday = 'Éphéméride indisponible';
        _todayNamedayDateKey = key;
      });
      _queueLocalStatePersist();
    }
  }

  String _weatherLabelForCode(int code) {
    if (code == 0) return 'Ciel dégagé';
    if (code == 1 || code == 2) return 'Éclaircies';
    if (code == 3) return 'Couvert';
    if (code == 45 || code == 48) return 'Brouillard';
    if (code >= 51 && code <= 57) return 'Bruine';
    if (code >= 61 && code <= 67) return 'Pluie';
    if (code >= 71 && code <= 77) return 'Neige';
    if (code >= 80 && code <= 82) return 'Averses';
    if (code >= 95 && code <= 99) return 'Orage';
    return 'Météo variable';
  }

  String _weatherIconForCode(int code) {
    if (code == 0) return '☀️';
    if (code == 1 || code == 2) return '🌤️';
    if (code == 3) return '☁️';
    if (code == 45 || code == 48) return '🌫️';
    if (code >= 51 && code <= 67) return '🌧️';
    if (code >= 71 && code <= 77) return '❄️';
    if (code >= 80 && code <= 82) return '🌦️';
    if (code >= 95 && code <= 99) return '⛈️';
    return '🌤️';
  }

  String _weatherDateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  _DayWeather _dayWeatherFromCode(int code, String temperature) {
    final text = _weatherLabelForCode(code);
    final icon = _weatherIconForCode(code);
    final low = text.toLowerCase();
    final outdoorBad = low.contains('pluie') || low.contains('averse') || low.contains('orage') || low.contains('neige') || low.contains('bruine');
    return _DayWeather(icon: icon, text: text, temperature: temperature, outdoorBad: outdoorBad);
  }

  _DayWeather? _weatherForWeekDay(int day) {
    final date = _weekDateForDay(day);
    return _weatherForecast[_weatherDateKey(date)];
  }

  Future<void> _loadWeather() async {
    final city = _weatherCity.trim();
    if (city.isEmpty) return;
    if (mounted) setState(() { _weatherLoading = true; _weatherError = ''; });
    try {
      final geoUrl = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeQueryComponent(city)}&count=1&language=fr&format=json');
      final geoRaw = await html.HttpRequest.getString(geoUrl.toString());
      final geo = jsonDecode(geoRaw);
      final results = geo is Map ? geo['results'] : null;
      if (results is! List || results.isEmpty || results.first is! Map) throw Exception('Ville introuvable');
      final place = results.first as Map;
      final latitude = place['latitude'];
      final longitude = place['longitude'];
      final resolvedName = '${place['name'] ?? city}';
      if (latitude is! num || longitude is! num) throw Exception('Coordonnées indisponibles');

      final weatherUrl = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,precipitation_probability_max&forecast_days=7&timezone=auto');
      final weatherRaw = await html.HttpRequest.getString(weatherUrl.toString());
      final weather = jsonDecode(weatherRaw);
      final current = weather is Map ? weather['current'] : null;
      final daily = weather is Map ? weather['daily'] : null;
      if (current is! Map || daily is! Map) throw Exception('Météo indisponible');
      final temp = current['temperature_2m'];
      final code = current['weather_code'];
      if (temp is! num || code is! num) throw Exception('Données météo incomplètes');

      final forecastDates = daily['time'];
      final forecastCodes = daily['weather_code'];
      final forecastTemps = daily['temperature_2m_max'];
      final forecastRain = daily['precipitation_probability_max'];
      final nextForecast = <String, _DayWeather>{};
      if (forecastDates is List && forecastCodes is List && forecastTemps is List) {
        final count = [forecastDates.length, forecastCodes.length, forecastTemps.length].reduce((a, b) => a < b ? a : b);
        for (var i = 0; i < count && i < 7; i++) {
          final ds = '${forecastDates[i]}';
          final c = forecastCodes[i];
          final t = forecastTemps[i];
          if (c is! num || t is! num) continue;
          nextForecast[ds] = _dayWeatherFromCode(c.toInt(), '${t.round()}°');
        }
      }

      // La probabilité de pluie ne remplace pas le code météo, mais renforce
      // le signal d'alerte pour les messages destinés aux activités extérieures.
      if (forecastDates is List && forecastCodes is List && forecastTemps is List && forecastRain is List) {
        final count = [forecastDates.length, forecastCodes.length, forecastTemps.length, forecastRain.length].reduce((a, b) => a < b ? a : b);
        for (var i = 0; i < count && i < 7; i++) {
          final ds = '${forecastDates[i]}';
          final rain = forecastRain[i];
          final existing = nextForecast[ds];
          if (existing != null && rain is num && rain.toInt() >= 60 && !existing.outdoorBad) {
            nextForecast[ds] = _DayWeather(icon: '🌦️', text: '${existing.text} · risque d’averses', temperature: existing.temperature, outdoorBad: true);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _weatherCity = resolvedName;
        _weatherTemperature = '${temp.round()}°';
        _weatherIcon = _weatherIconForCode(code.toInt());
        _weatherText = _weatherLabelForCode(code.toInt());
        _weatherError = '';
        _weatherLoading = false;
        _weatherForecast
          ..clear()
          ..addAll(nextForecast);
      });
      _queueLocalStatePersist();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weatherLoading = false;
        _weatherError = 'Météo indisponible';
      });
      _queueLocalStatePersist();
    }
  }

  Widget _homeMascotAvatar({double size = 56}) {
    Widget content;
    if (_homeMascotKind == 'photo' && _homeMascotImageData.isNotEmpty) {
      try {
        final comma = _homeMascotImageData.indexOf(',');
        final encoded = comma >= 0 ? _homeMascotImageData.substring(comma + 1) : _homeMascotImageData;
        final bytes = base64Decode(encoded);
        content = Image.memory(bytes, fit: BoxFit.cover, filterQuality: FilterQuality.medium, gaplessPlayback: true);
      } catch (_) {
        content = Image.memory(_bearHeadBytes, fit: BoxFit.contain, filterQuality: FilterQuality.medium, gaplessPlayback: true);
      }
    } else if (_homeMascotKind == 'emoji') {
      content = Center(child: Text(_homeMascotEmoji, style: TextStyle(fontSize: size * .52)));
    } else {
      content = Image.memory(_bearHeadBytes, fit: BoxFit.contain, filterQuality: FilterQuality.medium, gaplessPlayback: true);
    }

    return GestureDetector(
      onTap: _editHomeMascot,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4EA),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE7D4C6), width: 1.5),
              boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 8, offset: Offset(0, 3))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(padding: EdgeInsets.all(size * .05), child: content),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFEFB),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE0D5C8)),
              ),
              child: _uiIcon('edit', Icons.edit_rounded, size: 10, color: const Color(0xFF6F7B74)),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickHomeMascotImage() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = false;
    input.style
      ..position = 'fixed'
      ..left = '-10000px'
      ..top = '0'
      ..width = '1px'
      ..height = '1px'
      ..opacity = '0';
    html.document.body?.children.add(input);
    try {
      try {
        input.click();
        await input.onChange.first;
      } catch (_) {
        _showFeedback('Impossible d’ouvrir le sélecteur de photo dans ce navigateur.');
        return null;
      }
      final files = input.files;
      if (files == null || files.isEmpty) {
        _showFeedback('Aucune photo n’a été sélectionnée.');
        return null;
      }
      final file = files.first;
      final mime = file.type.toLowerCase();
      if (mime.isNotEmpty && !mime.startsWith('image/')) {
        _showFeedback('Ce fichier n’est pas une photo compatible.');
        return null;
      }
      if (file.size > 1024 * 1024) {
        _showFeedback('Photo trop lourde. Choisis une image de moins de 1 Mo.');
        return null;
      }
      final reader = html.FileReader();
      try {
        reader.readAsDataUrl(file);
        await reader.onLoad.first;
      } catch (_) {
        _showFeedback('Impossible de lire cette photo. Essaie une image PNG ou JPEG.');
        return null;
      }
      final data = reader.result?.toString();
      if (data == null || data.isEmpty || !data.startsWith('data:image/')) {
        _showFeedback('La photo sélectionnée n’a pas pu être importée.');
        return null;
      }
      return data;
    } catch (_) {
      _showFeedback('L’importation de la photo a échoué.');
      return null;
    } finally {
      input.remove();
    }
  }

  Future<void> _editHomeMascot() async {
    final choice = await showModalBottomSheet<_HomeMascotChoice>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFBF5),
      builder: (_) => _HomeMascotSheet(
        currentKind: _homeMascotKind,
        currentEmoji: _homeMascotEmoji,
        emojiOptions: _activityIconPalette(Activity(
          id: '_mascot_picker_probe',
          name: 'Mascotte',
          emoji: _homeMascotEmoji,
          category: 'Autre',
          duration: 1,
          frequency: 1,
          priority: 1,
        )),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice.kind == 'photo') {
      final data = await _pickHomeMascotImage();
      if (data == null || !mounted) return;
      setState(() {
        _homeMascotKind = 'photo';
        _homeMascotImageData = data;
      });
    } else {
      setState(() {
        _homeMascotKind = choice.kind;
        _homeMascotEmoji = choice.emoji;
        _homeMascotImageData = '';
      });
    }
    _queueLocalStatePersist();
  }

  Future<void> _editHomeIdentity() async {
    final result = await showModalBottomSheet<_HomeIdentityResult>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFBF5),
      builder: (_) => _HomeIdentitySheet(
        initialName: _userName,
        initialCity: _weatherCity,
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _userName = result.name;
      _weatherCity = result.city;
      _weatherError = '';
    });
    _queueLocalStatePersist();

    if (result.city.isEmpty) {
      setState(() {
        _weatherText = '';
        _weatherTemperature = '';
        _weatherIcon = '🌤️';
        _weatherError = '';
        _weatherForecast.clear();
      });
      _queueLocalStatePersist();
      return;
    }

    await _loadWeather();
  }

}
