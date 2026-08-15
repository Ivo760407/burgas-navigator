import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

  @override
  void initState() {
    super.initState();
    language = widget.initialLanguage;
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

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!mounted) return;

    if (!serviceEnabled) {
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

    Position position = await Geolocator.getCurrentPosition();

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
                onPressed: () {
                  _showMessage(
                    context,
                    language == 'en'
                        ? 'Voice search will be added.'
                        : language == 'de'
                            ? 'Die Sprachsuche wird hinzugefügt.'
                            : 'Гласовото търсене ще бъде добавено.',
                  );
                },
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
                children: const [
                  _CategoryButton(
                    icon: Icons.restaurant,
                    title: 'Ресторанти',
                  ),
                  _CategoryButton(
                    icon: Icons.hotel,
                    title: 'Хотели',
                  ),
                  _CategoryButton(
                    icon: Icons.beach_access,
                    title: 'Плажове',
                  ),
                  _CategoryButton(
                    icon: Icons.local_parking,
                    title: 'Паркинги',
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(
                    child: _BottomButton(
                      icon: Icons.map,
                      title: 'Карта',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BottomButton(
                      icon: Icons.favorite_border,
                      title: 'Любими',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BottomButton(
                      icon: Icons.settings,
                      title: 'Настройки',
                    ),
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

  const _CategoryButton({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

  const _BottomButton({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 14,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 25,
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class LocationMapScreen extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String language;

  const LocationMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.language,
  });

  String get title {
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
            urlTemplate:
                'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
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
