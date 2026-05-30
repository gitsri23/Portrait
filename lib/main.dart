import 'package:flutter/material.dart';
import 'game_data.dart';
import 'screens/home_screen.dart';

void main() async {
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
        fontFamily: 'NokiaPixel',
        scaffoldBackgroundColor: Colors.black, // వైట్ ఫ్లాష్ ఆపడానికి ఇది ముఖ్యం!
        canvasColor: Colors.black,
      ),
      home: const HomeScreen(),
    );
  }
}
