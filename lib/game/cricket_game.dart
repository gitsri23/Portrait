import 'dart:math';
import 'dart:typed_data';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/camera.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

// --- Sound System (Same as before) ---
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
  static void two() { tone(550, 0.08); Future.delayed(const Duration(milliseconds: 70), () => tone(660, 0.08)); }
  static void three() { final freqs = [550.0, 660.0, 770.0]; for (int i = 0; i < freqs.length; i++) { Future.delayed(Duration(milliseconds: i * 55), () => tone(freqs[i], 0.08)); } }
  static void four() { final freqs = [440.0, 554.0, 659.0]; for (int i = 0; i < freqs.length; i++) { Future.delayed(Duration(milliseconds: i * 65), () => tone(freqs[i], 0.12)); } }
  static void six() { final freqs = [523.0, 659.0, 784.0, 1047.0]; for (int i = 0; i < freqs.length; i++) { Future.delayed(Duration(milliseconds: i * 75), () => tone(freqs[i], 0.15)); } }
  static void outWicket() { final freqs = [300.0, 220.0, 160.0]; for (int i = 0; i < freqs.length; i++) { Future.delayed(Duration(milliseconds: i * 90), () => tone(freqs[i], 0.2, 'sawtooth')); } }
  static void miss() => tone(180, 0.18, 'sawtooth', 0.18);
  static void over() { final freqs = [330.0, 280.0, 220.0]; for (int i = 0; i < freqs.length; i++) { Future.delayed(Duration(milliseconds: i * 120), () => tone(freqs[i], 0.3, 'square', 0.15)); } }
}

// --- Ball Types ---
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

// 3 Phases of the game just like the video
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
  String bLabelText = '';
  double bLabelTimer = 0;

  // --- Fielding View Variables ---
  Vector2 fieldBallPos = Vector2.zero();
  Vector2 fieldBallVel = Vector2.zero();
  List<Vector2> fielders = [];

  @override
  Future<void> onLoad() async {
    camera.viewport = FixedAspectRatioViewport(aspectRatio: 120 / 160);

    // Green Background
    add(RectangleComponent(size: Vector2(120, 160), paint: Paint()..color = const Color(0xFF8BAC0F)));

    bowler = Bowler(); 
    batsman = Batsman(); 
    ball = Ball();

    add(bowler); 
    add(batsman); 
    add(ball);
    
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
    // Video lanti perspective kosam ball x position center(60) nundi start avvali
    ball.x = 60 + (rng.nextDouble() * 6 - 3);
    ball.y = 35; // Top crease
    ball.vy = (40.0 + rng.nextDouble() * 30.0) * bt.sm; 
    ball.isActive = true; ball.bounced = false;
    ball.bounceAt = bt.br[0] + rng.nextDouble() * (bt.br[1] - bt.br[0]);
    
    if (bt.label.isNotEmpty) { bLabelText = bt.label; bLabelTimer = 0.8; }
    bowler.phase = 'deliver'; bowler.frame = 0;
  }

  void checkHit() {
    if (state != GameState.BOWLING || !ball.isActive || batsman.swing) return;
    batsman.swing = true; batsman.swingTimer = 0.30;

    double by = ball.y;
    
    // Timing check
    if (by >= 100 && by <= 130) {
      ball.isActive = false;
      Sfx.hit();
      
      // Calculate runs based on timing
      int runs;
      if (by >= 112 && by <= 118) runs = rng.nextBool() ? 6 : 4; // Perfect timing
      else runs = rng.nextInt(3) + 1; // 1, 2, or 3 runs

      combo++;
      if (combo > maxCombo) maxCombo = combo; 
      
      score += runs; balls++; scoreNotifier.value = score;

      if (runs == 6) { sixes++; rMsg = 'Six!'; Sfx.six(); } 
      else if (runs == 4) { fours++; rMsg = 'Four!'; Sfx.four(); } 
      else { rMsg = '$runs Run${runs > 1 ? 's' : ''}'; runs == 3 ? Sfx.three() : (runs == 2 ? Sfx.two() : Sfx.one()); }

      // --- SWITCH TO FIELDING VIEW ---
      state = GameState.FIELDING;
      
      // Setup ball for fielding view
      fieldBallPos = Vector2(60, 100); // Batting position on radar
      double angle = (rng.nextDouble() * pi) - (pi / 2); // Random shot angle (top half)
      double speed = runs >= 4 ? 60.0 : 30.0;
      fieldBallVel = Vector2(sin(angle) * speed, -cos(angle) * speed);

      // Setup random fielders
      fielders.clear();
      for (int i = 0; i < 5; i++) {
        fielders.add(Vector2(20 + rng.nextDouble() * 80, 20 + rng.nextDouble() * 60));
      }

      rTimer = 2.5; // Stay on fielding screen for 2.5 secs
    } else if (by > 130) {
      ball.isActive = false; combo = 0; balls++;
      rMsg = 'Missed'; Sfx.miss(); 
      endBall(1.0);
    }
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
          ball.vy = ball.vy * 0.7 + 15; ball.bounced = true;
          Sfx.bounce();
        }
        
        // Video laaga perspective scale (Ball kinda ki vachkoddi peddaga avvali)
        ball.scale = 1.0 + ((ball.y - 20) / 100) * 0.5;
        
        ball.y += ball.vy * dt;

        // Wicket hit logic
        if (ball.y >= 120 && ball.y <= 126 && (ball.x - 60).abs() < 6) {
          ball.isActive = false; wickets++; balls++; combo = 0;
          wicketNotifier.value = wickets; batsman.stumpBroken = true;
          rMsg = 'Out!'; Sfx.outWicket(); endBall(2.0);
        } else if (ball.y > 140) {
          ball.isActive = false; combo = 0; balls++; rMsg = 'Dot'; endBall(1.0);
        }
      }

      if (batsman.swing) {
        batsman.swingTimer -= dt; if (batsman.swingTimer <= 0) batsman.swing = false;
      }
    } 
    // FIELDING RADAR LOGIC
    else if (state == GameState.FIELDING) {
      fieldBallPos += fieldBallVel * dt;
      
      // Fielder movement towards ball
      for (var f in fielders) {
        if (f.distanceTo(fieldBallPos) > 10 && rMsg != 'Six!' && rMsg != 'Four!') {
          Vector2 dir = (fieldBallPos - f)..normalize();
          f += dir * 20 * dt;
        }
      }

      rTimer -= dt;
      if (rTimer <= 0) {
         endBall(0.5); // transition to result
      }
    }
    // RESULT LOGIC
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
  void onTap() { if (!gameOverNotifier.value) checkHit(); }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final pDark = Paint()..color = const Color(0xFF0F380F);
    final pLight = Paint()..color = const Color(0xFF306230);

    if (state == GameState.BOWLING || state == GameState.RESULT) {
      // 1. VIDEO LANTI PERSPECTIVE PITCH DRAWING
      // Outer pitch lines
      canvas.drawLine(const Offset(45, 30), const Offset(20, 130), pDark..strokeWidth=1);
      canvas.drawLine(const Offset(75, 30), const Offset(100, 130), pDark..strokeWidth=1);
      // Top Crease
      canvas.drawLine(const Offset(47, 35), const Offset(73, 35), pDark);
      // Bottom Crease
      canvas.drawLine(const Offset(25, 120), const Offset(95, 120), pDark);
      
      // Inner pitch shade
      Path pitchPath = Path()
        ..moveTo(45, 30)..lineTo(75, 30)..lineTo(100, 130)..lineTo(20, 130)..close();
      canvas.drawPath(pitchPath, Paint()..color = const Color(0x110F380F));

      // Labels
      final textP = TextPaint(style: const TextStyle(fontFamily: 'NokiaPixel', color: Color(0xFF0F380F), fontSize: 6, fontWeight: FontWeight.bold));
      if (bLabelTimer > 0) textP.render(canvas, bLabelText, Vector2(60, 50), anchor: Anchor.center);

    } else if (state == GameState.FIELDING) {
      // 2. VIDEO LANTI TOP-DOWN FIELDING VIEW
      // Boundary circle
      canvas.drawCircle(const Offset(60, 60), 50, Paint()..color = const Color(0xFF306230)..style = PaintingStyle.stroke..strokeWidth = 1);
      // Inner circle
      canvas.drawCircle(const Offset(60, 60), 30, Paint()..color = const Color(0xFF306230)..style = PaintingStyle.stroke..strokeWidth = 1);
      // Center Pitch
      canvas.drawRect(const Rect.fromLTWH(55, 50, 10, 20), pLight);
      
      // Draw Fielders (dots)
      for (var f in fielders) {
        canvas.drawRect(Rect.fromCenter(center: Offset(f.x, f.y), width: 3, height: 3), pDark);
      }
      
      // Draw Ball (dot)
      canvas.drawRect(Rect.fromCenter(center: Offset(fieldBallPos.x, fieldBallPos.y), width: 2, height: 2), pDark);

      // Side HUD (Just like video)
      canvas.drawRect(const Rect.fromLTWH(105, 40, 10, 30), Paint()..color=const Color(0xFF306230)..style=PaintingStyle.stroke);
      canvas.drawRect(const Rect.fromLTWH(107, 65, 6, 2), pDark); // pseudo player running
    }

    // RESULTS POPUP
    if (state == GameState.RESULT || (state == GameState.FIELDING && rTimer < 1.5)) {
      if (rMsg.isNotEmpty) {
        canvas.drawRect(const Rect.fromLTWH(30, 60, 60, 20), Paint()..color = const Color(0xFF8BAC0F));
        canvas.drawRect(const Rect.fromLTWH(30, 60, 60, 20), Paint()..color = const Color(0xFF0F380F)..style=PaintingStyle.stroke..strokeWidth=2);
        
        final rPaint = TextPaint(style: const TextStyle(fontFamily: 'NokiaPixel', color: Color(0xFF0F380F), fontSize: 10, fontWeight: FontWeight.bold));
        rPaint.render(canvas, rMsg, Vector2(60, 70), anchor: Anchor.center);
      }
    }
  }
}

// --- Ball Component ---
class Ball extends Component {
  double x = 60, y = 35, vy = 0, bounceAt = 0;
  double scale = 1.0;
  bool isActive = false, bounced = false;
  
  @override void render(Canvas canvas) {
    if (!isActive || (gameRef as CricketGame).state != GameState.BOWLING) return;
    double s = 2 * scale;
    canvas.drawRect(Rect.fromLTWH(x - s, y - s, s*2, s*2), Paint()..color = const Color(0xFF0F380F));
  }
}

// --- Bowler Component (Top of Perspective Pitch) ---
class Bowler extends Component {
  double x = 60, y = 25; 
  String phase = 'idle'; int frame = 0;
  
  @override void render(Canvas canvas) {
    if ((gameRef as CricketGame).state != GameState.BOWLING) return;
    final p0 = Paint()..color = const Color(0xFF0F380F);
    void p(double px, double py, double w, double h) => canvas.drawRect(Rect.fromLTWH(px, py, w, h), p0);

    // Bowler is smaller because of perspective
    if (phase == 'idle') { p(x - 1, y - 4, 2, 2); p(x - 1, y - 2, 3, 3); p(x - 1, y + 1, 1, 2); p(x + 1, y + 1, 1, 2); } 
    else if (phase == 'runup') { int f = (frame / 4).floor() % 2; p(x - 1, y - 4, 2, 2); p(x - 1, y - 2, 3, 3); if (f == 0) { p(x - 1, y + 1, 1, 3); p(x + 1, y + 1, 1, 1); } else { p(x - 1, y + 1, 1, 1); p(x + 1, y + 1, 1, 3); } } 
    else if (phase == 'deliver') { p(x - 1, y - 4, 2, 2); p(x - 1, y - 2, 3, 3); p(x + 2, y - 3, 1, 2); p(x - 1, y + 1, 1, 2); }
  }
}

// --- Batsman Component (Bottom of Perspective Pitch) ---
class Batsman extends Component {
  double x = 60, y = 115, swingTimer = 0; 
  bool swing = false, stumpBroken = false;
  
  @override void render(Canvas canvas) {
    if ((gameRef as CricketGame).state != GameState.BOWLING) return;
    final p0 = Paint()..color = const Color(0xFF0F380F); 
    void p(double px, double py, double w, double h) => canvas.drawRect(Rect.fromLTWH(px, py, w, h), p0);

    // Stumps
    if (!stumpBroken) { p(x-6, y-5, 1, 6); p(x-4, y-5, 1, 6); p(x-2, y-5, 1, 6); }
    else { p(x-6, y-2, 1, 3); p(x-3, y, 4, 1); } // Broken stumps

    // Batsman (Larger because of perspective)
    p(x + 2, y - 10, 5, 5); // Head/Helmet
    p(x + 1, y - 5, 7, 8); // Body
    p(x + 2, y + 3, 2, 5); // Left Leg
    p(x + 5, y + 3, 2, 5); // Right Leg
    
    // Bat
    if (swing) { p(x - 10, y - 2, 12, 3); } // Horizontal Swing
    else { p(x - 2, y - 2, 3, 10); } // Idle stance
  }
}
