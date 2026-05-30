import 'package:flutter/material.dart';
import 'game_data.dart';
import 'screens/home_screen.dart';

void main() async {
  // Flutter ఇంజిన్ స్టార్ట్ అయ్యాక SharedPreferences లోడ్ అవ్వడానికి ఇది తప్పనిసరి
  WidgetsFlutterBinding.ensureInitialized();
  await GameData.init(); 
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nokia Cricket Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'monospace', // రెట్రో లుక్ కోసం
      ),
      home: const HomeScreen(),
    );
  }
}
