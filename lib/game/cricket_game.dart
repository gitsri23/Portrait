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
// Ball Types & Game States
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
// Core Game Logic
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

  // --- ప్రొఫెషనల్ షాట్ మీటర్ (Shot Meter) ---
  double timingProgress = 0.5; // డిఫాల్ట్ గా మధ్యలో
  String timingLabel = '';
  double timingTimer = 0.0;
  bool showMeter = false;

  // ఫీల్డింగ్ లాజిక్
  Vector2 fieldBallPos = Vector2.zero();
  Vector2 fieldBallVel = Vector2.zero();
  List<Vector2> fielders = [];
  bool fielderHasBall = false;
  bool ballThrownToCenter = false;
  double throwDelay = 0.0;
  
  bool isAerial = false; 
  double aerialLandingDistance = 0.0; 
  double hitStartDistance = 0.0;

  // రన్నింగ్ లాజిక్
  int currentRuns = 0;
  double runProgress = 0.0; 
  bool isBatsmanRunning = false;
  double runDirection = 1.0; 

  @override
  Future<void> onLoad() async {
    camera.viewport = FixedAspectRatioViewport(aspectRatio: 120 / 160);

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
    showMeter = true; // బంతి వేయగానే మీటర్ కనిపిస్తుంది
    timingLabel = '';
    Sfx.bowl();
  }

  void releaseBall() {
    BallType bt = pickBType();
    ball.x = 60 + (rng.nextDouble() * 6 - 3);
    ball.y = 35; 
    ball.z = 8.0; 
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

    // మీటర్ ఎక్కడ ఫ్రీజ్ అవ్వాలో కాలిక్యులేట్ చేయడం
    timingProgress = ((by - 90) / 60).clamp(0.0, 1.0);
    timingTimer = 1.0; // 1 సెకను మీటర్ హోల్డ్ అవుతుంది

    if (distanceToStumps <= 5) { 
      timingLabel = 'PERFECT!';
      ball.isActive = false; balls++; score += 6; scoreNotifier.value = score;
      sixes++; combo++; if (combo > maxCombo) maxCombo = combo;
      rMsg = 'SIX!'; 
      Sfx.hit(); Sfx.six(); Sfx.cheer(); 
      HapticFeedback.heavyImpact(); 
      endBall(2.0);
    } 
    else if (distanceToStumps <= 12) { 
      timingLabel = by < 120 ? 'EARLY' : 'LATE'; 
      if (distanceToStumps <= 8) timingLabel = 'GOOD!';
      
      ball.isActive = false; balls++; score += 4; scoreNotifier.value = score;
      fours++; combo++; if (combo > maxCombo) maxCombo = combo;
      rMsg = 'FOUR!'; 
      Sfx.hit(); Sfx.four(); Sfx.cheer(); 
      HapticFeedback.mediumImpact(); 
      endBall(2.0);
    } 
    else if (distanceToStumps <= 25) { 
      timingLabel = by < 120 ? 'EARLY' : 'LATE';
      
      ball.isActive = false; balls++;
      combo++; if (combo > maxCombo) maxCombo = combo;
      Sfx.hit(); HapticFeedback.lightImpact();
      setupFielding(1.0 - (distanceToStumps / 25));
    } 
    else { 
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

    fieldBallPos = Vector2(60, 110); 
    
    double angle = (rng.nextDouble() * pi * 1.5) - (pi * 0.75); 
    double speed = 30.0 + (power * 70.0); 
    fieldBallVel = Vector2(sin(angle) * speed, -cos(angle) * speed);

    isAerial = power > 0.6 && rng.nextBool(); 
    aerialLandingDistance = isAerial ? (25.0 + power * 45.0) : 0.0; 
    hitStartDistance = 0.0;

    fielders = getFieldSetting();
  }

  void endBall(double delay) {
    state = GameState.RESULT; rTimer = delay; bowler.phase = 'idle'; bowler.frame = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameOverNotifier.value) return;

    if (timingTimer > 0) timingTimer -= dt;
    else showMeter = false; // టైమర్ అయిపోగానే మీటర్ మాయం అవుతుంది
    
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
        // మీటర్ కి బాల్ స్పీడ్ సింక్
        if(showMeter && timingLabel.isEmpty) {
           timingProgress = ((ball.y - 90) / 60).clamp(0.0, 1.0);
        }

        if (!ball.bounced) {
          double progress = (ball.y - 35) / (ball.bounceAt - 35);
          ball.z = 8.0 - (progress * 8.0); 
          if (ball.y >= ball.bounceAt) {
            ball.vy = ball.vy * 0.7 + 20; ball.bounced = true; ball.z = 0; Sfx.bounce();
          }
        } else {
          double progress = (ball.y - ball.bounceAt) / (120 - ball.bounceAt);
          ball.z = sin(progress * pi) * 6.0; 
        }
        
        ball.y += ball.vy * dt;

        if (ball.y >= 120 && ball.y <= 126 && (ball.x - 60).abs() < 5) {
          ball.isActive = false; wickets++; balls++; combo = 0; 
          timingLabel = 'MISSED!'; timingTimer = 1.0;
          wicketNotifier.value = wickets; batsman.stumpBroken = true;
          rMsg = 'Bowled!'; Sfx.outWicket(); 
          HapticFeedback.heavyImpact(); endBall(2.0);
        } else if (ball.y > 140) {
          ball.isActive = false; balls++; combo = 0; 
          timingLabel = 'TOO LATE'; timingTimer = 1.0;
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
        hitStartDistance += (fieldBallVel * dt).length;
        
        if (isAerial) {
          double p = hitStartDistance / aerialLandingDistance;
          ball.z = sin(p * pi) * 15.0; 
          if (p >= 1.0) {
            isAerial = false; ball.z = 0; Sfx.bounce();
          }
        }

        if (fieldBallPos.distanceTo(center) >= 48) {
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
        ball.z = 3.0; 
        throwDelay -= dt;
        if (throwDelay <= 0) { fielderHasBall = false; ballThrownToCenter = true; }
      } 
      else if (ballThrownToCenter) {
        fieldBallPos += (center - fieldBallPos).normalized() * 80 * dt;
        ball.z = 4.0; 
        
        if (fieldBallPos.distanceTo(center) < 3) {
          ball.z = 0;
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
    // 1. మొదట బ్యాక్‌గ్రౌండ్ & పిచ్ గీయాలి (కింద ఉండే లేయర్)
    final grassColor = const Color(0xFF4CAF50);
    final pitchColor = const Color(0xFFD7CCC8);
    final linePaint = Paint()..color = Colors.white70..strokeWidth = 1.0..isAntiAlias = true;
    final shadowPaint = Paint()..color = Colors.black26..isAntiAlias = true;

    canvas.drawRect(const Rect.fromLTWH(0, 0, 120, 160), Paint()..color = grassColor);

    if (state == GameState.BOWLING || state == GameState.RESULT) {
      Path pitchPath = Path()..moveTo(45, 30)..lineTo(75, 30)..lineTo(100, 130)..lineTo(20, 130)..close();
      canvas.drawPath(pitchPath, Paint()..color = pitchColor..isAntiAlias = true);

      canvas.drawLine(const Offset(47, 35), const Offset(73, 35), linePaint);
      canvas.drawLine(const Offset(25, 120), const Offset(95, 120), linePaint);
      canvas.drawLine(const Offset(20, 126), const Offset(100, 126), linePaint);

      final textP = TextPaint(style: const TextStyle(fontFamily: 'Arial', color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold));
      if (bLabelTimer > 0) textP.render(canvas, bLabelText, Vector2(60, 50), anchor: Anchor.center);

    } else if (state == GameState.FIELDING) {
      canvas.drawCircle(const Offset(60, 60), 48, Paint()..color = Colors.white30..style = PaintingStyle.stroke..strokeWidth = 1..isAntiAlias = true);
      canvas.drawCircle(const Offset(60, 60), 25, Paint()..color = Colors.white30..style = PaintingStyle.stroke..strokeWidth = 1..isAntiAlias = true);
      
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(56, 52, 8, 16), const Radius.circular(2)), Paint()..color = pitchColor);

      for (var f in fielders) {
        canvas.drawOval(Rect.fromCenter(center: Offset(f.x, f.y+1), width: 3, height: 1.5), shadowPaint);
        canvas.drawCircle(Offset(f.x, f.y), 1.5, Paint()..color = Colors.blue..isAntiAlias = true);
      }

      canvas.drawOval(Rect.fromCenter(center: Offset(fieldBallPos.x, fieldBallPos.y), width: 3, height: 1.5), shadowPaint);
      canvas.drawCircle(Offset(fieldBallPos.x, fieldBallPos.y - ball.z), 1.5, Paint()..color = Colors.redAccent..isAntiAlias=true);

      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(105, 40, 8, 40), const Radius.circular(4)), Paint()..color = Colors.black45);
      double runnerY = 77 - (runProgress * 34);
      canvas.drawCircle(Offset(109, runnerY+1), 2.5, Paint()..color = Colors.yellowAccent..isAntiAlias=true);
    }

    // 2. పిచ్ గీసిన తర్వాత, ప్లేయర్స్ ని గీయాలి (పైన ఉండే లేయర్ - Z Index Fix)
    super.render(canvas);

    // 3. చివరగా UI ఓవర్లేస్ (షాట్ మీటర్, రిజల్ట్స్) గీయాలి
    if (showMeter) {
      double mx = 4; double my = 40; double mw = 6; double mh = 60;
      
      // మీటర్ సెగ్మెంట్స్: Red->Orange->Green->Cyan->Green->Orange->Red
      List<Color> mColors = [Colors.red, Colors.orange, Colors.green, Colors.cyan, Colors.green, Colors.orange, Colors.red];
      List<double> mStops = [0.0, 0.2, 0.4, 0.45, 0.55, 0.6, 0.8, 1.0];
      
      for (int i = 0; i < mColors.length; i++) {
        double startY = my + mStops[i] * mh;
        double segmentH = (mStops[i+1] - mStops[i]) * mh;
        canvas.drawRect(Rect.fromLTWH(mx, startY, mw, segmentH), Paint()..color = mColors[i]);
      }
      
      canvas.drawRect(Rect.fromLTWH(mx, my, mw, mh), Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth=1);
      
      double indY = my + (timingProgress * mh);
      canvas.drawLine(Offset(mx - 3, indY), Offset(mx + mw + 3, indY), Paint()..color = Colors.white..strokeWidth=2);
      
      if (timingLabel.isNotEmpty) {
        final tp = TextPaint(style: const TextStyle(fontFamily: 'Arial', color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 2)]));
        // మీటర్ కింద పక్కగా టెక్స్ట్ పెడుతున్నాం, దేనికీ అడ్డు రాకుండా
        tp.render(canvas, timingLabel, Vector2(mx + 12, indY - 4));
      }
    }

    // క్లీన్ రిజల్ట్ పాప్-అప్
    if (state == GameState.RESULT && rMsg.isNotEmpty) {
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(25, 60, 70, 20), const Radius.circular(4)), Paint()..color = Colors.black87);
      final rPaint = TextPaint(style: const TextStyle(fontFamily: 'Arial', color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.bold));
      rPaint.render(canvas, rMsg, Vector2(60, 70), anchor: Anchor.center);
    }
  }
}

// ---------------------------------------------------------
// 2.5D Visual Models (Humanoids with Shadows)
// ---------------------------------------------------------

class Ball extends Component with HasGameRef<CricketGame> {
  double x = 60, y = 35, z = 0, vy = 0, bounceAt = 0;
  bool isActive = false, bounced = false;
  
  @override void render(Canvas canvas) {
    if (!isActive || gameRef.state != GameState.BOWLING) return;
    
    // షాడో
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 4, height: 2), Paint()..color = Colors.black38..isAntiAlias=true);
    // బంతి
    canvas.drawCircle(Offset(x, y - z), 2.0, Paint()..color = Colors.redAccent..isAntiAlias=true);
    canvas.drawCircle(Offset(x - 0.5, y - z - 0.5), 0.6, Paint()..color = Colors.white70..isAntiAlias=true);
  }
}

class Bowler extends Component with HasGameRef<CricketGame> {
  double x = 60, y = 25; 
  String phase = 'idle'; int frame = 0;
  
  @override void render(Canvas canvas) {
    if (gameRef.state != GameState.BOWLING) return;
    
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y + 2), width: 6, height: 3), Paint()..color = Colors.black26..isAntiAlias=true);

    final pJersey = Paint()..color = Colors.blue..strokeWidth = 2.0..strokeCap = StrokeCap.round..isAntiAlias=true;
    final pSkin = Paint()..color = const Color(0xFFFFCC80)..strokeWidth = 1.0..isAntiAlias=true;
    final pPants = Paint()..color = Colors.white..strokeWidth = 1.5..strokeCap = StrokeCap.round..isAntiAlias=true;

    canvas.drawCircle(Offset(x, y - 5), 1.5, pSkin); // తల
    canvas.drawLine(Offset(x, y - 3), Offset(x, y), pJersey); // బాడీ

    if (phase == 'idle') { 
      canvas.drawLine(Offset(x, y), Offset(x - 1, y + 2), pPants); 
      canvas.drawLine(Offset(x, y), Offset(x + 1, y + 2), pPants);
    } else if (phase == 'runup') { 
      int f = (frame / 3).floor() % 2; 
      if (f == 0) {
        canvas.drawLine(Offset(x, y), Offset(x - 2, y + 2), pPants); 
        canvas.drawLine(Offset(x, y), Offset(x + 1, y + 1), pPants); 
      } else {
        canvas.drawLine(Offset(x, y), Offset(x - 1, y + 1), pPants); 
        canvas.drawLine(Offset(x, y), Offset(x + 2, y + 2), pPants); 
      }
    } else if (phase == 'deliver') { 
      canvas.drawLine(Offset(x + 1, y - 2), Offset(x + 3, y - 4), pSkin); // చెయ్యి ఎత్తడం
      canvas.drawLine(Offset(x, y), Offset(x - 1, y + 2), pPants); 
    }
  }
}

class Batsman extends Component with HasGameRef<CricketGame> {
  double x = 60, y = 115, swingTimer = 0; 
  bool swing = false, stumpBroken = false;
  
  @override void render(Canvas canvas) {
    if (gameRef.state != GameState.BOWLING) return;
    
    // బ్యాట్స్‌మాన్ షాడో
    canvas.drawOval(Rect.fromCenter(center: Offset(x + 3, y + 4), width: 10, height: 4), Paint()..color = Colors.black26..isAntiAlias=true);

    final pJersey = Paint()..color = Colors.blue..strokeWidth = 3.0..strokeCap = StrokeCap.round..isAntiAlias=true;
    final pPants = Paint()..color = Colors.white..strokeWidth = 2.5..strokeCap = StrokeCap.round..isAntiAlias=true;
    final pHat = Paint()..color = const Color(0xFF111111)..isAntiAlias=true;
    final pBat = Paint()..color = const Color(0xFF8D6E63)..strokeWidth = 2.0..strokeCap = StrokeCap.round..isAntiAlias=true;
    final pStump = Paint()..color = const Color(0xFFFFF176)..strokeWidth = 1.0..isAntiAlias=true;

    // స్టంప్స్
    if (!stumpBroken) { 
      canvas.drawRect(Rect.fromLTWH(x - 4, y - 5, 1, 6), pStump);
      canvas.drawRect(Rect.fromLTWH(x - 2, y - 5, 1, 6), pStump);
      canvas.drawRect(Rect.fromLTWH(x, y - 5, 1, 6), pStump);
    } else { 
      canvas.drawRect(Rect.fromLTWH(x - 4, y - 2, 1, 3), pStump);
      canvas.drawRect(Rect.fromLTWH(x - 2, y, 3, 1), pStump);
    }

    // బ్యాట్స్‌మాన్ బాడీ
    canvas.drawCircle(Offset(x + 4, y - 7), 2.0, pHat); 
    canvas.drawLine(Offset(x + 4, y - 4), Offset(x + 4, y), pJersey); 
    canvas.drawLine(Offset(x + 4, y), Offset(x + 3, y + 3), pPants); 
    canvas.drawLine(Offset(x + 4, y), Offset(x + 6, y + 3), pPants); 
    
    // బ్యాట్ ఊపడం
    if (swing) { 
      canvas.drawLine(Offset(x + 4, y - 1), Offset(x - 6, y - 1), pBat); 
    } else { 
      canvas.drawLine(Offset(x + 5, y - 1), Offset(x + 1, y + 4), pBat); 
    }
  }
}
