import 'package:flutter/material.dart';
import 'game_data.dart';
import 'screens/home_screen.dart'; // పాత్ కరెక్ట్ గా ఉండాలి

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameData.init(); 
  
  // const తీసేసాం, ఎందుకంటే HomeScreen స్టేట్‌ఫుల్ విడ్జెట్
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
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
      ),
      home: const HomeScreen(), // ఇక్కడ const వద్దు అని ఎర్రర్ వస్తే const తీసేయండి
      
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            IgnorePointer(
              child: CustomPaint(
                painter: GlobalScanlinePainter(),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.04),
                        Colors.transparent,
                        Colors.black.withOpacity(0.05),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class GlobalScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintH = Paint()
      ..color = Colors.black.withOpacity(0.05)
      ..strokeWidth = 1.0;

    final paintV = Paint()
      ..color = Colors.black.withOpacity(0.03)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.height; i += 2) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paintH);
    }
    for (double i = 0; i < size.width; i += 2) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paintV);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
