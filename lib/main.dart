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
        scaffoldBackgroundColor: Colors.black, // వైట్ ఫ్లాష్ రాకుండా బ్లాక్ చేశాం
        canvasColor: Colors.black,
      ),
      home: const HomeScreen(),
      
      // ఇక్కడ builder వాడటం వల్ల యాప్ మొత్తానికి (అన్ని స్క్రీన్స్ పైన) ఈ ఎఫెక్ట్ అప్లై అవుతుంది
      builder: (context, child) {
        return Stack(
          children: [
            // మీ అసలైన యాప్ స్క్రీన్స్ (Home, Shop, Game etc.)
            if (child != null) child,
            
            // -------------------------------------------------
            // గ్లోబల్ పిక్సెల్ & గ్లేర్ ఎఫెక్ట్ (టచ్‌కి అడ్డు రాకుండా IgnorePointer)
            // -------------------------------------------------
            IgnorePointer(
              child: CustomPaint(
                painter: GlobalScanlinePainter(),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.04), // స్క్రీన్ మీద చిన్న మెరుపు
                        Colors.transparent,
                        Colors.black.withOpacity(0.05), // స్క్రీన్ కింద షాడో
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

// ----------------------------------------------------
// యాప్ మొత్తానికి పిక్సెల్ గ్రిడ్ ఎఫెక్ట్ గీసే పెయింటర్
// ----------------------------------------------------
class GlobalScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintH = Paint()
      ..color = Colors.black.withOpacity(0.05) // అడ్డంగా గీతలు
      ..strokeWidth = 1.0;

    final paintV = Paint()
      ..color = Colors.black.withOpacity(0.03) // నిలువుగా గీతలు
      ..strokeWidth = 1.0;

    // Horizontal Lines (Scanlines)
    for (double i = 0; i < size.height; i += 2) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paintH);
    }
    
    // Vertical Lines (LCD Pixel Grid)
    for (double i = 0; i < size.width; i += 2) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paintV);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
