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
// 8-Bit సౌండ్ ఇంజిన్ (Cheer, Haptics తో సహా)
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
    for (int i = 0; i < 12; i++) {
      Future.delayed(Duration(milliseconds: i * 40), () => tone(300.0 + Random().nextInt(300), 0.1, 'sawtooth', 0.15));
    }
  }
}

// ---------------------------------------------------------
// గేమ్ స్టేట్స్ & కోర్ లాజిక్
// ---------------------------------------------------------
enum GameState { BOWLING, FIELDING, RESULT }

class CricketGame extends FlameGame with TapCallbacks {
  final Random rng = Random();

  int maxBalls = 12;
  int maxWickets = 3;
  int score = 0;
  int wickets = 0;
  int balls = 0;

  // --- STATS VARIABLES FOR ACHIEVEMENTS (FIXED) ---
  int combo = 0;
  int maxCombo = 0;
  int sixes = 0;
  int fours = 0;
  // ------------------------------------------------

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
    ball.vy = 40.0 + rng.nextDouble() * 40.0; // Dynamic speed
    ball.isActive = true; ball.bounced = false;
    ball.bounceAt = 70 + rng.nextDouble() * 30;
    bowler.phase = 'deliver'; bowler.frame = 0;
  }

  void checkHit() {
    if (state != GameState.BOWLING || !ball.isActive || batsman.swing) return;
    batsman.swing = true; batsman.swingTimer = 0.20;

    // Skill-based Timing Check: Stumps are at y=120
    double distanceToStumps = (120 - ball.y).abs();

    if (distanceToStumps <= 6) {
      // PERFECT TIMING -> SIX
      ball.isActive = false; balls++; score += 6; scoreNotifier.value = score;
      
      // Update Stats
      sixes++;
      combo++; if (combo > maxCombo) maxCombo = combo;

      rMsg = 'Six!'; 
      Sfx.hit(); Sfx.six(); Sfx.cheer(); 
      HapticFeedback.mediumImpact(); 
      endBall(2.0);
    } 
    else if (distanceToStumps <= 12) {
      // GOOD TIMING -> FOUR
      ball.isActive = false; balls++; score += 4; scoreNotifier.value = score;
      
      // Update Stats
      fours++;
      combo++; if (combo > maxCombo) maxCombo = combo;

      rMsg = 'Four!'; 
      Sfx.hit(); Sfx.four(); Sfx.cheer(); 
      HapticFeedback.lightImpact(); 
      endBall(2.0);
    } 
    else if (distanceToStumps <= 25) {
      // OKAY TIMING -> FIELDING (Manual Runs)
      ball.isActive = false; balls++;
      
      // Update Stats
      combo++; if (combo > maxCombo) maxCombo = combo;

      Sfx.hit(); 
      setupFielding(distanceToStumps);
    } 
    else {
      // POOR TIMING -> MISS
      if (ball.y < 120) {
        ball.isActive = false; balls++;
        
        // Reset Combo on Miss
        combo = 0; 
        
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
    double speed = distance <= 18 ? 60.0 : 35.0; 
    fieldBallVel = Vector2(sin(angle) * speed, -cos(angle) * speed);

    fielders.clear();
    for (int i = 0; i < 4; i++) {
      fielders.add(Vector2(20 + rng.nextDouble() * 80, 20 + rng.nextDouble() * 60));
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
        
        ball.scale = 1.0 + ((ball.y - 20) / 100) * 0.5;
        ball.y += ball.vy * dt;

        // Clean Bowled Logic
        if (ball.y >= 120 && ball.y <= 126 && (ball.x - 60).abs() < 5) {
          ball.isActive = false; wickets++; balls++; 
          combo = 0; // Reset Combo
          wicketNotifier.value = wickets; batsman.stumpBroken = true;
          rMsg = 'Bowled!'; Sfx.outWicket(); endBall(2.0);
        } else if (ball.y > 140) {
          ball.isActive = false; balls++; 
          combo = 0; // Reset Combo
          rMsg = 'Dot'; endBall(1.0);
        }
      }

      if (batsman.swing) {
        batsman.swingTimer -= dt; if (batsman.swingTimer <= 0) batsman.swing = false;
      }
    } 
    // ---------------------------------------
    // MANUAL FIELDING & RUNNING LOGIC
    // ---------------------------------------
    else if (state == GameState.FIELDING) {
      Vector2 center = Vector2(60, 60);

      // 1. Ball Movement & Boundary Clamp
      if (!fielderHasBall && !ballThrownToCenter) {
        fieldBallPos += fieldBallVel * dt;
        if (fieldBallPos.distanceTo(center) > 48) {
          fieldBallVel = Vector2.zero(); 
        }

        // Fielders chase ball
        for (var f in fielders) {
          if (f.distanceTo(fieldBallPos) < 3) {
            fielderHasBall = true;
            throwDelay = 0.5; 
          } else {
            f += (fieldBallPos - f).normalized() * 35 * dt;
          }
        }
      } 
      // 2. Fielder holds ball briefly
      else if (fielderHasBall) {
        throwDelay -= dt;
        if (throwDelay <= 0) {
          fielderHasBall = false;
          ballThrownToCenter = true;
        }
      } 
      // 3. Ball thrown back to pitch
      else if (ballThrownToCenter) {
        fieldBallPos += (center - fieldBallPos).normalized() * 60 * dt;
        
        // Ball arrives at center! Check Run Out
        if (fieldBallPos.distanceTo(center) < 3) {
          if (isBatsmanRunning && runProgress > 0.05 && runProgress < 0.95) {
            wickets++; wicketNotifier.value = wickets;
            combo = 0; // Reset Combo on Run Out
            rMsg = 'Run Out!'; Sfx.outWicket(); endBall(2.0);
          } else {
            // Safe!
            score += currentRuns; scoreNotifier.value = score;
            rMsg = '$currentRuns Run${currentRuns > 1 ? 's' : ''}'; 
            endBall(1.5);
          }
        }
      }

      // 4. Batsman Manual Running Progress
      if (isBatsmanRunning) {
        runProgress += runDirection * 0.9 * dt; 
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
      canvas.drawCircle(const Offset(60, 60), 50, Paint()..color = const Color(0xFF306230)..style = PaintingStyle.stroke..strokeWidth = 1);
      canvas.drawCircle(const Offset(60, 60), 30, Paint()..color = const Color(0xFF306230)..style = PaintingStyle.stroke..strokeWidth = 1);
      canvas.drawRect(const Rect.fromLTWH(55, 50, 10, 20), pLight);
      
      for (var f in fielders) canvas.drawRect(Rect.fromCenter(center: Offset(f.x, f.y), width: 2, height: 2), pDark);
      canvas.drawRect(Rect.fromCenter(center: Offset(fieldBallPos.x, fieldBallPos.y), width: 2, height: 2), pDark);

      // Right-side Manual Running UI
      canvas.drawRect(const Rect.fromLTWH(105, 40, 10, 40), Paint()..color=const Color(0xFF306230)..style=PaintingStyle.stroke);
      double runnerY = 75 - (runProgress * 30);
      canvas.drawRect(Rect.fromLTWH(107, runnerY, 6, 3), pDark); 
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
// కాంపోనెంట్స్: మినీమలిస్ట్ స్టిక్ ఫిగర్స్ (HasGameRef తో)
// ---------------------------------------------------------
class Ball extends Component with HasGameRef<CricketGame> {
  double x = 60, y = 35, vy = 0, bounceAt = 0;
  double scale = 1.0;
  bool isActive = false, bounced = false;
  
  @override void render(Canvas canvas) {
    if (!isActive || gameRef.state != GameState.BOWLING) return;
    double s = 2 * scale;
    canvas.drawRect(Rect.fromLTWH(x - s, y - s, s*2, s*2), Paint()..color = const Color(0xFF0F380F));
  }
}

class Bowler extends Component with HasGameRef<CricketGame> {
  double x = 60, y = 25; 
  String phase = 'idle'; int frame = 0;
  
  @override void render(Canvas canvas) {
    if (gameRef.state != GameState.BOWLING) return;
    final p0 = Paint()..color = const Color(0xFF0F380F);
    void p(double px, double py, double w, double h) => canvas.drawRect(Rect.fromLTWH(px, py, w, h), p0);

    p(x, y - 4, 1, 2); 
    if (phase == 'idle') { 
      p(x, y - 2, 1, 4); 
      p(x - 1, y + 2, 1, 2); p(x + 1, y + 2, 1, 2); 
    } else if (phase == 'runup') { 
      int f = (frame / 4).floor() % 2; 
      p(x, y - 2, 1, 4); 
      if (f == 0) { p(x - 1, y + 2, 1, 2); p(x + 1, y + 1, 1, 1); } 
      else { p(x - 1, y + 1, 1, 1); p(x + 1, y + 2, 1, 2); } 
    } else if (phase == 'deliver') { 
      p(x, y - 2, 1, 4); 
      p(x + 1, y - 3, 2, 1); 
      p(x - 1, y + 2, 1, 2); 
    }
  }
}

class Batsman extends Component with HasGameRef<CricketGame> {
  double x = 60, y = 115, swingTimer = 0; 
  bool swing = false, stumpBroken = false;
  
  @override void render(Canvas canvas) {
    if (gameRef.state != GameState.BOWLING) return;
    final p0 = Paint()..color = const Color(0xFF0F380F); 
    void p(double px, double py, double w, double h) => canvas.drawRect(Rect.fromLTWH(px, py, w, h), p0);

    if (!stumpBroken) { p(x-4, y-5, 1, 6); p(x-2, y-5, 1, 6); p(x, y-5, 1, 6); }
    else { p(x-4, y-2, 1, 3); p(x-2, y, 3, 1); } 

    p(x + 3, y - 8, 2, 2); 
    p(x + 3, y - 5, 2, 6); 
    p(x + 2, y + 1, 1, 4); 
    p(x + 5, y + 1, 1, 4); 
    
    if (swing) { p(x - 8, y - 2, 10, 1); } 
    else { p(x, y - 2, 2, 8); } 
  }
}
