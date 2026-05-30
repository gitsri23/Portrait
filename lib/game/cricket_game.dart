import 'dart:math';
import 'dart:typed_data';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/camera.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

// ---------------------------------------------------------
// WEB AUDIO API తరహా డైనమిక్ సౌండ్స్ (8-bit ఎఫెక్ట్స్)
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
        if (t == 'square') {
          val = sin(2 * pi * f * time) >= 0 ? 1.0 : -1.0;
        } else if (t == 'sawtooth') {
          val = 2.0 * (time * f - (time * f + 0.5).floor());
        } else {
          val = sin(2 * pi * f * time);
        }
        
        double env = exp(-5.0 * time / d); 
        val = val * env * v;
        
        int sample = (val * 32767).toInt().clamp(-32768, 32767);
        header.setInt16(44 + i * 2, sample, Endian.little);
      }

      _players[_pIdx].play(BytesSource(bytes));
      _pIdx = (_pIdx + 1) % _players.length;
    } catch (e) {
      // ఇగ్నోర్
    }
  }

  static void start() {
    tone(440, 0.08);
    Future.delayed(const Duration(milliseconds: 90), () => tone(660, 0.1));
  }
  static void bowl() => tone(200, 0.05, 'square', 0.12);
  static void bounce() => tone(155, 0.04, 'square', 0.09);
  static void hit() => tone(700, 0.06, 'square', 0.2);
  static void one() => tone(550, 0.08);
  static void two() {
    tone(550, 0.08);
    Future.delayed(const Duration(milliseconds: 70), () => tone(660, 0.08));
  }
  static void three() {
    final freqs = [550.0, 660.0, 770.0];
    for (int i = 0; i < freqs.length; i++) {
      Future.delayed(Duration(milliseconds: i * 55), () => tone(freqs[i], 0.08));
    }
  }
  static void four() {
    final freqs = [440.0, 554.0, 659.0];
    for (int i = 0; i < freqs.length; i++) {
      Future.delayed(Duration(milliseconds: i * 65), () => tone(freqs[i], 0.12));
    }
  }
  static void six() {
    final freqs = [523.0, 659.0, 784.0, 1047.0];
    for (int i = 0; i < freqs.length; i++) {
      Future.delayed(Duration(milliseconds: i * 75), () => tone(freqs[i], 0.15));
    }
  }
  static void outWicket() {
    final freqs = [300.0, 220.0, 160.0];
    for (int i = 0; i < freqs.length; i++) {
      Future.delayed(Duration(milliseconds: i * 90), () => tone(freqs[i], 0.2, 'sawtooth'));
    }
  }
  static void miss() => tone(180, 0.18, 'sawtooth', 0.18);
  static void over() {
    final freqs = [330.0, 280.0, 220.0];
    for (int i = 0; i < freqs.length; i++) {
      Future.delayed(Duration(milliseconds: i * 120), () => tone(freqs[i], 0.3, 'square', 0.15));
    }
  }
}
// ---------------------------------------------------------

class BallType {
  final String id, label;
  final List<double> br;
  final double sm, p;
  BallType(this.id, this.label, this.br, this.sm, this.p);
}

final List<BallType> BTYPES = [
  BallType('normal', '', [70, 84], 1.0, 0.50),
  BallType('short', 'SHORT!', [50, 66], 0.9, 0.20),
  BallType('full', 'FULL', [90, 106], 1.1, 0.20),
  BallType('yorker', 'YORKER!', [114, 124], 1.3, 0.10),
];

class ShotType {
  final String name;
  final List<double> yr;
  final List<int> runs;
  ShotType(this.name, this.yr, this.runs);
}

final Map<String, ShotType> SHOTS = {
  'hook': ShotType('HOOK!', [87, 100], [2, 6]),
  'pull': ShotType('PULL SHOT', [100, 111], [1, 4]),
  'cut': ShotType('CUT SHOT', [111, 118], [1, 4]),
  'cover': ShotType('COVER DRIVE', [118, 123], [2, 6]),
  'straight': ShotType('STRAIGHT!', [123, 127], [4, 6]),
  'flick': ShotType('FLICK', [127, 133], [1, 3]),
  'sweep': ShotType('SWEEP', [133, 139], [1, 2]),
};

enum GameState { PLAY, RESULT }

class CricketGame extends FlameGame with TapCallbacks {
  final Random rng = Random();

  int maxBalls = 12;
  int maxWickets = 3;

  int score = 0;
  int wickets = 0;
  int balls = 0;
  
  // STATS
  int combo = 0;
  int maxCombo = 0;
  int sixes = 0;
  int fours = 0;

  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> wicketNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> gameOverNotifier = ValueNotifier<bool>(false);

  GameState state = GameState.PLAY;
  
  late Bowler bowler;
  late Batsman batsman;
  late Ball ball;
  late Stumps batsmanStumps;

  String rMsg = '';
  String rShot = '';
  double rTimer = 0;
  double bowlT = 1.0;

  String bLabelText = '';
  double bLabelTimer = 0;

  @override
  Future<void> onLoad() async {
    camera.viewport = FixedAspectRatioViewport(aspectRatio: 120 / 160);

    add(RectangleComponent(size: Vector2(120, 160), paint: Paint()..color = const Color(0xFF8BAC0F)));

    for (int i = 0; i < 30; i++) {
      add(RectangleComponent(
        position: Vector2((i * 4 + (i % 3)).toDouble(), rng.nextDouble() * 3 + 3),
        size: Vector2(2, (rng.nextInt(3) + 3).toDouble()),
        paint: Paint()..color = const Color(0xFF306230),
      ));
    }

    add(RectangleComponent(position: Vector2(34, 14), size: Vector2(52, 122), paint: Paint()..color = const Color(0xFFC4E060)));

    final creaseP = Paint()..color = const Color(0xFF0F380F);
    add(RectangleComponent(position: Vector2(34, 18), size: Vector2(52, 1), paint: creaseP));
    add(RectangleComponent(position: Vector2(34, 28), size: Vector2(52, 1), paint: creaseP));
    add(RectangleComponent(position: Vector2(34, 118), size: Vector2(52, 1), paint: creaseP));

    bowler = Bowler(); batsman = Batsman(); ball = Ball(); batsmanStumps = Stumps();

    add(batsmanStumps); add(bowler); add(batsman); add(ball);
    
    // ఆడియో: స్టార్ట్
    Sfx.start();
  }

  BallType pickBType() {
    double r = rng.nextDouble(), c = 0;
    for (var bt in BTYPES) {
      c += bt.p;
      if (r < c) return bt;
    }
    return BTYPES[0];
  }

  void startBowl() {
    if (ball.isActive || bowler.phase != 'idle') return;
    bowler.phase = 'runup'; bowler.frame = 0;
    // ఆడియో: బౌలర్
    Sfx.bowl();
  }

  void releaseBall() {
    BallType bt = pickBType();
    ball.x = 60 + (rng.nextDouble() * 10 - 5);
    ball.y = 22;
    ball.vy = (60.0 + rng.nextDouble() * 40.0) * bt.sm; 
    ball.isActive = true; ball.bounced = false;
    ball.bounceAt = bt.br[0] + rng.nextDouble() * (bt.br[1] - bt.br[0]);
    
    if (bt.label.isNotEmpty) { bLabelText = bt.label; bLabelTimer = 0.8; }
    bowler.phase = 'deliver'; bowler.frame = 0;
  }

  ShotType? detectShot(double by) {
    for (var entry in SHOTS.entries) {
      if (by >= entry.value.yr[0] && by < entry.value.yr[1]) return entry.value;
    }
    return null;
  }

  void checkHit() {
    if (state != GameState.PLAY || !ball.isActive || batsman.swing) return;
    batsman.swing = true; batsman.swingTimer = 0.20;

    double by = ball.y;
    ShotType? sh = detectShot(by);

    if (sh != null) {
      ball.isActive = false;
      Sfx.hit(); // ఆడియో: హిట్

      int runs = sh.runs[0] + rng.nextInt(sh.runs[1] - sh.runs[0] + 1);

      combo++;
      if (combo > maxCombo) maxCombo = combo; 
      if (combo >= 3 && runs < 6) runs = min(runs + 1, 6);
      
      score += runs; balls++; scoreNotifier.value = score;

      if (runs == 6) { 
        sixes++; rMsg = 'SIX!'; 
        Sfx.six(); 
      } else if (runs == 4) { 
        fours++; rMsg = 'FOUR!'; 
        Sfx.four(); 
      } else if (runs == 3) {
        rMsg = '3 RUNS';
        Sfx.three();
      } else if (runs == 2) {
        rMsg = '2 RUNS';
        Sfx.two();
      } else { 
        rMsg = '1 RUN';
        Sfx.one();
      }

      rShot = sh.name; endBall(1.5);
    } else if (by > 139) {
      ball.isActive = false; combo = 0; balls++;
      rMsg = 'MISSED!'; rShot = ''; 
      Sfx.miss(); // ఆడియో: మిస్
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

    if (state == GameState.PLAY) {
      if (bowler.phase == 'runup') {
        bowler.frame++; if (bowler.frame >= 15) releaseBall();
      } else if (bowler.phase == 'deliver') {
        bowler.frame++; if (bowler.frame > 8) { bowler.phase = 'idle'; bowler.frame = 0; }
      } else if (bowler.phase == 'idle' && !ball.isActive) {
        bowlT -= dt; if (bowlT <= 0) startBowl();
      }

      if (ball.isActive) {
        if (!ball.bounced && ball.y >= ball.bounceAt) {
          ball.vy = ball.vy * 0.7 + 20; ball.bounced = true;
          Sfx.bounce(); // ఆడియో: బౌన్స్
        }
        ball.y += ball.vy * dt;

        if (ball.y >= 120 && ball.y <= 128 && (ball.x - 60).abs() < 8) {
          ball.isActive = false; wickets++; balls++; combo = 0;
          wicketNotifier.value = wickets; batsmanStumps.broken = true;
          batsmanStumps.t = 0.6; rMsg = 'OUT! W'; rShot = ''; 
          Sfx.outWicket(); // ఆడియో: ఔట్
          endBall(1.8);
        } else if (ball.y > 160) {
          ball.isActive = false; combo = 0; balls++; rMsg = 'DOT'; rShot = ''; endBall(0.8);
        }
      }

      if (batsman.swing) {
        batsman.swingTimer -= dt; if (batsman.swingTimer <= 0) batsman.swing = false;
      }
      if (batsmanStumps.broken && batsmanStumps.t > 0) {
        batsmanStumps.t -= dt;
      }
    } else if (state == GameState.RESULT) {
      rTimer -= dt;
      if (rTimer <= 0) {
        batsmanStumps.broken = false;
        if (balls >= maxBalls || wickets >= maxWickets) {
          Sfx.over(); // ఆడియో: మ్యాచ్ ఓవర్
          gameOverNotifier.value = true;
        } else {
          state = GameState.PLAY; ball.isActive = false; bowler.phase = 'idle'; bowlT = 0.8;
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
    final textP = TextPaint(style: const TextStyle(fontFamily: 'NokiaPixel', color: Color(0xFF0F380F), fontSize: 6, fontWeight: FontWeight.bold));
    if (bLabelTimer > 0) textP.render(canvas, bLabelText, Vector2(60, 40), anchor: Anchor.center);

    if (state == GameState.RESULT) {
      canvas.drawRect(const Rect.fromLTWH(15, 58, 90, 34), Paint()..color = const Color(0xFF0F380F));
      canvas.drawRect(const Rect.fromLTWH(17, 60, 86, 30), Paint()..color = const Color(0xFFC4E060));
      
      final rPaint = TextPaint(style: TextStyle(fontFamily: 'NokiaPixel', color: const Color(0xFF0F380F), fontSize: rMsg.length > 6 ? 8 : 10, fontWeight: FontWeight.bold));
      rPaint.render(canvas, rMsg, Vector2(60, 70), anchor: Anchor.center);
      
      if (rShot.isNotEmpty) {
        final sPaint = TextPaint(style: const TextStyle(fontFamily: 'NokiaPixel', color: Color(0xFF306230), fontSize: 6, fontWeight: FontWeight.bold));
        sPaint.render(canvas, rShot, Vector2(60, 82), anchor: Anchor.center);
      }
    }
  }
}

class Ball extends Component {
  double x = 60, y = 22, vy = 0, bounceAt = 0;
  bool isActive = false, bounced = false;
  void reset() { isActive = false; bounced = false; }
  @override void render(Canvas canvas) {
    if (!isActive) return;
    canvas.drawRect(Rect.fromLTWH(x - 1, y - 1, 3, 3), Paint()..color = const Color(0xFF0F380F));
    canvas.drawRect(Rect.fromLTWH(x, y + 1, 2, 1), Paint()..color = const Color(0xFF306230));
  }
}

// ---------------------------------------------
// అప్‌డేటెడ్ Bowler & Batsman (క్లియర్ విజువల్స్)
// ---------------------------------------------
class Bowler extends Component {
  double x = 60, y = 19;
  String phase = 'idle';
  int frame = 0;

  @override
  void render(Canvas canvas) {
    final p0 = Paint()..color = const Color(0xFF0F380F);
    void p(double px, double py, double w, double h) => canvas.drawRect(Rect.fromLTWH(px, py, w, h), p0);

    if (phase == 'idle') {
      p(x - 1, y - 6, 3, 3); // తల
      p(x - 2, y - 3, 5, 5); // బాడీ
      p(x - 2, y + 2, 2, 3); // ఎడమ కాలు
      p(x + 1, y + 2, 2, 3); // కుడి కాలు
    } else if (phase == 'runup') {
      int f = (frame / 4).floor() % 2;
      p(x - 1, y - 6, 3, 3); 
      p(x - 2, y - 3, 5, 5); 
      if (f == 0) {
        p(x - 2, y + 2, 2, 4); 
        p(x + 1, y + 1, 2, 2); 
      } else {
        p(x - 2, y + 1, 2, 2); 
        p(x + 1, y + 2, 2, 4); 
      }
    } else if (phase == 'deliver') {
      p(x - 1, y - 6, 3, 3); 
      p(x - 2, y - 3, 5, 5); 
      p(x + 3, y - 5, 2, 4); // చెయ్యి
      p(x - 2, y + 2, 2, 3); 
    }
  }
}

class Batsman extends Component {
  double x = 60, y = 126, swingTimer = 0;
  bool swing = false;

  @override
  void render(Canvas canvas) {
    final p0 = Paint()..color = const Color(0xFF0F380F); 
    final p1 = Paint()..color = const Color(0xFF306230); 
    void p(double px, double py, double w, double h, Paint pt) => canvas.drawRect(Rect.fromLTWH(px, py, w, h), pt);

    p(x - 4, y + 5, 9, 2, p1); // షాడో

    p(x - 2, y - 9, 4, 4, p0); // తల/హెల్మెట్
    p(x + 2, y - 8, 2, 2, p0); // గ్రిల్

    p(x - 3, y - 5, 6, 6, p0); // బాడీ

    p(x - 2, y + 1, 2, 4, p0); // కాళ్లు
    p(x + 1, y + 1, 2, 4, p0); 
    
    if (swing) {
      p(x - 10, y - 2, 10, 2, p0); // బ్యాట్ స్వింగ్
      p(x - 12, y - 3, 2, 4, p0);  
    } else {
      p(x + 3, y - 3, 2, 8, p0);   // ఐడిల్ బ్యాట్
      p(x + 3, y + 5, 3, 2, p0);   
    }
  }
}

class Stumps extends Component {
  bool broken = false; double t = 0;
  @override void render(Canvas canvas) {
    final p0 = Paint()..color = const Color(0xFF0F380F); final p1 = Paint()..color = const Color(0xFF306230);
    void p(double px, double py, double w, double h, Paint pt) => canvas.drawRect(Rect.fromLTWH(px, py, w, h), pt);

    if (!broken) { for(var sx in [56.0, 59.0, 62.0]) p(sx, 120, 1, 7, p0); p(55, 119, 11, 1, p0); } 
    else { double sp = 1 - (t / 0.6).clamp(0.0, 1.0); p(56 - sp * 7, 120 + sp * 5, 1, 5, p0); p(59, 120 + sp * 3, 1, 5, p0); p(62 + sp * 6, 120 + sp * 6, 1, 5, p0); p(55 - sp * 4, 119 - sp * 3, 11, 1, p1); }
  }
}
