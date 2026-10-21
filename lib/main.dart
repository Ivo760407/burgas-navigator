import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
          seedColor: const Color(0xFF0077B6),
        ),
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
      backgroundColor: const Color(0xFFF5FAFC),
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
  static const String _cloudTtsUrl = String.fromEnvironment('CLOUD_TTS_URL');

  @override
  void initState() {
    super.initState();
    language = widget.initialLanguage;
    _configureTts();
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

          int score(String name) {
            var value = 0;
            if (name.contains('network')) value += 3;
            if (name.contains('neural')) value += 3;
            if (name.contains('natural')) value += 3;
            if (name.contains('wavenet')) value += 2;
            if (name.contains('local')) value -= 2;
            return value;
          }

          return score(bName).compareTo(score(aName));
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
  final query = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(language == 'en' ? 'Where do you want to go?' : language == 'de' ? 'Wohin möchtest du gehen?' : 'Къде искаш да отидеш?'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: language == 'en' ? 'Enter an address or place' : language == 'de' ? 'Adresse oder Ort eingeben' : 'Въведи адрес или място',
        ),
        onSubmitted: (value) => Navigator.pop(dialogContext, value),
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
  );
  controller.dispose();
  if (!mounted || query == null || query.trim().isEmpty) return;
  await _findPlaces(query.trim());
}

Future<List<Map<String, dynamic>>> _fetchPlaces(String query) async {
  // Photon uses OpenStreetMap data and does not require a private API key.
  final uri = Uri.https('photon.komoot.io', '/api/', {
    'q': query,
    'lat': '42.5048',
    'lon': '27.4626',
    'limit': '10',
    'lang': language == 'bg' ? 'default' : language,
  });
  final response = await http.get(uri, headers: const {'Accept': 'application/json'})
      .timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) {
    throw const FormatException('Search service returned an error');
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final features = data['features'] as List<dynamic>? ?? const [];
  return features.whereType<Map<String, dynamic>>().map((feature) {
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
    final coordinates = geometry['coordinates'] as List<dynamic>? ?? const [];
    if (coordinates.length < 2 || coordinates[0] is! num || coordinates[1] is! num) {
      return <String, dynamic>{};
    }
    final name = (properties['name'] ?? properties['street'] ?? properties['city'] ?? query).toString();
    final details = [
      properties['street'],
      properties['housenumber'],
      properties['city'] ?? properties['locality'],
    ].where((part) => part != null && part.toString().trim().isNotEmpty)
        .map((part) => part.toString().trim()).toSet().join(', ');
    return <String, dynamic>{
      'name': name,
      'details': details,
      'latitude': (coordinates[1] as num).toDouble(),
      'longitude': (coordinates[0] as num).toDouble(),
    };
  }).where((place) => place.isNotEmpty).toList();
}

Future<void> _findPlaces(String query) async {
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
  await _findPlaces('$category Burgas Bulgaria');
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
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final place = places[index];
                  return ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(place['name'] as String),
                    subtitle: Text((place['details'] as String).isEmpty ? query : place['details'] as String),
                    trailing: const Icon(Icons.chevron_right),
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
      latitude: 42.5048,
      longitude: 27.4626,
      language: language,
      placeName: language == 'en' ? 'Burgas' : language == 'de' ? 'Burgas' : 'Бургас',
    ),
  ));
}

Future<void> _showFavorites() async {
  if (_recentPlaces.isEmpty) {
    _showMessage(context, language == 'en' ? 'Your recent places will appear here after a search.' : language == 'de' ? 'Hier erscheinen Orte nach deiner Suche.' : 'Тук ще се показват последните намерени места.');
    return;
  }
  await _showPlaceResults(List<Map<String, dynamic>>.from(_recentPlaces), language == 'en' ? 'Recent places' : language == 'de' ? 'Zuletzt gesucht' : 'Последни места');
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
      backgroundColor: const Color(0xFFF5FAFC),
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
                  _CategoryButton(icon: Icons.restaurant, title: 'Ресторанти', onPressed: () => _searchCategory('restaurant')),
                  _CategoryButton(icon: Icons.hotel, title: 'Хотели', onPressed: () => _searchCategory('hotel')),
                  _CategoryButton(icon: Icons.beach_access, title: 'Плажове', onPressed: () => _searchCategory('beach')),
                  _CategoryButton(icon: Icons.local_parking, title: 'Паркинги', onPressed: () => _searchCategory('parking')),
                ],
              ),

              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(
                    child: _BottomButton(icon: Icons.map, title: 'Карта', onPressed: _openCityMap),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BottomButton(icon: Icons.history, title: 'Последни', onPressed: _showFavorites),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BottomButton(icon: Icons.settings, title: 'Настройки', onPressed: _showSettings),
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
