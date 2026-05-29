import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const NokiaCricketApp());
}

class NokiaCricketApp extends StatelessWidget {
  const NokiaCricketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nokia Cricket Pro',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111111),
        fontFamily: 'monospace',
      ),
      home: const HomeScreen(),
    );
  }
}
