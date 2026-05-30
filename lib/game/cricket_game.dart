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
// 8-Bit సౌండ్ ఇంజిన్
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
  
  static void cheer() {
    final freqs = [440.0, 554.0, 659.0, 880.0, 1108.0, 1318.0];
    for (int i = 0; i < freqs.length; i++) {
      Future.delayed(Duration(milliseconds: i * 60), () => tone(freqs[i], 0.1, 'square', 0.15));
    }
  }
}

// ---------------------------------------------------------
// బాల్ రకాలు & గేమ్ స్టేట్స్
// ---------------------------------------------------------
class BallType {
  final String id, label; final List<double> br; final double sm, p;
  BallType(this.id, this.label, this.br, this.sm, this.p);
}

final List<BallType> BTYPES = [
  BallType('normal', '', [70, 84], 1.0, 0.50),
  BallType('short', 'SHORT!', [50, 66], 0.9, 0.20),
  BallType('full', 'FULL', [90, 106], 1.1, 0.20),
  BallType('yorker', 'YORKER!', [114, 124], 1.3, 0.10),
];

enum GameState { BOWLING, FIELDING, RESULT }

// ---------------------------------------------------------
// కోర్ గేమ్ క్లాస్
// ---------------------------------------------------------
class CricketGame extends FlameGame with TapCallbacks {
  final Random rng = Random();

  int maxBalls = 12;
  int maxWickets = 3;
  int score = 0;
  int wickets = 0;
  int balls = 0;

  int combo = 0, maxCombo = 0, sixes = 0, fours = 0;

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

  String bLabelText = '';
  double bLabelTimer = 0;

  // --- SHOT METER VARIABLES ---
  double timingProgress = -1.0; 
  String timingLabel = '';
  double timingTimer = 0.0;

  // రియల్ ఫీల్డింగ్ క్యాచ్ లాజిక్ కోసం
  Vector2 fieldBallPos = Vector2.zero();
  Vector2 fieldBallVel = Vector2.zero();
  List<Vector2> fielders = [];
  bool fielderHasBall = false;
  bool ballThrownToCenter = false;
  double throwDelay = 0.0;
  
  bool isAerial = false; 
  double aerialLandingDistance = 0.0; 

  // మ్యాన్యువల్ రన్నింగ్
  int currentRuns = 0;
  double runProgress = 0.0; 
  bool isBatsmanRunning = false;
  double runDirection = 1.0; 

  @override
  Future<void> onLoad() async {
    camera.viewport = FixedAspectRatioViewport(aspectRatio: 120 / 160);
    add(RectangleComponent(size: Vector2(120, 160), paint: Paint()..color = const Color(0xFF8BAC0F)));

    bowler = Bowler(); batsman = Batsman(); ball = Ball();
    add(bowler); add(batsman); add(ball);
    
    Sfx.start();
  }

  BallType pickBType() {
    double r = rng.nextDouble(), c = 0;
    for (var bt in BTYPES) { c += bt.p; if (r < c) return bt; }
    return BTYPES[0];
  }

  void startBowl() {
    if (ball.isActive || bowler.phase != 'idle') return;
    bowler.phase = 'runup'; bowler.frame = 0;
    Sfx.bowl();
  }

  void releaseBall() {
    BallType bt = pickBType();
    ball.x = 60 + (rng.nextDouble() * 6 - 3);
    ball.y = 35; 
    ball.vy = 40.0 + rng.nextDouble() * 30.0; 
    ball.isActive = true; ball.bounced = false;
    ball.bounceAt = bt.br[0] + rng.nextDouble() * (bt.br[1] - bt.br[0]);
    
    if (bt.label.isNotEmpty) { bLabelText = bt.label; bLabelTimer = 0.8; }
    bowler.phase = 'deliver'; bowler.frame = 0;
  }

  List<Vector2> getFieldSetting() {
    int type = rng.nextInt(3);
    if(type == 0) { 
       return [Vector2(60, 15), Vector2(30, 25), Vector2(90, 25), Vector2(15, 60), Vector2(105, 60), Vector2(30, 95), Vector2(90, 95), Vector2(45, 45), Vector2(75, 45)];
    } else if(type == 1) { 
       return [Vector2(50, 45), Vector2(70, 45), Vector2(40, 60), Vector2(80, 60), Vector2(45, 75), Vector2(75, 75), Vector2(60, 20), Vector2(20, 30), Vector2(100, 30)];
    } else { 
       return [Vector2(60, 25), Vector2(35, 35), Vector2(85, 35), Vector2(25, 60), Vector2(95, 60), Vector2(40, 85), Vector2(80, 85), Vector2(20, 20), Vector2(100, 20)];
    }
  }

  void checkHit() {
    if (state != GameState.BOWLING || !ball.isActive || batsman.swing) return;
    batsman.swing = true; batsman.swingTimer = 0.20;

    double by = ball.y;
    double distanceToStumps = (120 - by).abs();

    // --- SHOT METER CALCULATION ---
    // Y-axis 90 to 150 range. Perfect is at 120. (60px total window)
    timingProgress = ((by - 90) / 60).clamp(0.0, 1.0);
    timingTimer = 1.5; // మీటర్ 1.5 సెకన్లు కనిపిస్తుంది

    if (distanceToStumps <= 5) { 
      // 1. PERFECT (SIX)
      timingLabel = 'PERFECT!';
      ball.isActive = false; balls++; score += 6; scoreNotifier.value = score;
      sixes++; combo++; if (combo > maxCombo) maxCombo = combo;
      rMsg = 'SIX!'; 
      Sfx.hit(); Sfx.six(); Sfx.cheer(); 
      HapticFeedback.heavyImpact(); 
      endBall(2.0);
    } 
    else if (distanceToStumps <= 12) { 
      // 2. GOOD (FOUR)
      timingLabel = by < 120 ? 'EARLY' : 'LATE'; 
      if (distanceToStumps <= 8) timingLabel = 'GOOD!'; // Close to perfect
      
      ball.isActive = false; balls++; score += 4; scoreNotifier.value = score;
      fours++; combo++; if (combo > maxCombo) maxCombo = combo;
      rMsg = 'FOUR!'; 
      Sfx.hit(); Sfx.four(); Sfx.cheer(); 
      HapticFeedback.mediumImpact(); 
      endBall(2.0);
    } 
    else if (distanceToStumps <= 25) { 
      // 3. OKAY (FIELDING)
      timingLabel = by < 120 ? 'EARLY' : 'LATE';
      
      ball.isActive = false; balls++;
      combo++; if (combo > maxCombo) maxCombo = combo;
      Sfx.hit(); HapticFeedback.lightImpact();
      setupFielding(1.0 - (distanceToStumps / 25));
    } 
    else { 
      // 4. MISS
      if (by < 120) {
        timingLabel = 'TOO EARLY';
        ball.isActive = false; balls++; combo = 0; 
        rMsg = 'Missed'; Sfx.miss(); endBall(1.0);
      } else {
        timingLabel = 'TOO LATE';
      }
    }
  }

  void setupFielding(double power) {
    state = GameState.FIELDING;
    currentRuns = 0; runProgress = 0.0; isBatsmanRunning = false; runDirection = 1.0;
    fielderHasBall = false; ballThrownToCenter = false;

    fieldBallPos = Vector2(60, 60); 
    
    double angle = (rng.nextDouble() * pi * 1.5) - (pi * 0.75); 
    double speed = 30.0 + (power * 70.0); 
    fieldBallVel = Vector2(sin(angle) * speed, -cos(angle) * speed);

    isAerial = power > 0.6 && rng.nextBool(); 
    aerialLandingDistance = isAerial ? (25.0 + power * 45.0) : 0.0; 

    fielders = getFieldSetting();
  }

  void endBall(double delay) {
    state = GameState.RESULT; rTimer = delay; bowler.phase = 'idle'; bowler.frame = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameOverNotifier.value) return;

    // Shot Meter Timer 
    if (timingTimer > 0) timingTimer -= dt;
    if (bLabelTimer > 0) bLabelTimer -= dt;

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
          ball.vy = ball.vy * 0.7 + 20; ball.bounced = true; Sfx.bounce();
        }
        
        ball.y += ball.vy * dt;

        if (ball.y >= 120 && ball.y <= 126 && (ball.x - 60).abs() < 5) {
          ball.isActive = false; wickets++; balls++; combo = 0; 
          wicketNotifier.value = wickets; batsman.stumpBroken = true;
          rMsg = 'Bowled!'; Sfx.outWicket(); 
          HapticFeedback.heavyImpact(); endBall(2.0);
        } else if (ball.y > 140) {
          ball.isActive = false; balls++; combo = 0; 
          rMsg = 'Dot'; endBall(1.0);
        }
      }

      if (batsman.swing) {
        batsman.swingTimer -= dt; if (batsman.swingTimer <= 0) batsman.swing = false;
      }
    } 
    else if (state == GameState.FIELDING) {
      Vector2 center = Vector2(60, 60);

      if (!fielderHasBall && !ballThrownToCenter) {
        fieldBallPos += fieldBallVel * dt;
        double distTraveled = fieldBallPos.distanceTo(center);

        if (isAerial && distTraveled >= aerialLandingDistance) {
          isAerial = false; Sfx.bounce();
        }

        if (distTraveled >= 48) {
          if (isAerial) {
            score += 6; scoreNotifier.value = score; sixes++;
            combo++; if (combo > maxCombo) maxCombo = combo;
            rMsg = 'SIX!'; Sfx.six(); Sfx.cheer(); HapticFeedback.heavyImpact();
          } else {
            score += 4; scoreNotifier.value = score; fours++;
            combo++; if (combo > maxCombo) maxCombo = combo;
            rMsg = 'FOUR!'; Sfx.four(); Sfx.cheer(); HapticFeedback.mediumImpact();
          }
          endBall(2.0); return; 
        }

        for (var f in fielders) {
          if (f.distanceTo(fieldBallPos) < 4) {
            if (isAerial) {
              wickets++; wicketNotifier.value = wickets; combo = 0;
              rMsg = 'Catch Out!'; Sfx.outWicket(); HapticFeedback.heavyImpact();
              endBall(2.0); return;
            } else {
              fielderHasBall = true; throwDelay = 0.4; 
              fieldBallVel = Vector2.zero(); break;
            }
          } else {
            f += (fieldBallPos - f).normalized() * 40 * dt; 
          }
        }
      } 
      else if (fielderHasBall) {
        throwDelay -= dt;
        if (throwDelay <= 0) { fielderHasBall = false; ballThrownToCenter = true; }
      } 
      else if (ballThrownToCenter) {
        fieldBallPos += (center - fieldBallPos).normalized() * 80 * dt;
        if (fieldBallPos.distanceTo(center) < 3) {
          if (isBatsmanRunning && runProgress > 0.05 && runProgress < 0.95) {
            wickets++; wicketNotifier.value = wickets; combo = 0;
            rMsg = 'Run Out!'; Sfx.outWicket(); HapticFeedback.heavyImpact(); endBall(2.0);
          } else {
            score += currentRuns; scoreNotifier.value = score;
            rMsg = currentRuns > 0 ? '$currentRuns Run${currentRuns > 1 ? 's' : ''}' : 'Dot'; 
            endBall(1.5);
          }
        }
      }

      if (isBatsmanRunning) {
        runProgress += runDirection * 1.2 * dt; 
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
      if (!isBatsmanRunning) { isBatsmanRunning = true; }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final pDark = Paint()..color = const Color(0xFF0F380F);
    final pLight = Paint()..color = const Color(0xFF306230);
    final pDarkStroke = Paint()..color = const Color(0xFF0F380F)..style = PaintingStyle.stroke..strokeWidth = 1;

    if (state == GameState.BOWLING || state == GameState.RESULT) {
      canvas.drawLine(const Offset(45, 30), const Offset(20, 130), pDarkStroke);
      canvas.drawLine(const Offset(75, 30), const Offset(100, 130), pDarkStroke);
      canvas.drawLine(const Offset(47, 35), const Offset(73, 35), pDarkStroke);
      canvas.drawLine(const Offset(25, 120), const Offset(95, 120), pDarkStroke);
      
      Path pitchPath = Path()..moveTo(45, 30)..lineTo(75, 30)..lineTo(100, 130)..lineTo(20, 130)..close();
      canvas.drawPath(pitchPath, Paint()..color = const Color(0x110F380F));

      final textP = TextPaint(style: const TextStyle(fontFamily: 'NokiaPixel', color: Color(0xFF0F380F), fontSize: 6, fontWeight: FontWeight.bold));
      if (bLabelTimer > 0) textP.render(canvas, bLabelText, Vector2(60, 50), anchor: Anchor.center);

    } else if (state == GameState.FIELDING) {
      canvas.drawCircle(const Offset(60, 60), 48, Paint()..color = const Color(0xFF306230)..style = PaintingStyle.stroke..strokeWidth = 1);
      canvas.drawCircle(const Offset(60, 60), 25, Paint()..color = const Color(0xFF306230)..style = PaintingStyle.stroke..strokeWidth = 1);
      canvas.drawRect(const Rect.fromLTWH(56, 52, 8, 16), pLight);
      
      for (var f in fielders) canvas.drawRect(Rect.fromCenter(center: Offset(f.x, f.y), width: 3, height: 3), pDark);
      canvas.drawCircle(Offset(fieldBallPos.x, fieldBallPos.y), 1.5, pDark);

      canvas.drawRect(const Rect.fromLTWH(105, 40, 8, 40), Paint()..color=const Color(0xFF306230)..style=PaintingStyle.stroke);
      double runnerY = 77 - (runProgress * 34);
      canvas.drawRect(Rect.fromLTWH(106, runnerY, 6, 4), pDark); 
    }

    // --- SHOT METER UI ---
    if (timingTimer > 0) {
      double mx = 5; double my = 35; double mw = 6; double mh = 60;
      
      // అవుట్ లైన్ (Background)
      canvas.drawRect(Rect.fromLTWH(mx, my, mw, mh), Paint()..color = const Color(0xFF306230)..style = PaintingStyle.stroke);
      
      // పర్ఫెక్ట్ జోన్ (Middle)
      double perfectY = my + (mh * 0.4);
      double perfectH = mh * 0.2;
      canvas.drawRect(Rect.fromLTWH(mx, perfectY, mw, perfectH), pDark);

      // ప్లేయర్ ట్యాప్ చేసిన పాయింట్ (Indicator)
      double indY = my + (timingProgress * mh);
      canvas.drawLine(Offset(mx - 2, indY), Offset(mx + mw + 2, indY), Paint()..color = const Color(0xFF0F380F)..strokeWidth = 2);

      // టెక్స్ట్ లేబుల్ (PERFECT! / EARLY / LATE)
      final tp = TextPaint(style: const TextStyle(fontFamily: 'NokiaPixel', color: Color(0xFF0F380F), fontSize: 8, fontWeight: FontWeight.bold));
      tp.render(canvas, timingLabel, Vector2(mx + 12, indY - 4));
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

class Ball extends Component with HasGameRef<CricketGame> {
  double x = 60, y = 35, vy = 0, bounceAt = 0;
  bool isActive = false, bounced = false;
  
  @override void render(Canvas canvas) {
    if (!isActive || gameRef.state != GameState.BOWLING) return;
    canvas.drawCircle(Offset(x, y), 1.5, Paint()..color = const Color(0xFF0F380F));
  }
}

class Bowler extends Component with HasGameRef<CricketGame> {
  double x = 60, y = 25; 
  String phase = 'idle'; int frame = 0;
  
  @override void render(Canvas canvas) {
    if (gameRef.state != GameState.BOWLING) return;
    final pLine = Paint()..color = const Color(0xFF0F380F)..strokeWidth = 1.5;
    
    canvas.drawRect(Rect.fromLTWH(x - 1, y - 5, 2, 2), Paint()..color = const Color(0xFF0F380F));
    canvas.drawLine(Offset(x, y - 3), Offset(x, y + 1), pLine);

    if (phase == 'idle') { 
      canvas.drawLine(Offset(x, y + 1), Offset(x - 1, y + 3), pLine); 
      canvas.drawLine(Offset(x, y + 1), Offset(x + 1, y + 3), pLine);
    } else if (phase == 'runup') { 
      int f = (frame / 4).floor() % 2; 
      if (f == 0) {
        canvas.drawLine(Offset(x, y + 1), Offset(x - 1, y + 3), pLine); 
        canvas.drawLine(Offset(x, y + 1), Offset(x + 1, y + 1), pLine); 
      } else {
        canvas.drawLine(Offset(x, y + 1), Offset(x - 1, y + 1), pLine); 
        canvas.drawLine(Offset(x, y + 1), Offset(x + 1, y + 3), pLine); 
      }
    } else if (phase == 'deliver') { 
      canvas.drawLine(Offset(x, y - 2), Offset(x + 2, y - 3), pLine); 
      canvas.drawLine(Offset(x, y + 1), Offset(x - 1, y + 3), pLine); 
    }
  }
}

class Batsman extends Component with HasGameRef<CricketGame> {
  double x = 60, y = 115, swingTimer = 0; 
  bool swing = false, stumpBroken = false;
  
  @override void render(Canvas canvas) {
    if (gameRef.state != GameState.BOWLING) return;
    final pDark = Paint()..color = const Color(0xFF0F380F); 
    final pLine = Paint()..color = const Color(0xFF0F380F)..strokeWidth = 2.0;

    if (!stumpBroken) { 
      canvas.drawRect(Rect.fromLTWH(x - 4, y - 5, 1, 6), pDark);
      canvas.drawRect(Rect.fromLTWH(x - 2, y - 5, 1, 6), pDark);
      canvas.drawRect(Rect.fromLTWH(x, y - 5, 1, 6), pDark);
    } else { 
      canvas.drawRect(Rect.fromLTWH(x - 4, y - 2, 1, 3), pDark);
      canvas.drawRect(Rect.fromLTWH(x - 2, y, 3, 1), pDark);
    }

    canvas.drawRect(Rect.fromLTWH(x + 3, y - 8, 2, 2), pDark); 
    canvas.drawLine(Offset(x + 4, y - 6), Offset(x + 4, y - 1), pLine); 
    canvas.drawLine(Offset(x + 4, y - 1), Offset(x + 3, y + 3), pLine); 
    canvas.drawLine(Offset(x + 4, y - 1), Offset(x + 5, y + 3), pLine); 
    
    if (swing) { 
      canvas.drawLine(Offset(x + 4, y - 3), Offset(x - 5, y - 2), pLine); 
    } else { 
      canvas.drawLine(Offset(x + 4, y - 3), Offset(x, y + 3), pLine); 
    }
  }
}
