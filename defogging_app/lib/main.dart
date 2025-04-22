import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:defogging_app/pages/google_map_page.dart';
import 'package:defogging_app/pages/analytics_page.dart';
import 'package:defogging_app/pages/settings_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '除雾应用',
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
      home: const MainPage(),
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
    Icons.history,
    Icons.analytics_outlined,
    Icons.settings_outlined,
  ];

  final List<Widget> _pages = [
    const GoogleMapPage(),
    const Center(child: Text('历史页面')),
    const AnalyticsPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(padding: EdgeInsets.zero),
      child: Scaffold(
        body: Stack(
          children: [
            _pages[_selectedIndex],
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
