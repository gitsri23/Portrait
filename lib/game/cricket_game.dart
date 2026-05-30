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
// 8-Bit సౌండ్ ఇంజిన్ (Glitch లేని క్లీన్ సౌండ్స్)
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
  
  // గ్లిచ్ లేకుండా క్లీన్ గా ఉండే ఆర్కేడ్ చీరప్ (Cheer) సౌండ్
  static void cheer() {
    final freqs = [440.0, 554.0, 659.0, 880.0, 1108.0, 1318.0];
    for (int i = 0; i < freqs.length; i++) {
      Future.delayed(Duration(milliseconds: i * 60), () => tone(freqs[i], 0.1, 'square', 0.15));
    }
  }
}

// ---------------------------------------------------------
// గేమ్ స్టేట్స్ & కోర్ క్రికెట్ లాజిక్
// ---------------------------------------------------------
enum GameState { BOWLING, FIELDING, RESULT }

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

  // రియల్ ఫీల్డింగ్ & క్యాచ్ లాజిక్ కోసం
  Vector2 fieldBallPos = Vector2.zero();
  Vector2 fieldBallVel = Vector2.zero();
  List<Vector2> fielders = [];
  bool fielderHasBall = false;
  bool ballThrownToCenter = false;
  double throwDelay = 0.0;
  
  bool isAerial = false; // గాల్లో కొట్టాడా లేదా?
  double aerialLandingDistance = 0.0; // బంతి ఎక్కడ పడుతుంది?

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

  void startBowl() {
    if (ball.isActive || bowler.phase != 'idle') return;
    bowler.phase = 'runup'; bowler.frame = 0;
    Sfx.bowl();
  }

  void releaseBall() {
    ball.x = 60 + (rng.nextDouble() * 6 - 3);
    ball.y = 35; 
    ball.vy = 40.0 + rng.nextDouble() * 30.0; 
    ball.isActive = true; ball.bounced = false;
    ball.bounceAt = 70 + rng.nextDouble() * 30;
    bowler.phase = 'deliver'; bowler.frame = 0;
  }

  // 3 రకాల క్రికెట్ ఫీల్డింగ్ సెటప్స్ (9 మంది ఫీల్డర్స్)
  List<Vector2> getFieldSetting() {
    int type = rng.nextInt(3);
    if(type == 0) { // Defensive (బౌండరీ దగ్గర ఎక్కువ మంది)
       return [Vector2(60, 15), Vector2(30, 25), Vector2(90, 25), Vector2(15, 60), Vector2(105, 60), Vector2(30, 95), Vector2(90, 95), Vector2(45, 45), Vector2(75, 45)];
    } else if(type == 1) { // Attacking (సర్కిల్ లోపల)
       return [Vector2(50, 45), Vector2(70, 45), Vector2(40, 60), Vector2(80, 60), Vector2(45, 75), Vector2(75, 75), Vector2(60, 20), Vector2(20, 30), Vector2(100, 30)];
    } else { // Normal (బ్యాలెన్స్డ్)
       return [Vector2(60, 25), Vector2(35, 35), Vector2(85, 35), Vector2(25, 60), Vector2(95, 60), Vector2(40, 85), Vector2(80, 85), Vector2(20, 20), Vector2(100, 20)];
    }
  }

  void checkHit() {
    if (state != GameState.BOWLING || !ball.isActive || batsman.swing) return;
    batsman.swing = true; batsman.swingTimer = 0.20;

    double distanceToStumps = (120 - ball.y).abs();

    if (distanceToStumps <= 18) { // హిట్ అయింది
      ball.isActive = false; balls++;
      Sfx.hit(); HapticFeedback.mediumImpact();
      
      // ఎంత పర్ఫెక్ట్‌గా టైమింగ్ చేసాడనే దాన్ని బట్టి పవర్ వస్తుంది
      double power = 1.0 - (distanceToStumps / 18); // 0.0 to 1.0
      setupFielding(power);
    } else { // మిస్ అయింది
      if (ball.y < 120) {
        ball.isActive = false; balls++; combo = 0; 
        rMsg = 'Missed'; Sfx.miss(); endBall(1.0);
      }
    }
  }

  void setupFielding(double power) {
    state = GameState.FIELDING;
    currentRuns = 0; runProgress = 0.0; isBatsmanRunning = false; runDirection = 1.0;
    fielderHasBall = false; ballThrownToCenter = false;

    fieldBallPos = Vector2(60, 60); // పిచ్ సెంటర్ నుండి స్టార్ట్
    
    // బంతి వెళ్లే డైరెక్షన్ మరియు వేగం
    double angle = (rng.nextDouble() * pi * 1.5) - (pi * 0.75); 
    double speed = 30.0 + (power * 70.0); 
    fieldBallVel = Vector2(sin(angle) * speed, -cos(angle) * speed);

    // పవర్ > 0.6 ఉంటే గాల్లోకి వెళ్లే (Aerial/Catch) అవకాశం ఉంది
    isAerial = power > 0.6 && rng.nextBool(); 
    if (power > 0.92) isAerial = true; // పర్ఫెక్ట్ టైమింగ్ పక్కా సిక్స్ (గాల్లోకి)
    
    // బంతి గాల్లో ఉంటే ఎక్కడ బౌన్స్ అవుతుందో క్యాలిక్యులేట్ చేయడం
    aerialLandingDistance = isAerial ? (25.0 + power * 45.0) : 0.0; 

    // ఫీల్డర్లను ప్లేస్ చేయడం
    fielders = getFieldSetting();
  }

  void endBall(double delay) {
    state = GameState.RESULT; rTimer = delay; bowler.phase = 'idle'; bowler.frame = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameOverNotifier.value) return;

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
    // ---------------------------------------
    // రియల్ ఫీల్డింగ్ & క్యాచ్ ఔట్ లాజిక్
    // ---------------------------------------
    else if (state == GameState.FIELDING) {
      Vector2 center = Vector2(60, 60);

      if (!fielderHasBall && !ballThrownToCenter) {
        fieldBallPos += fieldBallVel * dt;
        double distTraveled = fieldBallPos.distanceTo(center);

        // 1. బంతి బౌన్స్ అవ్వడం (గాల్లోంచి కిందపడటం)
        if (isAerial && distTraveled >= aerialLandingDistance) {
          isAerial = false; // ఇక క్యాచ్ ఔట్ అవ్వదు
          Sfx.bounce();
        }

        // 2. బౌండరీ లైన్ చెక్
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

        // 3. ఫీల్డర్స్ క్యాచ్ పట్టడం / బంతి ఆపడం
        for (var f in fielders) {
          if (f.distanceTo(fieldBallPos) < 4) {
            if (isAerial) {
              // గాల్లో ఉన్నప్పుడు పట్టుకున్నాడు -> CATCH OUT!
              wickets++; wicketNotifier.value = wickets; combo = 0;
              rMsg = 'Catch Out!'; Sfx.outWicket(); HapticFeedback.heavyImpact();
              endBall(2.0); return;
            } else {
              // కింద పడ్డాక పట్టుకున్నాడు -> బంతి ఆగాక విసురుతాడు
              fielderHasBall = true; throwDelay = 0.4; 
              fieldBallVel = Vector2.zero();
              break;
            }
          } else {
            // ఫీల్డర్స్ బంతి వైపు పరిగెత్తడం
            f += (fieldBallPos - f).normalized() * 40 * dt; 
          }
        }
      } 
      else if (fielderHasBall) {
        throwDelay -= dt;
        if (throwDelay <= 0) { fielderHasBall = false; ballThrownToCenter = true; }
      } 
      // కీపర్‌కి విసరడం
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

      // మ్యాన్యువల్ రన్నింగ్
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
      // Perspective Pitch
      canvas.drawLine(const Offset(45, 30), const Offset(20, 130), pDarkStroke);
      canvas.drawLine(const Offset(75, 30), const Offset(100, 130), pDarkStroke);
      canvas.drawLine(const Offset(47, 35), const Offset(73, 35), pDarkStroke);
      canvas.drawLine(const Offset(25, 120), const Offset(95, 120), pDarkStroke);
      
      Path pitchPath = Path()..moveTo(45, 30)..lineTo(75, 30)..lineTo(100, 130)..lineTo(20, 130)..close();
      canvas.drawPath(pitchPath, Paint()..color = const Color(0x110F380F));

    } else if (state == GameState.FIELDING) {
      // Top-Down Radar View
      canvas.drawCircle(const Offset(60, 60), 48, Paint()..color = const Color(0xFF306230)..style = PaintingStyle.stroke..strokeWidth = 1);
      canvas.drawCircle(const Offset(60, 60), 25, Paint()..color = const Color(0xFF306230)..style = PaintingStyle.stroke..strokeWidth = 1);
      canvas.drawRect(const Rect.fromLTWH(56, 52, 8, 16), pLight);
      
      // ఫీల్డర్స్ & బాల్ 
      for (var f in fielders) {
        canvas.drawRect(Rect.fromCenter(center: Offset(f.x, f.y), width: 3, height: 3), pDark);
      }
      // గుండ్రటి బంతి (Round ball)
      canvas.drawCircle(Offset(fieldBallPos.x, fieldBallPos.y), 1.5, pDark);

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
// నోకియా స్టిక్ ఫిగర్స్ (క్లియర్ గా తెలిసేలా డిజైన్)
// ---------------------------------------------------------

class Ball extends Component with HasGameRef<CricketGame> {
  double x = 60, y = 35, vy = 0, bounceAt = 0;
  bool isActive = false, bounced = false;
  
  @override void render(Canvas canvas) {
    if (!isActive || gameRef.state != GameState.BOWLING) return;
    // Round Ball
    canvas.drawCircle(Offset(x, y), 1.5, Paint()..color = const Color(0xFF0F380F));
  }
}

class Bowler extends Component with HasGameRef<CricketGame> {
  double x = 60, y = 25; 
  String phase = 'idle'; int frame = 0;
  
  @override void render(Canvas canvas) {
    if (gameRef.state != GameState.BOWLING) return;
    final pLine = Paint()..color = const Color(0xFF0F380F)..strokeWidth = 1.5;
    
    // తల
    canvas.drawRect(Rect.fromLTWH(x - 1, y - 5, 2, 2), Paint()..color = const Color(0xFF0F380F));
    // బాడీ (గీత)
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
      canvas.drawLine(Offset(x, y - 2), Offset(x + 2, y - 3), pLine); // చెయ్యి
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

    // స్టంప్స్
    if (!stumpBroken) { 
      canvas.drawRect(Rect.fromLTWH(x - 4, y - 5, 1, 6), pDark);
      canvas.drawRect(Rect.fromLTWH(x - 2, y - 5, 1, 6), pDark);
      canvas.drawRect(Rect.fromLTWH(x, y - 5, 1, 6), pDark);
    } else { 
      canvas.drawRect(Rect.fromLTWH(x - 4, y - 2, 1, 3), pDark);
      canvas.drawRect(Rect.fromLTWH(x - 2, y, 3, 1), pDark);
    }

    // బ్యాట్స్‌మాన్ స్టిక్ ఫిగర్ (క్లియర్)
    canvas.drawRect(Rect.fromLTWH(x + 3, y - 8, 2, 2), pDark); // తల
    canvas.drawLine(Offset(x + 4, y - 6), Offset(x + 4, y - 1), pLine); // బాడీ
    canvas.drawLine(Offset(x + 4, y - 1), Offset(x + 3, y + 3), pLine); // ఎడమ కాలు
    canvas.drawLine(Offset(x + 4, y - 1), Offset(x + 5, y + 3), pLine); // కుడి కాలు
    
    // బ్యాట్
    if (swing) { 
      canvas.drawLine(Offset(x + 4, y - 3), Offset(x - 5, y - 2), pLine); 
    } else { 
      canvas.drawLine(Offset(x + 4, y - 3), Offset(x, y + 3), pLine); 
    }
  }
}
