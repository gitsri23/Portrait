import 'dart:math';
import 'dart:typed_data';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

// ---------------------------------------------------------
// నోకియా 8-Bit సౌండ్ ఇంజిన్ (Cheerup, Haptics తో)
// ---------------------------------------------------------
class Sfx {
  static final List<AudioPlayer> _players = List.generate(5, (_) => AudioPlayer());
  static int _pIdx = 0;

  static void tone(double f, double d, [String t = 'square', double v = 0.25]) {
    try {
      int sampleRate = 44100;
      int numSamples = (sampleRate * d).toInt();
      int byteRate = sampleRate * 2;
      var bytes = Uint8List(44 + numSamples * 2);
      var header = ByteData.view(bytes.buffer);
      
      bytes[0] = 82; bytes[1] = 73; bytes[2] = 70; bytes[3] = 70; 
      header.setUint32(4, 36 + numSamples * 2, Endian.little);
      bytes[8] = 87; bytes[9] = 65; bytes[10] = 86; bytes[11] = 69; 
      bytes[12] = 102; bytes[13] = 109; bytes[14] = 116; bytes[15] = 32; 
      header.setUint32(16, 16, Endian.little);
      header.setUint16(20, 1, Endian.little);
      header.setUint16(22, 1, Endian.little);
      header.setUint32(24, sampleRate, Endian.little);
      header.setUint32(28, byteRate, Endian.little);
      header.setUint16(32, 2, Endian.little);
      header.setUint16(34, 16, Endian.little);
      bytes[36] = 100; bytes[37] = 97; bytes[38] = 116; bytes[39] = 97; 
      header.setUint32(40, numSamples * 2, Endian.little);
      
      for (int i = 0; i < numSamples; ++i) {
        double time = i / sampleRate;
        double val = 0.0;
        if (t == 'square') val = sin(2 * pi * f * time) >= 0 ? 1.0 : -1.0;
        else if (t == 'sawtooth') val = 2.0 * (time * f - (time * f + 0.5).floor());
        else val = sin(2 * pi * f * time);
        
        double env = exp(-5.0 * time / d); 
        val = val * env * v;
        int sample = (val * 32767).toInt().clamp(-32768, 32767);
        header.setInt16(44 + i * 2, sample, Endian.little);
      }
      _players[_pIdx].play(BytesSource(bytes));
      _pIdx = (_pIdx + 1) % _players.length;
    } catch (e) {}
  }

  static void start() { tone(440, 0.08); Future.delayed(const Duration(milliseconds: 90), () => tone(660, 0.1)); }
  static void bowl() => tone(200, 0.05, 'square', 0.12);
  static void bounce() => tone(155, 0.04, 'square', 0.09);
  static void hit() => tone(700, 0.06, 'square', 0.2);
  static void one() => tone(550, 0.08);
  static void four() { final freqs = [440.0, 554.0, 659.0]; for (int i = 0; i < freqs.length; i++) { Future.delayed(Duration(milliseconds: i * 65), () => tone(freqs[i], 0.12)); } }
  static void six() { final freqs = [523.0, 659.0, 784.0, 1047.0]; for (int i = 0; i < freqs.length; i++) { Future.delayed(Duration(milliseconds: i * 75), () => tone(freqs[i], 0.15)); } }
  static void outWicket() { final freqs = [300.0, 220.0, 160.0]; for (int i = 0; i < freqs.length; i++) { Future.delayed(Duration(milliseconds: i * 90), () => tone(freqs[i], 0.2, 'sawtooth')); } }
  static void miss() => tone(180, 0.18, 'sawtooth', 0.18);
  static void over() { final freqs = [330.0, 280.0, 220.0]; for (int i = 0; i < freqs.length; i++) { Future.delayed(Duration(milliseconds: i * 120), () => tone(freqs[i], 0.3, 'square', 0.15)); } }
  
  // సిక్స్ కొట్టినప్పుడు cheerup sound
  static void cheer() {
    for (int i = 0; i < 8; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () => tone(400.0 + Random().nextInt(400), 0.1, 'sawtooth', 0.12));
    }
  }
}

// ---------------------------------------------------------
// గేమ్ స్టేట్స్ & లాజిక్
// ---------------------------------------------------------
enum GameState { BOWLING, FIELDING, RESULT }

class CricketGame extends FlameGame with TapCallbacks {
  final Random rng = Random();

  int maxBalls = 12;
  int maxWickets = 3;
  int score = 0;
  int wickets = 0;
  int balls = 0;

  int combo = 0;
  int maxCombo = 0;
  int sixes = 0;
  int fours = 0;

  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> wicketNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> gameOverNotifier = ValueNotifier<bool>(false);

  GameState state = GameState.BOWLING;
  
  late Bowler bowler;
  late Batsman batsman;
  late Ball ball;
  
  String rMsg = '';
  double rTimer = 0;
  double bowlT = 1.0;

  // Fielding Variables (For Manual Running)
  Vector2 fieldBallPos = Vector2.zero();
  Vector2 fieldBallVel = Vector2.zero();
  List<Vector2> fielders = [];
  bool fielderHasBall = false;
  bool ballThrownToCenter = false;
  double throwDelay = 0.0;
  
  // Manual Run Variables
  int currentRuns = 0;
  double runProgress = 0.0; // 0.0 to 1.0
  bool isBatsmanRunning = false;
  double runDirection = 1.0; 

  @override
  Future<void> onLoad() async {
    camera.viewport = FixedAspectRatioViewport(aspectRatio: 120 / 160);
    add(RectangleComponent(size: Vector2(120, 160), paint: Paint()..color = const Color(0xFF8BAC0F)));

    // మోడల్స్
    bowler = Bowler(); batsman = Batsman(); ball = Ball();
    add(bowler); add(batsman); add(ball);
    
    Sfx.start();
  }

  void startBowl() {
    if (ball.isActive || bowler.phase != 'idle') return;
    bowler.phase = 'runup'; bowler.frame = 0;
    Sfx.bowl();
  }

  void releaseBall() {
    ball.x = 60 + (rng.nextDouble() * 6 - 3);
    ball.y = 35; 
    // బంతి వేగం పెంచాను (సిక్స్‌ల కోసం)
    ball.vy = 45.0 + rng.nextDouble() * 40.0; 
    ball.isActive = true; ball.bounced = false;
    ball.bounceAt = 70 + rng.nextDouble() * 30;
    bowler.phase = 'deliver'; bowler.frame = 0;
  }

  void checkHit() {
    if (state != GameState.BOWLING || !ball.isActive || batsman.swing) return;
    batsman.swing = true; batsman.swingTimer = 0.20;

    // సిక్స్ మరియు ఫోర్ కోసం టైమింగ్ మరియు పొజిషన్ చెక్
    double distanceToStumps = (120 - ball.y).abs();

    if (distanceToStumps <= 5) {
      // 1. PERFECT TIMING (SIX)
      ball.isActive = false; balls++; score += 6; scoreNotifier.value = score;
      sixes++; combo++; if (combo > maxCombo) maxCombo = combo;
      rMsg = 'Six!'; 
      Sfx.hit(); Sfx.six(); Sfx.cheer(); 
      HapticFeedback.heavyImpact(); // సిక్స్ కొట్టినప్పుడు ఫోన్ వైబ్రేషన్
      endBall(2.0);
    } 
    else if (distanceToStumps <= 10) {
      // 2. GOOD TIMING (FOUR)
      ball.isActive = false; balls++; score += 4; scoreNotifier.value = score;
      fours++; combo++; if (combo > maxCombo) maxCombo = combo;
      rMsg = 'Four!'; 
      Sfx.hit(); Sfx.four(); Sfx.cheer(); 
      HapticFeedback.mediumImpact(); 
      endBall(2.0);
    } 
    else if (distanceToStumps <= 25) {
      // 3. OKAY TIMING (FIELDING - Manual Runs)
      ball.isActive = false; balls++;
      combo++; if (combo > maxCombo) maxCombo = combo;
      Sfx.hit(); 
      HapticFeedback.lightImpact();
      setupFielding(distanceToStumps);
    } 
    else {
      // 4. MISS (Too early or too late)
      if (ball.y < 120) {
        ball.isActive = false; balls++; combo = 0; 
        rMsg = 'Missed'; Sfx.miss(); endBall(1.0);
      }
    }
  }

  void setupFielding(double distance) {
    state = GameState.FIELDING;
    currentRuns = 0;
    runProgress = 0.0;
    isBatsmanRunning = false;
    runDirection = 1.0;
    fielderHasBall = false;
    ballThrownToCenter = false;

    fieldBallPos = Vector2(60, 100); 
    double angle = (rng.nextDouble() * pi) - (pi / 2); 
    // టైమింగ్ బట్టి బంతి వేగం మారుతుంది
    double speed = distance <= 16 ? 75.0 : 40.0; 
    fieldBallVel = Vector2(sin(angle) * speed, -cos(angle) * speed);

    // ఫీల్డర్లను పిచ్ చుట్టూ పెట్టాను
    fielders.clear();
    for (int i = 0; i < 4; i++) {
      fielders.add(Vector2(15 + rng.nextDouble() * 90, 15 + rng.nextDouble() * 70));
    }
  }

  void endBall(double delay) {
    state = GameState.RESULT; rTimer = delay; bowler.phase = 'idle'; bowler.frame = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameOverNotifier.value) return;

    if (state == GameState.BOWLING) {
      if (bowler.phase == 'runup') {
        bowler.frame++; if (bowler.frame >= 15) releaseBall();
      } else if (bowler.phase == 'deliver') {
        bowler.frame++; if (bowler.frame > 8) { bowler.phase = 'idle'; bowler.frame = 0; }
      } else if (bowler.phase == 'idle' && !ball.isActive) {
        bowlT -= dt; if (bowlT <= 0) startBowl();
      }

      if (ball.isActive) {
        if (!ball.bounced && ball.y >= ball.bounceAt) {
          ball.vy = ball.vy * 0.7 + 25; ball.bounced = true; Sfx.bounce();
        }
        
        ball.y += ball.vy * dt;

        // బౌల్డ్ లాజిక్
        if (ball.y >= 120 && ball.y <= 126 && (ball.x - 60).abs() < 5) {
          ball.isActive = false; wickets++; balls++; combo = 0; 
          wicketNotifier.value = wickets; batsman.stumpBroken = true;
          rMsg = 'Bowled!'; Sfx.outWicket(); 
          HapticFeedback.heavyImpact();
          endBall(2.0);
        } else if (ball.y > 140) {
          ball.isActive = false; balls++; combo = 0; 
          rMsg = 'Dot'; endBall(1.0);
        }
      }

      if (batsman.swing) {
        batsman.swingTimer -= dt; if (batsman.swingTimer <= 0) batsman.swing = false;
      }
    } 
    // ---------------------------------------
    // ఫీల్డింగ్ & రన్నింగ్ లాజిక్ (CORRECTED)
    // ---------------------------------------
    else if (state == GameState.FIELDING) {
      Vector2 center = Vector2(60, 60);

      // 1. బంతి బౌండరీకి వెళ్ళడం/ఆగిపోవడం
      if (!fielderHasBall && !ballThrownToCenter) {
        fieldBallPos += fieldBallVel * dt;
        
        // **కరెక్టెడ్ లాజిక్**: బంతి బౌండరీ (48 రేడియస్) టచ్ అయితే, వెంటనే "Four!" వెళ్ళిపోతుంది.
        if (fieldBallPos.distanceTo(center) >= 48) {
          score += 4; scoreNotifier.value = score;
          fours++; combo++; if (combo > maxCombo) maxCombo = combo;
          rMsg = 'Four!'; 
          Sfx.four(); Sfx.cheer(); 
          HapticFeedback.mediumImpact();
          endBall(2.0); // ఫీల్డింగ్ స్టేజ్ ఇక్కడితో ఆగిపోతుంది.
          return;
        }

        // బంతి మధ్యలో ఆగిపోతే, ఫీల్డర్స్ దాని వైపు పరిగెత్తుకుంటూ వెళ్తారు
        for (var f in fielders) {
          if (f.distanceTo(fieldBallPos) < 4) {
            fielderHasBall = true;
            throwDelay = 0.4; // బంతిని తీసుకుని విసిరేందుకు చిన్న గ్యాప్
            break;
          } else {
            f += (fieldBallPos - f).normalized() * 50 * dt; 
          }
        }
      } 
      // 2. ఫీల్డర్ బంతిని పట్టుకున్నాడు
      else if (fielderHasBall) {
        throwDelay -= dt;
        if (throwDelay <= 0) {
          fielderHasBall = false;
          ballThrownToCenter = true;
        }
      } 
      // 3. బంతిని వికెట్ కీపర్‌కి విసిరాడు
      else if (ballThrownToCenter) {
        fieldBallPos += (center - fieldBallPos).normalized() * 80 * dt;
        
        // బంతి కీపర్ దగ్గరికి వచ్చినప్పుడు, రన్ అవుట్ చెక్ చేస్తాం
        if (fieldBallPos.distanceTo(center) < 3) {
          if (isBatsmanRunning && runProgress > 0.05 && runProgress < 0.95) {
            // క్రీజ్ వెలుపల ఉన్నాడు -> రన్ అవుట్!
            wickets++; wicketNotifier.value = wickets; combo = 0;
            rMsg = 'Run Out!'; Sfx.outWicket(); 
            HapticFeedback.heavyImpact();
            endBall(2.0);
          } else {
            // సేఫ్!
            score += currentRuns; scoreNotifier.value = score;
            rMsg = currentRuns > 0 ? '$currentRuns Run${currentRuns > 1 ? 's' : ''}' : 'Dot'; 
            endBall(1.5);
          }
        }
      }

      // 4. బ్యాట్స్‌మాన్ మ్యాన్యువల్ రన్నింగ్
      if (isBatsmanRunning) {
        runProgress += runDirection * 1.2 * dt; // పరుగు వేగం
        if (runProgress >= 1.0) {
          runProgress = 1.0; isBatsmanRunning = false; runDirection = -1.0; 
          currentRuns++; Sfx.one();
        } else if (runProgress <= 0.0) {
          runProgress = 0.0; isBatsmanRunning = false; runDirection = 1.0; 
          currentRuns++; Sfx.one();
        }
      }
    } 
    else if (state == GameState.RESULT) {
      rTimer -= dt;
      if (rTimer <= 0) {
        batsman.stumpBroken = false;
        if (balls >= maxBalls || wickets >= maxWickets) {
          Sfx.over(); gameOverNotifier.value = true;
        } else {
          state = GameState.BOWLING; ball.isActive = false; bowler.phase = 'idle'; bowlT = 0.8;
        }
      }
    }
  }

  @override
  void onTapDown(TapDownEvent event) { super.onTapDown(event); onTap(); }
  
  void onTap() { 
    if (gameOverNotifier.value) return;

    if (state == GameState.BOWLING) {
      checkHit();
    } else if (state == GameState.FIELDING) {
      // ఫీల్డింగ్ స్టేజ్‌లో స్క్రీన్ ట్యాప్ చేస్తే రన్ చేయడం స్టార్ట్ చేస్తాడు
      if (!isBatsmanRunning) {
        isBatsmanRunning = true;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final pDark = Paint()..color = const Color(0xFF0F380F);
    final pLight = Paint()..color = const Color(0xFF306230);

    if (state == GameState.BOWLING || state == GameState.RESULT) {
      // Perspective Pitch
      canvas.drawLine(const Offset(45, 30), const Offset(20, 130), pDark..strokeWidth=1);
      canvas.drawLine(const Offset(75, 30), const Offset(100, 130), pDark..strokeWidth=1);
      canvas.drawLine(const Offset(47, 35), const Offset(73, 35), pDark);
      canvas.drawLine(const Offset(25, 120), const Offset(95, 120), pDark);
      
      Path pitchPath = Path()..moveTo(45, 30)..lineTo(75, 30)..lineTo(100, 130)..lineTo(20, 130)..close();
      canvas.drawPath(pitchPath, Paint()..color = const Color(0x110F380F));

    } else if (state == GameState.FIELDING) {
      // Top-Down Radar View
      canvas.drawCircle(const Offset(60, 60), 48, Paint()..color = const Color(0xFF306230)..style = PaintingStyle.stroke..strokeWidth = 1);
      canvas.drawCircle(const Offset(60, 60), 25, Paint()..color = const Color(0xFF306230)..style = PaintingStyle.stroke..strokeWidth = 1);
      canvas.drawRect(const Rect.fromLTWH(56, 52, 8, 16), pLight);
      
      for (var f in fielders) canvas.drawRect(Rect.fromCenter(center: Offset(f.x, f.y), width: 3, height: 3), pDark);
      canvas.drawRect(Rect.fromCenter(center: Offset(fieldBallPos.x, fieldBallPos.y), width: 2, height: 2), pDark);

      // Running HUD
      canvas.drawRect(const Rect.fromLTWH(105, 40, 8, 40), Paint()..color=const Color(0xFF306230)..style=PaintingStyle.stroke);
      double runnerY = 77 - (runProgress * 34);
      canvas.drawRect(Rect.fromLTWH(106, runnerY, 6, 4), pDark); 
    }

    if (state == GameState.RESULT) {
      if (rMsg.isNotEmpty) {
        canvas.drawRect(const Rect.fromLTWH(25, 60, 70, 20), Paint()..color = const Color(0xFF8BAC0F));
        canvas.drawRect(const Rect.fromLTWH(25, 60, 70, 20), Paint()..color = const Color(0xFF0F380F)..style=PaintingStyle.stroke..strokeWidth=2);
        final rPaint = TextPaint(style: const TextStyle(fontFamily: 'NokiaPixel', color: Color(0xFF0F380F), fontSize: 10, fontWeight: FontWeight.bold));
        rPaint.render(canvas, rMsg, Vector2(60, 70), anchor: Anchor.center);
      }
    }
  }
}

// ---------------------------------------------------------
// నోకియా విజువల్ మోడల్స్ (Round Ball & Stick Figures)
// ---------------------------------------------------------

// **బంతి మోడల్ (Round గా)**
class Ball extends Component with HasGameRef<CricketGame> {
  double x = 60, y = 35, vy = 0, bounceAt = 0;
  bool isActive = false, bounced = false;
  
  @override void render(Canvas canvas) {
    if (!isActive || gameRef.state != GameState.BOWLING) return;
    // సింపుల్ Monochrome గుండ్రటి బంతి
    canvas.drawRect(Rect.fromLTWH(x - 1, y - 1, 2, 2), Paint()..color = const Color(0xFF0F380F));
  }
}

// **బౌలర్ మోడల్ (Stick Figure గా)**
class Bowler extends Component with HasGameRef<CricketGame> {
  double x = 60, y = 25; 
  String phase = 'idle'; int frame = 0;
  
  @override void render(Canvas canvas) {
    if (gameRef.state != GameState.BOWLING) return;
    final p0 = Paint()..color = const Color(0xFF0F380F);
    void p(double px, double py, double w, double h) => canvas.drawRect(Rect.fromLTWH(px, py, w, h), p0);

    // నోకియా వీడియోలో లాగా స్టిక్ ఫిగర్ సిల్హౌట్
    p(x - 1, y - 4, 2, 2); // తల (round-ish)
    p(x - 1, y - 1, 2, 4); // బాడీ
    
    if (phase == 'idle') { 
      p(x - 2, y + 3, 1, 2); p(x + 1, y + 3, 1, 2); // రెండు కాళ్లు
    } else if (phase == 'runup') { 
      int f = (frame / 4).floor() % 2; 
      if (f == 0) { p(x - 2, y + 3, 1, 2); p(x + 1, y + 2, 1, 1); } 
      else { p(x - 2, y + 2, 1, 1); p(x + 1, y + 3, 1, 2); } 
    } else if (phase == 'deliver') { 
      p(x + 1, y - 2, 3, 1); // బంతి వేస్తున్న చెయ్యి
      p(x - 2, y + 3, 1, 2); 
    }
  }
}

// **బ్యాట్స్‌మాన్ మోడల్ (Stick Figure గా)**
class Batsman extends Component with HasGameRef<CricketGame> {
  double x = 60, y = 115, swingTimer = 0; 
  bool swing = false, stumpBroken = false;
  
  @override void render(Canvas canvas) {
    if (gameRef.state != GameState.BOWLING) return;
    final p0 = Paint()..color = const Color(0xFF0F380F); 
    void p(double px, double py, double w, double h) => canvas.drawRect(Rect.fromLTWH(px, py, w, h), p0);

    // స్టంప్స్
    if (!stumpBroken) { p(x-3, y-4, 1, 5); p(x-1, y-4, 1, 5); p(x+1, y-4, 1, 5); }
    else { p(x-3, y-1, 1, 2); p(x-1, y, 3, 1); } 

    // బ్యాట్స్‌మాన్ సిల్హౌట్ (Stick figure with details)
    p(x + 4, y - 7, 3, 3); // హెల్మెట్/తల
    p(x + 3, y - 3, 4, 6); // బాడీ
    p(x + 3, y + 3, 2, 4); // ఎడమ కాలు (ప్యాడ్)
    p(x + 6, y + 3, 1, 4); // కుడి కాలు
    
    // బ్యాట్ లైన్
    if (swing) { p(x - 8, y - 1, 11, 2); } // స్వింగ్ (అడ్డంగా)
    else { p(x + 1, y - 1, 2, 8); } // ఐడిల్ (కిందకి)
  }
}
