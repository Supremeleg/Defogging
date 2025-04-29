import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:defogging_app/pages/google_map_page.dart';
import 'package:defogging_app/pages/analytics_page.dart';
import 'package:defogging_app/pages/settings_page.dart';
import 'package:defogging_app/pages/login_page.dart';
import 'package:defogging_app/pages/profile_page.dart';
import 'package:defogging_app/pages/social_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:location/location.dart';
import 'dart:io' show Platform;
import 'database/database_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/user_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Starting application initialization...');
    
    // Initialize SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    print('Initializing SharedPreferences...');
    
    // Initialize database
    final dbHelper = DatabaseHelper();
    print('Initializing database...');
    await dbHelper.initializeDatabase();
    
    print('Loading environment variables...');
    await dotenv.load(fileName: ".env");
    
    print('Requesting location permissions...');
    await _requestLocationPermission();
    
    print('Application initialization completed successfully');
    runApp(MyApp(prefs: prefs));
  } catch (e) {
    print('Error during application initialization: $e');
    // In production, you might want to show a user-friendly error screen
    rethrow;
  }
}

Future<void> _requestLocationPermission() async {
  Location location = Location();
  
  // Check if location services are enabled
  bool serviceEnabled = await location.serviceEnabled();
  if (!serviceEnabled) {
    serviceEnabled = await location.requestService();
    if (!serviceEnabled) {
      return;
    }
  }

  // Request location permission
  PermissionStatus permissionStatus = await location.hasPermission();
  if (permissionStatus == PermissionStatus.denied) {
    permissionStatus = await location.requestPermission();
    if (permissionStatus != PermissionStatus.granted) {
      return;
    }
  }

  // If location permission is granted, try to enable background mode
  if (permissionStatus == PermissionStatus.granted) {
    try {
      await location.enableBackgroundMode(enable: true);
    } catch (e) {
      // If enabling background mode fails, it might be because we don't have background permission
      // This is normal, we'll try again when the user uses the app
      print('Background location permission not granted: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp({super.key, required this.prefs});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Defogging App',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => AuthWrapper(prefs: prefs),
        '/home': (context) => const MainPage(),
        '/profile': (context) => ProfilePage(prefs: prefs),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final SharedPreferences prefs;

  const AuthWrapper({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasData) {
          return const MainPage();
        }
        
        return LoginPage(prefs: prefs);
      },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<IconData> _navigationIcons = [
    Icons.map_outlined,
    Icons.people_outline,
    Icons.analytics_outlined,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(padding: EdgeInsets.zero),
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: [
                const GoogleMapPage(),
                const SocialPage(),
                const AnalyticsPage(),
                const SettingsPage(),
              ],
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(77),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(_navigationIcons.length, (index) {
                        bool isSelected = _selectedIndex == index;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                            child: Center(
                              child: Container(
                                width: 60,
                                height: 36,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                child: Stack(
                                  children: [
                                    if (isSelected)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(18),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white.withAlpha(179),
                                                blurRadius: 15,
                                                spreadRadius: 1,
                                              ),
                                              BoxShadow(
                                                color: Colors.white.withAlpha(128),
                                                blurRadius: 8,
                                                spreadRadius: 0,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: isSelected ? 8 : 0,
                                          sigmaY: isSelected ? 8 : 0,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.white.withAlpha(250)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              _navigationIcons[index],
                                              color: isSelected 
                                                  ? Colors.black.withAlpha(204)
                                                  : Colors.white.withAlpha(179),
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
