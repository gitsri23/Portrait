import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/theme.dart';
import 'presentation/screens/camera_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  runApp(const CinematicApp());
}

Future<void> _requestPermissions() async {
  await [
    Permission.camera,
    Permission.microphone,
    Permission.storage,
  ].request();
}

class CinematicApp extends StatelessWidget {
  const CinematicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cinematic Camera',
      debugShowCheckedModeBanner: false,
      theme: CinematicTheme.theme,
      home: const CameraScreen(),
    );
  }
}
