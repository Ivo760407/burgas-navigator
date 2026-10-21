import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const BurgasNavigatorApp());
}

class BurgasNavigatorApp extends StatelessWidget {
  const BurgasNavigatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Burgas Navigator',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF42A5F5),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3FAFF),
      ),
      home: const LanguageScreen(),
    );
  }
}

// ------------------------------------------------------------
// ЕКРАН ЗА ИЗБОР НА ЕЗИК
// ------------------------------------------------------------

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  void selectLanguage(BuildContext context, String language) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(language: language),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FAFF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '🌊',
                  style: TextStyle(fontSize: 60),
                ),
                const SizedBox(height: 15),
                const Text(
                  'BURGAS NAVIGATOR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Изберете език',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose language',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 35),
                _LanguageButton(
                  flag: '🇧🇬',
                  title: 'Български',
                  onPressed: () {
                    selectLanguage(context, 'bg');
                  },
                ),
                const SizedBox(height: 12),
                _LanguageButton(
                  flag: '🇬🇧',
                  title: 'English',
                  onPressed: () {
                    selectLanguage(context, 'en');
                  },
                ),
                const SizedBox(height: 12),
                _LanguageButton(
                  flag: '🇩🇪',
                  title: 'Deutsch',
                  onPressed: () {
                    selectLanguage(context, 'de');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// БУТОН ЗА ЕЗИК
// ------------------------------------------------------------

class _LanguageButton extends StatelessWidget {
  final String flag;
  final String title;
  final VoidCallback onPressed;

  const _LanguageButton({
    required this.flag,
    required this.title,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          children: [
            Text(
              flag,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 15),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// НАЧАЛЕН ЕКРАН
// ------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  final String initialLanguage;

  const HomeScreen({
    super.key,
    required String language,
  }) : initialLanguage = language;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String language;
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _cloudPlayer = AudioPlayer();
  final List<Map<String, dynamic>> _recentPlaces = [];
  final List<Map<String, dynamic>> _favoritePlaces = [];
  Position? _searchOrigin;
  static const String _cloudTtsUrl = String.fromEnvironment('CLOUD_TTS_URL');

  @override
  void initState() {
    super.initState();
    language = widget.initialLanguage;
    _loadSavedPlaces();
    _configureTts();
  }

  String _placeKey(Map<String, dynamic> place) =>
      '${place['latitude']},${place['longitude']}';

  Future<void> _loadSavedPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> decodePlaces(String key) {
        final raw = prefs.getString(key);
        if (raw == null) return [];
        final decoded = jsonDecode(raw);
        if (decoded is! List) return [];
        return decoded.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['name'] is String &&
                item['latitude'] is num && item['longitude'] is num)
            .toList();
      }
      final recent = decodePlaces('burgas_recent_places');
      final favorites = decodePlaces('burgas_favorite_places');
      if (!mounted) return;
      setState(() {
        _recentPlaces..clear()..addAll(recent.take(20));
        _favoritePlaces..clear()..addAll(favorites);
      });
    } catch (_) {
      // Local storage is optional; search remains usable if it fails.
    }
  }

  Future<void> _persistPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('burgas_recent_places', jsonEncode(_recentPlaces));
      await prefs.setString('burgas_favorite_places', jsonEncode(_favoritePlaces));
    } catch (_) {
      // Do not interrupt navigation if persistence is unavailable.
    }
  }

  bool _isFavorite(Map<String, dynamic> place) =>
      _favoritePlaces.any((saved) => _placeKey(saved) == _placeKey(place));

  Future<void> _openNavigation(Map<String, dynamic> place) async {
    final latitude = place['latitude'];
    final longitude = place['longitude'];
    if (latitude is! num || longitude is! num) {
      _showMessage(context, language == 'en'
          ? 'Location coordinates are unavailable.'
          : language == 'de'
              ? 'Standortkoordinaten sind nicht verfügbar.'
              : 'Липсват координати за мястото.');
      return;
    }

    final mode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(language == 'en'
            ? 'Choose how to travel'
            : language == 'de'
                ? 'Fortbewegungsart wählen'
                : 'Избери начин на придвижване'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.directions_walk),
              title: Text(language == 'en' ? 'Walking' : language == 'de' ? 'Zu Fuß' : 'Пеша'),
              onTap: () => Navigator.pop(dialogContext, 'walking'),
            ),
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: Text(language == 'en' ? 'Car' : language == 'de' ? 'Auto' : 'С автомобил'),
              onTap: () => Navigator.pop(dialogContext, 'driving'),
            ),
            ListTile(
              leading: const Icon(Icons.directions_bike),
              title: Text(language == 'en' ? 'Bicycle' : language == 'de' ? 'Fahrrad' : 'С велосипед'),
              onTap: () => Navigator.pop(dialogContext, 'bicycling'),
            ),
            ListTile(
              leading: const Icon(Icons.directions_transit),
              title: Text(language == 'en' ? 'Public transport' : language == 'de' ? 'Öffentliche Verkehrsmittel' : 'Обществен транспорт'),
              onTap: () => Navigator.pop(dialogContext, 'transit'),
            ),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;

    var avoidStairs = false;
    if (mode == 'walking') {
      final question = language == 'en'
          ? 'Would you like a walking route with or without stairs? Google Maps may not honor stair avoidance on every route, so please check the route before starting.'
          : language == 'de'
              ? 'Möchtest du eine Fußroute mit oder ohne Treppen? Google Maps berücksichtigt die Treppenvermeidung möglicherweise nicht bei jeder Route. Bitte prüfe die Route vor dem Start.'
              : 'Предпочиташ ли пешеходен маршрут със или без стълби? Google Maps може да не спази избягването на стълби при всеки маршрут, затова провери маршрута преди тръгване.';
      await _speak(question);
      if (!mounted) return;
      final stairsChoice = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(language == 'en'
              ? 'Stairs on the route?'
              : language == 'de'
                  ? 'Treppen auf der Route?'
                  : 'Стълби по маршрута?'),
          content: Text(question),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(language == 'en' ? 'With stairs' : language == 'de' ? 'Mit Treppen' : 'Със стълби'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(language == 'en' ? 'Without stairs' : language == 'de' ? 'Ohne Treppen' : 'Без стълби'),
            ),
          ],
        ),
      );
      if (stairsChoice == null || !mounted) return;
      avoidStairs = stairsChoice;
    }

    final parameters = <String, String>{
      'api': '1',
      'destination': '$latitude,$longitude',
      'travelmode': mode,
    };
    final origin = _searchOrigin;
    if (origin != null) {
      parameters['origin'] = '${origin.latitude},${origin.longitude}';
    }
    // Google Maps may ignore this extra preference; the dialog warns users
    // to verify the route before starting.
    if (mode == 'walking' && avoidStairs) {
      parameters['avoid'] = 'stairs';
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', parameters);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _showMessage(context, language == 'en'
            ? 'Could not open navigation.'
            : language == 'de'
                ? 'Navigation konnte nicht geöffnet werden.'
                : 'Навигацията не може да бъде отворена.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage(context, language == 'en'
            ? 'Could not open navigation.'
            : language == 'de'
                ? 'Navigation konnte nicht geöffnet werden.'
                : 'Навигацията не може да бъде отворена.');
      }
    }
  }
  Future<void> _toggleFavorite(Map<String, dynamic> place) async {
    setState(() {
      if (_isFavorite(place)) {
        _favoritePlaces.removeWhere((saved) => _placeKey(saved) == _placeKey(place));
      } else {
        _favoritePlaces.insert(0, Map<String, dynamic>.from(place));
      }
    });
    await _persistPlaces();
    if (mounted) {
      _showMessage(context, language == 'en'
          ? (_isFavorite(place) ? 'Added to favorites.' : 'Removed from favorites.')
          : language == 'de'
              ? (_isFavorite(place) ? 'Zu Favoriten hinzugefügt.' : 'Aus Favoriten entfernt.')
              : (_isFavorite(place) ? 'Добавено в любими.' : 'Премахнато от любими.'));
    }
  }

  Future<void> _configureTts() async {
    // По-бавен темп и естествена височина, вместо типичен роботизиран
    // навигационен тон. Самият глас идва от TTS двигателя на телефона.
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.43);
    await _tts.setVolume(1.0);
    await _tts.setPitch(0.97);
    await _setTtsLanguage();
  }

  Future<void> _setTtsLanguage() async {
    final locale = language == 'en'
        ? 'en-US'
        : language == 'de'
            ? 'de-DE'
            : 'bg-BG';

    try {
      await _tts.setLanguage(locale);

      // Ако телефонът предлага network/neural/natural вариант,
      // предпочитаме него пред стария локален глас.
      final voices = await _tts.getVoices;
      final matching = voices
          .whereType<Map>()
          .where((voice) {
            final voiceLocale =
                (voice['locale'] ?? '').toString().toLowerCase();
            final normalized = voiceLocale.replaceAll('_', '-');
            final requested = locale.toLowerCase();
            final languageCode = requested.split('-').first;
            return normalized == requested || normalized.startsWith('$languageCode-') || normalized == languageCode;
          })
          .toList();

      if (matching.isNotEmpty) {
        matching.sort((a, b) {
          final aName = (a['name'] ?? '').toString().toLowerCase();
          final bName = (b['name'] ?? '').toString().toLowerCase();

          int score(Map voice, String name) {
            var value = 0;
            if (name.contains('network')) value += 3;
            if (name.contains('neural')) value += 3;
            if (name.contains('natural')) value += 3;
            if (name.contains('wavenet')) value += 2;
            if (name.contains('local')) value -= 2;
            final qualityValue = voice['quality'];
            final quality = qualityValue is num ? qualityValue.toInt() : int.tryParse(qualityValue?.toString() ?? '');
            if (quality != null) value += quality ~/ 100;
            if (voice['networkConnectionRequired'] == true) value += 1;
            final latencyValue = voice['latency'];
            final latency = latencyValue is num ? latencyValue.toInt() : int.tryParse(latencyValue?.toString() ?? '');
            if (latency != null && latency > 0 && latency <= 200) value += 1;
            return value;
          }

          return score(b, bName).compareTo(score(a, aName));
        });

        final selected = matching.first;
        final name = selected['name']?.toString();
        if (name != null && name.isNotEmpty) {
          await _tts.setVoice({
            'name': name,
            'locale': locale,
          });
        }
      }
    } catch (_) {
      // Ако устройството не дава списък с гласове, остава избраният locale.
    }
  }

  String _prepareBulgarianTts(String message) {
    if (language != 'bg') return message;

    // Android TTS често произнася уличните съкращения буквално.
    // Разписваме ги с думи, за да се получи по-естествено произношение.
    var result = message
        .replaceAll(RegExp(r'\\bбул\\.\\s*', caseSensitive: false), 'булевард ')
        .replaceAll(RegExp(r'\\bул\\.\\s*', caseSensitive: false), 'улица ')
        .replaceAll(RegExp(r'\\bпл\\.\\s*', caseSensitive: false), 'площад ')
        .replaceAll(RegExp(r'\\bкв\\.\\s*', caseSensitive: false), 'квартал ')
        .replaceAll(RegExp(r'\\bж\\.\\s*к\\.\\s*', caseSensitive: false), 'жилищен комплекс ')
        .replaceAll(RegExp(r'\\bжк\\s+', caseSensitive: false), 'жилищен комплекс ')
        .replaceAll('Намирате се', 'Вие сте')
        .replaceAll('Текущото ви местоположение е', 'Вие сте на');

    // Малки паузи около номерата и препинателните знаци помагат на
    // навигационния стил и намаляват сливането на думи.
    result = result
        .replaceAll(RegExp(r'\\s*,\\s*'), ', ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();

    return result;
  }

  Future<bool> _speakWithCloudTts(String message) async {
    if (_cloudTtsUrl.trim().isEmpty) return false;

    try {
      final preparedMessage = _prepareBulgarianTts(message);
      final response = await http
          .post(
            Uri.parse(_cloudTtsUrl),
            headers: const {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'text': preparedMessage,
              'language': language,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200 ||
          response.bodyBytes.isEmpty ||
          !mounted) {
        return false;
      }

      await _tts.stop();
      await _cloudPlayer.stop();
      await _cloudPlayer.play(
        BytesSource(response.bodyBytes, mimeType: 'audio/mpeg'),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _speak(String message) async {
    try {
      if (await _speakWithCloudTts(message)) return;

      await _setTtsLanguage();
      await _tts.stop();

      // Резервен вариант: локалният Android TTS остава наличен при
      // липса на интернет или ако облачният TTS не е конфигуриран.
      final preparedMessage = _prepareBulgarianTts(message);
      final naturalMessage = preparedMessage
          .replaceAll(':', ': ')
          .replaceAll(', ', ',  ')
          .replaceAll('. ', '.  ');

      await _tts.speak(naturalMessage);
    } catch (_) {
      // Voice output is optional; location and map should still work.
    }
  }

  String _buildLocationMessage(Placemark? placemark, Position position) {
    final city = placemark?.locality?.trim().isNotEmpty == true
        ? placemark!.locality!.trim()
        : placemark?.subAdministrativeArea?.trim().isNotEmpty == true
            ? placemark!.subAdministrativeArea!.trim()
            : null;

    final street = placemark?.street?.trim() ?? '';
    final number = placemark?.name?.trim() ?? '';
    final address = [street, number]
        .where((part) => part.isNotEmpty)
        .join(' ')
        .trim();

    if (language == 'en') {
      if (city != null && address.isNotEmpty) {
        return 'You are in $city, at $address.';
      }
      if (city != null) {
        return 'You are in $city. Your coordinates are ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}.';
      }
      return 'Your current location is ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}.';
    }

    if (language == 'de') {
      if (city != null && address.isNotEmpty) {
        return 'Sie befinden sich in $city, in $address.';
      }
      if (city != null) {
        return 'Sie befinden sich in $city. Ihre Koordinaten sind ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}.';
      }
      return 'Ihr aktueller Standort ist ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}.';
    }

    if (city != null && address.isNotEmpty) {
      return 'Вие сте в $city, на адрес $address.';
    }
    if (city != null) {
      return 'Вие сте в $city.';
    }
    return 'Вие сте на текущото си местоположение.';
  }

  @override
  void dispose() {
    _tts.stop();
    _cloudPlayer.dispose();
    super.dispose();
  }

  String get subtitle {
    if (language == 'en') {
      return 'Your city assistant';
    }

    if (language == 'de') {
      return 'Dein Stadtassistent';
    }

    return 'Твоят градски асистент';
  }

  String get whereAmI {
    if (language == 'en') {
      return 'WHERE AM I?';
    }

    if (language == 'de') {
      return 'WO BIN ICH?';
    }

    return 'КЪДЕ СЪМ?';
  }

  String get whereTo {
    if (language == 'en') {
      return 'WHERE DO YOU WANT TO GO?';
    }

    if (language == 'de') {
      return 'WO MÖCHTEST DU HIN?';
    }

    return 'КЪДЕ ИСКАШ ДА ОТИДЕШ?';
  }

  String get whereAmISubtitle {
    if (language == 'en') {
      return 'Find my current location';
    }

    if (language == 'de') {
      return 'Meinen Standort bestimmen';
    }

    return 'Определи моето местоположение';
  }

  String get whereToSubtitle {
    if (language == 'en') {
      return 'Say or type where you want to go';
    }

    if (language == 'de') {
      return 'Sag oder schreibe, wohin du möchtest';
    }

    return 'Кажи или напиши къде искаш да отидеш';
  }

  String get quickSearch {
    if (language == 'en') {
      return 'Quick search';
    }

    if (language == 'de') {
      return 'Schnellsuche';
    }

    return 'Бързо търсене';
  }

  String get languageName {
    if (language == 'en') {
      return 'EN';
    }

    if (language == 'de') {
      return 'DE';
    }

    return 'BG';
  }

  void changeLanguage(String? newLanguage) {
    if (newLanguage == null) {
      return;
    }

    setState(() {
      language = newLanguage;
    });
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
Future<void> _searchLocation() async {
  final controller = TextEditingController();
  final speech = stt.SpeechToText();
  var isListening = false;
  var speechAvailable = false;
  final query = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(language == 'en' ? 'Where do you want to go?' : language == 'de' ? 'Wohin möchtest du gehen?' : 'Къде искаш да отидеш?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: language == 'en' ? 'Enter an address or place' : language == 'de' ? 'Adresse oder Ort eingeben' : 'Въведи адрес или място',
              ),
              onSubmitted: (value) => Navigator.pop(dialogContext, value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: language == 'en' ? 'Speak your destination' : language == 'de' ? 'Ziel sprechen' : 'Кажи дестинацията',
                  onPressed: () async {
                    if (isListening) {
                      await speech.stop();
                      setDialogState(() => isListening = false);
                      return;
                    }
                    speechAvailable = await speech.initialize(
                      onStatus: (status) {
                        if (status == 'notListening' && dialogContext.mounted) {
                          setDialogState(() => isListening = false);
                        }
                      },
                      onError: (_) {
                        if (dialogContext.mounted) setDialogState(() => isListening = false);
                      },
                    );
                    if (!speechAvailable) {
                      if (mounted && dialogContext.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(language == 'en'
                              ? 'Speech recognition is unavailable on this device.'
                              : language == 'de'
                                  ? 'Spracherkennung ist auf diesem Gerät nicht verfügbar.'
                                  : 'Гласовото разпознаване не е достъпно на това устройство.'),
                        ));
                      }
                      return;
                    }
                    setDialogState(() => isListening = true);
                    await speech.listen(
                      listenOptions: stt.SpeechListenOptions(
                        localeId: language == 'en' ? 'en_US' : language == 'de' ? 'de_DE' : 'bg_BG',
                      ),
                      onResult: (result) {
                        controller.text = result.recognizedWords;
                        controller.selection = TextSelection.collapsed(offset: controller.text.length);
                        if (result.finalResult && dialogContext.mounted) {
                          setDialogState(() => isListening = false);
                        }
                      },
                    );
                  },
                  icon: Icon(isListening ? Icons.stop : Icons.mic),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isListening
                        ? (language == 'en' ? 'Listening…' : language == 'de' ? 'Höre zu…' : 'Слушам…')
                        : (language == 'en' ? 'Tap the microphone to speak' : language == 'de' ? 'Tippe auf das Mikrofon' : 'Натисни микрофона, за да говориш'),
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(language == 'en' ? 'Cancel' : language == 'de' ? 'Abbrechen' : 'Отказ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(language == 'en' ? 'Search' : language == 'de' ? 'Suchen' : 'Търси'),
          ),
        ],
      ),
    ),
  );
  if (speechAvailable) {
    await speech.stop();
    await speech.cancel();
  }
  controller.dispose();
  if (!mounted || query == null || query.trim().isEmpty) return;
  await _findPlaces(query.trim());
}

Future<List<Map<String, dynamic>>> _fetchNightlifePlaces() async {
  // OpenStreetMap/Overpass is free and has dedicated tags for bars, pubs
  // and nightclubs; Photon is primarily a geocoder and often misses these POIs.
  const overpassQuery = r"""
[out:json][timeout:25];
(
  nwr(42.640,26.250,42.720,26.390)["amenity"~"^(bar|pub|nightclub|casino)$"];
  nwr(42.640,26.250,42.720,26.390)["club"~"^(nightclub|bar)$"];
  nwr(42.640,26.250,42.720,26.390)["leisure"="dance"];
);
out center tags;
""";
  final uri = Uri.https('overpass-api.de', '/api/interpreter', {'data': overpassQuery});
  final response = await http.get(uri, headers: const {
    'Accept': 'application/json',
    'User-Agent': 'BurgasNavigator/1.0 (free city navigation app)',
  }).timeout(const Duration(seconds: 22));
  if (response.statusCode != 200) {
    throw FormatException('Overpass returned HTTP ${response.statusCode}');
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final elements = data['elements'] as List<dynamic>? ?? const [];
  final places = <Map<String, dynamic>>[];
  for (final raw in elements) {
    if (raw is! Map<String, dynamic>) continue;
    final tags = raw['tags'] as Map<String, dynamic>? ?? const {};
    final name = (tags['name'] ?? tags['brand'] ?? '').toString().trim();
    if (name.isEmpty) continue;
    final lat = raw['lat'] ?? (raw['center'] as Map<String, dynamic>?)?['lat'];
    final lon = raw['lon'] ?? (raw['center'] as Map<String, dynamic>?)?['lon'];
    if (lat is! num || lon is! num) continue;
    final address = [
      tags['addr:street'],
      tags['addr:housenumber'],
      tags['addr:suburb'],
      'Сливен',
    ].where((part) => part != null && part.toString().trim().isNotEmpty)
     .map((part) => part.toString().trim()).join(', ');
    places.add({
      'name': name,
      'details': address,
      'latitude': lat.toDouble(),
      'longitude': lon.toDouble(),
    });
  }
  final seen = <String>{};
  return places.where((place) =>
    seen.add('${place['latitude']},${place['longitude']}')).toList();
}

Future<List<Map<String, dynamic>>> _fetchCityCategory(String category) async {
  const bounds = '(42.640,26.250,42.720,26.390)';
  final tags = category == 'hospital'
      ? 'nwr$bounds["amenity"~"^(hospital|clinic|doctors)\$"]; nwr$bounds["healthcare"~"^(hospital|clinic|doctor|centre|health_centre|medical_centre|urgent_care)\$"];'
      : category == 'police'
          ? 'nwr$bounds["amenity"="police"];'
          : 'nwr$bounds["amenity"="fire_station"];';
  final query = '[out:json][timeout:25];($tags);out center tags;';
  final uri = Uri.https('overpass-api.de', '/api/interpreter', {'data': query});
  final response = await http.get(uri, headers: const {
    'Accept': 'application/json',
    'User-Agent': 'BurgasNavigator/1.0 (free city navigation app)',
  }).timeout(const Duration(seconds: 28));
  if (response.statusCode != 200) throw FormatException('Overpass HTTP ${response.statusCode}');
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final elements = data['elements'] as List<dynamic>? ?? const [];
  final places = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final raw in elements) {
    if (raw is! Map<String, dynamic>) continue;
    final t = raw['tags'] as Map<String, dynamic>? ?? const {};
    final lat = raw['lat'] ?? (raw['center'] as Map<String, dynamic>?)?['lat'];
    final lon = raw['lon'] ?? (raw['center'] as Map<String, dynamic>?)?['lon'];
    if (lat is! num || lon is! num) continue;
    if (!seen.add('${lat.toDouble()},${lon.toDouble()}')) continue;
    final fallback = category == 'hospital'
        ? (language == 'en' ? 'Medical facility' : language == 'de' ? 'Medizinische Einrichtung' : 'Лечебно заведение')
        : category == 'police'
            ? (language == 'en' ? 'Police station' : language == 'de' ? 'Polizeidienststelle' : 'Полицейски участък')
            : (language == 'en' ? 'Fire station' : language == 'de' ? 'Feuerwehr' : 'Пожарна служба');
    final address = [t['addr:street'], t['addr:housenumber'], language == 'en' ? 'Sliven' : 'Сливен']
        .where((v) => v != null && v.toString().isNotEmpty).join(', ');
    places.add({
      'name': (t['name'] ?? t['operator'] ?? t['brand'] ?? fallback).toString(),
      'details': address, 'latitude': lat.toDouble(), 'longitude': lon.toDouble(),
    });
  }
  places.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  return places;
}

Future<List<Map<String, dynamic>>> _fetchPlaces(String query) async {
  final normalizedQuery = query.toLowerCase();
  final nightlifeTerms = [
    'нощни заведения', 'нощи заведения', 'нощно заведение', 'нощен клуб',
    'нощни клубове', 'дискотека', 'дискотеки', 'барове', 'бар', 'пъб',
    'pub', 'nightclub', 'night clubs', 'nightlife', 'clubs', 'nachtclub', 'kneipe',
  ];
  if (nightlifeTerms.any(normalizedQuery.contains)) {
    // Overpass can temporarily rate-limit or time out. Continue to geocoders.
    try {
      final places = await _fetchNightlifePlaces();
      if (places.isNotEmpty) return places;
    } catch (_) {
      // Fall through to Photon/Nominatim.
    }
  }
  final isHospital = normalizedQuery.contains('болница') ||
      normalizedQuery.contains('hospital') || normalizedQuery.contains('krankenhaus') ||
      normalizedQuery.contains('лечебно заведение');
  final isPolice = normalizedQuery.contains('полицейски участък') ||
      normalizedQuery.contains('police station') || normalizedQuery.contains('polizei');
  final isFireStation = normalizedQuery.contains('пожарна служба') ||
      normalizedQuery.contains('fire station') || normalizedQuery.contains('feuerwache');
  if (isHospital || isPolice || isFireStation) {
    final category = isHospital ? 'hospital' : isPolice ? 'police' : 'fire_station';
    // A temporary Overpass error must not disable emergency search.
    try {
      final places = await _fetchCityCategory(category);
      if (places.isNotEmpty) return places;
    } catch (_) {
      // Fall back to Photon/Nominatim below.
    }
  }
  // Try Photon first. If it is unavailable, fall back to Nominatim.
  // Neither provider requires a private API key.
  Object? photonError;
  try {
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': query,
      'lat': (_searchOrigin?.latitude ?? 42.6817).toString(),
      'lon': (_searchOrigin?.longitude ?? 26.3225).toString(),
      'limit': '10',
      'lang': language == 'bg' ? 'default' : language,
    });
    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw FormatException('Photon returned HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? const [];
    final places = features.whereType<Map<String, dynamic>>()
      .where((feature) {
        // Geocoders often omit city/locality for individual POIs.
        // Use the Sliven urban bounding box instead of dropping those results.
        final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
        final coordinates = geometry['coordinates'] as List<dynamic>? ?? const [];
        if (coordinates.length < 2 || coordinates[0] is! num || coordinates[1] is! num) {
          return false;
        }
        final longitude = (coordinates[0] as num).toDouble();
        final latitude = (coordinates[1] as num).toDouble();
        return latitude >= 42.640 && latitude <= 42.720 &&
            longitude >= 26.250 && longitude <= 26.390;
      })
      .map((feature) {
      final properties = feature['properties'] as Map<String, dynamic>? ?? {};
      final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
      final coordinates = geometry['coordinates'] as List<dynamic>? ?? const [];
      if (coordinates.length < 2 ||
          coordinates[0] is! num ||
          coordinates[1] is! num) {
        return <String, dynamic>{};
      }
      final name = (properties['name'] ??
              properties['street'] ??
              properties['city'] ??
              query)
          .toString();
      final details = [
        properties['street'],
        properties['housenumber'],
        properties['city'] ?? properties['locality'],
      ]
          .where((part) => part != null && part.toString().trim().isNotEmpty)
          .map((part) => part.toString().trim())
          .toSet()
          .join(', ');
      return <String, dynamic>{
        'name': name,
        'details': details,
        'latitude': (coordinates[1] as num).toDouble(),
        'longitude': (coordinates[0] as num).toDouble(),
      };
    }).where((place) => place.isNotEmpty).toList();
    if (places.isNotEmpty) return places;
  } catch (error) {
    photonError = error;
  }

  // Reserve Nominatim for fallback to avoid unnecessary requests.
  final fallbackUri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': query,
    'format': 'jsonv2',
    'addressdetails': '1',
    'limit': '10',
    'accept-language': language == 'bg' ? 'bg' : language,
  });
  try {
    final response = await http.get(fallbackUri, headers: const {
      'Accept': 'application/json',
      'User-Agent': 'BurgasNavigator/1.0 (Android city navigation app)',
    }).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw FormatException('Nominatim returned HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    // Accept only explicit city/town address matches; municipality membership
    // alone would incorrectly include nearby villages.
    return data.whereType<Map<String, dynamic>>().where((item) {
      // Use the same city-area filter as Photon; missing locality metadata
      // should not discard valid places inside Sliven.
      final latitude = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
      final longitude = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
      return latitude >= 42.640 && latitude <= 42.720 &&
          longitude >= 26.250 && longitude <= 26.390;
    }).map((item) {
      final address = item['address'] as Map<String, dynamic>? ?? {};
      final displayName = (item['display_name'] ?? query).toString();
      final name = (item['name'] ??
              address['amenity'] ??
              address['shop'] ??
              address['tourism'] ??
              address['road'] ??
              address['suburb'] ??
              displayName.split(',').first)
          .toString();
      return <String, dynamic>{
        'name': name,
        'details': displayName,
        'latitude': double.tryParse(item['lat']?.toString() ?? '') ?? 0.0,
        'longitude': double.tryParse(item['lon']?.toString() ?? '') ?? 0.0,
      };
    }).where((place) =>
        (place['latitude'] as double) != 0.0 &&
        (place['longitude'] as double) != 0.0).toList();
  } catch (fallbackError) {
    throw Exception('Search providers unavailable: $photonError; $fallbackError');
  }
}

Future<void> _refreshSearchOrigin() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _searchOrigin = null;
      return;
    }
    _searchOrigin = await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            timeLimit: Duration(seconds: 8),
          ),
        );
  } catch (_) {
    _searchOrigin = null;
  }
}

Future<void> _findPlaces(String query) async {
  await _refreshSearchOrigin();
  try {
    final places = await _fetchPlaces(query);
    if (!mounted) return;
    if (places.isEmpty) {
      _showMessage(context, language == 'en' ? 'No matching places found.' : language == 'de' ? 'Keine passenden Orte gefunden.' : 'Не са намерени подходящи места.');
      return;
    }
    await _showPlaceResults(places, query);
  } catch (_) {
    if (!mounted) return;
    _showMessage(context, language == 'en' ? 'Search is temporarily unavailable. Please try again.' : language == 'de' ? 'Die Suche ist vorübergehend nicht verfügbar. Bitte erneut versuchen.' : 'Търсенето временно не е достъпно. Опитай отново.');
  }
}

Future<void> _searchCategory(String category) async {
  const terms = <String, Map<String, String>>{
    'restaurant': {'bg': 'ресторант', 'en': 'restaurant', 'de': 'Restaurant'},
    'nightlife': {'bg': 'нощни заведения', 'en': 'nightlife', 'de': 'Nachtleben'},
    'hotel': {'bg': 'хотел', 'en': 'hotel', 'de': 'Hotel'},
    'beach': {'bg': 'плаж', 'en': 'beach', 'de': 'Strand'},
    'parking': {'bg': 'паркинг', 'en': 'parking', 'de': 'Parkplatz'},
    'pharmacy': {'bg': 'аптека', 'en': 'pharmacy', 'de': 'Apotheke'},
    'hospital': {'bg': 'болница', 'en': 'hospital', 'de': 'Krankenhaus'},
    'police': {'bg': 'полицейски участък', 'en': 'police station', 'de': 'Polizeiwache'},
    'fire_station': {'bg': 'пожарна служба', 'en': 'fire station', 'de': 'Feuerwache'},
    'atm': {'bg': 'банкомат', 'en': 'ATM', 'de': 'Geldautomat'},
    'supermarket': {'bg': 'супермаркет', 'en': 'supermarket', 'de': 'Supermarkt'},
    'toilets': {'bg': 'обществена тоалетна', 'en': 'public toilet', 'de': 'öffentliche Toilette'},
    'bus_station': {'bg': 'автогара', 'en': 'bus station', 'de': 'Busbahnhof'},
    'fuel': {'bg': 'бензиностанция', 'en': 'fuel station', 'de': 'Tankstelle'},
    'playground': {'bg': 'детска площадка', 'en': 'playground', 'de': 'Spielplatz'},
    'park': {'bg': 'парк', 'en': 'park', 'de': 'Park'},
    'museum': {'bg': 'музей', 'en': 'museum', 'de': 'Museum'},
    'attraction': {'bg': 'забележителност', 'en': 'tourist attraction', 'de': 'Sehenswürdigkeit'},
    'cafe': {'bg': 'кафене', 'en': 'cafe', 'de': 'Café'},
    'bakery': {'bg': 'пекарна', 'en': 'bakery', 'de': 'Bäckerei'},
    'bank': {'bg': 'банка', 'en': 'bank', 'de': 'Bank'},
    'dentist': {'bg': 'зъболекар', 'en': 'dentist', 'de': 'Zahnarzt'},
    'veterinary': {'bg': 'ветеринарна клиника', 'en': 'veterinary clinic', 'de': 'Tierarzt'},
    'ev_charging': {'bg': 'зарядна станция за електромобили', 'en': 'EV charging station', 'de': 'Ladestation für Elektroautos'},
    'sports': {'bg': 'спортен център', 'en': 'sports centre', 'de': 'Sportzentrum'},
    'library': {'bg': 'библиотека', 'en': 'library', 'de': 'Bibliothek'},
    'cinema': {'bg': 'кино', 'en': 'cinema', 'de': 'Kino'},
    'post_office': {'bg': 'поща', 'en': 'post office', 'de': 'Postamt'},
  };
  final searchTerm = terms[category]?[language] ?? category;
  final city = language == 'en'
      ? 'Sliven Bulgaria'
      : language == 'de'
          ? 'Sliven Bulgarien'
          : 'Сливен България';
  await _findPlaces('$searchTerm $city');
}

  String _formatApproximateDistance(Map<String, dynamic> place) {
    final latitude = place['latitude'];
    final longitude = place['longitude'];
    final origin = _searchOrigin;
    if (latitude is! num || longitude is! num) {
      return language == 'en'
          ? 'Distance unavailable'
          : language == 'de'
              ? 'Entfernung nicht verfügbar'
              : 'Разстоянието не е достъпно';
    }
    if (origin == null) {
      return language == 'en'
          ? 'Enable location to see distance'
          : language == 'de'
              ? 'Standort aktivieren, um die Entfernung zu sehen'
              : 'Включи местоположението, за да видиш разстоянието';
    }
    final kilometers = const Distance().as(
      LengthUnit.Kilometer,
      LatLng(origin.latitude, origin.longitude),
      LatLng(latitude.toDouble(), longitude.toDouble()),
    );
    final distanceLabel = kilometers < 1
        ? '${(kilometers * 1000).round()} m'
        : '${kilometers.toStringAsFixed(1)} km';
    if (language == 'en') return 'About $distanceLabel from your location (straight-line)';
    if (language == 'de') return 'Ca. $distanceLabel von deinem Standort (Luftlinie)';
    return 'Около $distanceLabel от твоето местоположение (по права линия)';
  }

Future<void> _showPlaceResults(List<Map<String, dynamic>> places, String query) async {
  final selected = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(language == 'en' ? 'Search results' : language == 'de' ? 'Suchergebnisse' : 'Резултати от търсенето', style: Theme.of(sheetContext).textTheme.titleLarge),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: places.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final place = places[index];
                  return ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(place['name'] as String),
                    subtitle: Text(
                      ('${(place['details'] as String).isEmpty ? query : place['details'] as String}\n${_formatApproximateDistance(place)}'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: language == 'en'
                              ? 'Start navigation'
                              : language == 'de'
                                  ? 'Navigation starten'
                                  : 'Навигация',
                          onPressed: () => _openNavigation(place),
                          icon: const Icon(Icons.directions),
                        ),
                        IconButton(
                          tooltip: language == 'en'
                              ? 'Toggle favorite'
                              : language == 'de'
                                  ? 'Favorit umschalten'
                                  : 'Добави/премахни от любими',
                          onPressed: () => _toggleFavorite(place),
                          icon: Icon(
                            _isFavorite(place) ? Icons.star : Icons.star_border,
                            color: _isFavorite(place) ? Colors.amber.shade700 : null,
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => Navigator.pop(sheetContext, place),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (!mounted || selected == null) return;
  final name = selected['name'] as String;
  setState(() {
    _recentPlaces.removeWhere((place) => place['name'] == name);
    _recentPlaces.insert(0, Map<String, dynamic>.from(selected));
    if (_recentPlaces.length > 20) _recentPlaces.removeLast();
  });
  await _persistPlaces();
  if (!mounted) return;
  final normalizedQuery = query.toLowerCase();
  final isEmergencySearch = normalizedQuery.contains('болница') ||
      normalizedQuery.contains('hospital') ||
      normalizedQuery.contains('krankenhaus') ||
      normalizedQuery.contains('полицейски участък') ||
      normalizedQuery.contains('police station') ||
      normalizedQuery.contains('пожарна служба') ||
      normalizedQuery.contains('fire station');
  if (isEmergencySearch) {
    await _openNavigation(selected);
    return;
  }
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => LocationMapScreen(
      latitude: selected['latitude'] as double,
      longitude: selected['longitude'] as double,
      language: language,
      placeName: name,
    ),
  ));
}

void _openCityMap() {
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => LocationMapScreen(
      latitude: 42.6817,
      longitude: 26.3225,
      language: language,
      placeName: language == 'en' ? 'Sliven' : language == 'de' ? 'Sliven' : 'Сливен',
    ),
  ));
}

Future<void> _showRecentPlaces() async {
  if (_recentPlaces.isEmpty) {
    _showMessage(context, language == 'en'
        ? 'Your recent places will appear here after a search.'
        : language == 'de'
            ? 'Hier erscheinen Orte nach deiner Suche.'
            : 'Тук ще се показват последните намерени места.');
    return;
  }
  await _showPlaceResults(
    List<Map<String, dynamic>>.from(_recentPlaces),
    language == 'en' ? 'Recent places' : language == 'de' ? 'Zuletzt gesucht' : 'Последни места',
  );
}

Future<void> _showFavorites() async {
  if (_favoritePlaces.isEmpty) {
    _showMessage(context, language == 'en'
        ? 'Save a place with the star button to see it here.'
        : language == 'de'
            ? 'Speichere einen Ort mit dem Stern, um ihn hier zu sehen.'
            : 'Запази място със звездата, за да се появи тук.');
    return;
  }
  await _showPlaceResults(
    List<Map<String, dynamic>>.from(_favoritePlaces),
    language == 'en' ? 'Favorites' : language == 'de' ? 'Favoriten' : 'Любими места',
  );
}

Future<void> _showSettings() async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(language == 'en' ? 'Settings' : language == 'de' ? 'Einstellungen' : 'Настройки'),
      content: Text(language == 'en'
          ? 'The spoken language follows the language selected on the main screen. Voice quality depends on the speech engine installed on your phone.'
          : language == 'de'
              ? 'Die Sprache folgt der Auswahl auf dem Hauptbildschirm. Die Sprachqualität hängt von der auf deinem Telefon installierten Sprachausgabe ab.'
              : 'Говоримият език следва избора на главния екран. Качеството на гласа зависи от гласовия двигател, инсталиран на телефона.'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            _speak(language == 'en' ? 'Voice test. Your city assistant is ready.' : language == 'de' ? 'Sprachtest. Dein Stadtassistent ist bereit.' : 'Проба на гласа. Градският ти асистент е готов.');
          },
          child: Text(language == 'en' ? 'Test voice' : language == 'de' ? 'Stimme testen' : 'Пробвай гласа'),
        ),
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(language == 'en' ? 'Close' : language == 'de' ? 'Schließen' : 'Затвори')),
      ],
    ),
  );
}
  void _showLocationLoading() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final message = language == 'en'
            ? 'Finding your location...'
            : language == 'de'
                ? 'Standort wird ermittelt...'
                : 'Определям местоположението...';

        return AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _hideLocationLoading() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    if (!mounted) return;
    _showLocationLoading();

    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!mounted) return;

    if (!serviceEnabled) {
      _hideLocationLoading();
      _showMessage(
        context,
        language == 'en'
            ? 'Location service is disabled.'
            : language == 'de'
                ? 'Standortdienst ist deaktiviert.'
                : 'Услугата за местоположение е изключена.',
      );
      return;
    }

    permission = await Geolocator.checkPermission();

    if (!mounted) return;

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (!mounted) return;
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _hideLocationLoading();
      _showMessage(
        context,
        language == 'en'
            ? 'Location permission denied.'
            : language == 'de'
                ? 'Standortberechtigung verweigert.'
                : 'Разрешението за местоположение е отказано.',
      );
      return;
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition();
    } catch (_) {
      if (!mounted) return;
      _hideLocationLoading();
      _showMessage(
        context,
        language == 'en'
            ? 'Could not determine your location.'
            : language == 'de'
                ? 'Ihr Standort konnte nicht ermittelt werden.'
                : 'Местоположението ви не може да бъде определено.',
      );
      return;
    }

    Placemark? placemark;
    try {
      final geocoding = Geocoding(
        locale: language == 'en'
            ? const Locale('en', 'US')
            : language == 'de'
                ? const Locale('de', 'DE')
                : const Locale('bg', 'BG'),
      );
      final placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        placemark = placemarks.first;
      }
    } catch (_) {
      // Reverse geocoding can fail due to platform service/rate limits.
    }

    if (!mounted) return;

    final locationMessage = _buildLocationMessage(placemark, position);
    _hideLocationLoading();
    await _speak(locationMessage);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationMapScreen(
          latitude: position.latitude,
          longitude: position.longitude,
          language: language,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FAFF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '🌊 BURGAS NAVIGATOR',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: language,
                        icon: const Icon(Icons.arrow_drop_down),
                        items: const [
                          DropdownMenuItem(
                            value: 'bg',
                            child: Text('🇧🇬 BG'),
                          ),
                          DropdownMenuItem(
                            value: 'en',
                            child: Text('🇬🇧 EN'),
                          ),
                          DropdownMenuItem(
                            value: 'de',
                            child: Text('🇩🇪 DE'),
                          ),
                        ],
                        onChanged: changeLanguage,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
              ),

              const SizedBox(height: 35),

              _MainButton(
                icon: Icons.location_on,
                title: whereAmI,
                subtitle: whereAmISubtitle,
                onPressed: _getCurrentLocation,
              ),

              const SizedBox(height: 16),

              _MainButton(
                icon: Icons.mic,
                title: whereTo,
                subtitle: whereToSubtitle,
                onPressed: _searchLocation,
              ),

              const SizedBox(height: 25),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  quickSearch,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _CategoryButton(
                    icon: Icons.local_hospital,
                    title: language == 'en' ? 'Hospital' : language == 'de' ? 'Krankenhaus' : 'Болница',
                    onPressed: () => _searchCategory('hospital'),
                  ),
                  _CategoryButton(
                    icon: Icons.local_police,
                    title: language == 'en' ? 'Police' : language == 'de' ? 'Polizei' : 'Полиция',
                    onPressed: () => _searchCategory('police'),
                  ),
                  _CategoryButton(
                    icon: Icons.local_fire_department,
                    title: language == 'en' ? 'Fire brigade' : language == 'de' ? 'Feuerwehr' : 'Пожарна',
                    onPressed: () => _searchCategory('fire_station'),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _BottomButton(icon: Icons.map, title: language == 'en' ? 'Map' : language == 'de' ? 'Karte' : 'Карта', onPressed: _openCityMap)),
                      const SizedBox(width: 10),
                      Expanded(child: _BottomButton(icon: Icons.history, title: language == 'en' ? 'Recent' : language == 'de' ? 'Zuletzt' : 'Последни', onPressed: _showRecentPlaces)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _BottomButton(icon: Icons.star, title: language == 'en' ? 'Favorites' : language == 'de' ? 'Favoriten' : 'Любими', onPressed: _showFavorites)),
                      const SizedBox(width: 10),
                      Expanded(child: _BottomButton(icon: Icons.settings, title: language == 'en' ? 'Settings' : language == 'de' ? 'Einstellungen' : 'Настройки', onPressed: _showSettings)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// ------------------------------------------------------------
// ОСНОВЕН БУТОН
// ------------------------------------------------------------

class _MainButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  const _MainButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 22,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 36,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// КОМПАКТЕН БУТОН
// ------------------------------------------------------------

class _CategoryButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onPressed;

  const _CategoryButton({required this.icon, required this.title, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0077B6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: Colors.black12),
      ),
    );
  }
}

// ------------------------------------------------------------
// ДОЛЕН БУТОН
// ------------------------------------------------------------

class _BottomButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onPressed;

  const _BottomButton({required this.icon, required this.title, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
          children: [
            Icon(
              icon,
              size: 25,
            ),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
      ),
    );
  }
}
class LocationMapScreen extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String language;
  final String? placeName;

  const LocationMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.language,
    this.placeName,
  });

  String get title {
    if (placeName != null && placeName!.trim().isNotEmpty) return placeName!;
    if (language == 'en') {
      return 'You are here';
    }

    if (language == 'de') {
      return 'Sie sind hier';
    }

    return 'Вие сте тук';
  }

  @override
  Widget build(BuildContext context) {
    final location = LatLng(latitude, longitude);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: location,
          initialZoom: 16,
        ),
        children: [
          TileLayer(
            // OpenStreetMap tiles — не изискват CARTO API key.
            urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName:
                'com.example.burgas_navigator',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: location,
                width: 160,
                height: 90,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.location_on,
                      color: Colors.blue,
                      size: 42,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
