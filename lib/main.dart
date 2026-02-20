import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/player/presentation/screens/home_screen.dart';

final cliArgsProvider = Provider<List<String>>((ref) => []);

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final width = prefs.getDouble('window_width') ?? 1000.0;
  final height = prefs.getDouble('window_height') ?? 700.0;
  final x = prefs.getDouble('window_x');
  final y = prefs.getDouble('window_y');

  WindowOptions windowOptions = WindowOptions(
    size: Size(width, height),
    center: x == null || y == null,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Bolt Player',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();

    if (x != null && y != null) {
      await windowManager.setPosition(Offset(x, y));
    }
    await windowManager.setMinimumSize(const Size(900, 550));
  });

  runApp(
    ProviderScope(
      overrides: [cliArgsProvider.overrideWith((ref) => args)],
      child: const BoltPlayerApp(),
    ),
  );
}

class BoltPlayerApp extends StatefulWidget {
  const BoltPlayerApp({super.key});

  @override
  State<BoltPlayerApp> createState() => _BoltPlayerAppState();
}

class _BoltPlayerAppState extends State<BoltPlayerApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _saveWindowState() async {
    final bounds = await windowManager.getBounds();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('window_x', bounds.left);
    await prefs.setDouble('window_y', bounds.top);
    await prefs.setDouble('window_width', bounds.width);
    await prefs.setDouble('window_height', bounds.height);
  }

  @override
  void onWindowResize() {
    _saveWindowState();
  }

  @override
  void onWindowMove() {
    _saveWindowState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bolt Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          surface: Color(0xFF1E1E1E),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
