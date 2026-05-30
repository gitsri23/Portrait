import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/camera.dart';
import 'package:flutter/material.dart';

// --- Ball Types Data ---
class BallType {
  final String id;
  final String label;
  final List<double> br;
  final double sm;
  final double p;
  BallType(this.id, this.label, this.br, this.sm, this.p);
}

final List<BallType> BTYPES = [
  BallType('normal', '', [70, 84], 1.0, 0.50),
  BallType('short', 'SHORT!', [50, 66], 0.9, 0.20),
  BallType('full', 'FULL', [90, 106], 1.1, 0.20),
  BallType('yorker', 'YORKER!', [114, 124], 1.3, 0.10),
];

// --- Shot Types Data ---
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

  // Stats for achievements/rewards
  int combo = 0;
  int maxCombo = 0;
  int sixes = 0;
  int fours = 0;
  int perfects = 0;
  int boundaries = 0;
  Set<String> shotsPlayed = {};
  List<dynamic> ballLog = [];

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
  double bowlT = 45;

  String bLabelText = '';
  double bLabelTimer = 0;

  @override
  Future<void> onLoad() async {
    camera.viewport = FixedAspectRatioViewport(aspectRatio: 120 / 160);

    // BG
    add(RectangleComponent(
      size: Vector2(120, 160),
      paint: Paint()..color = const Color(0xFF8BAC0F),
    ));

    // Crowd dots
    for (int i = 0; i < 30; i++) {
      add(RectangleComponent(
        position: Vector2((i * 4 + (i % 3)).toDouble(), rng.nextDouble() * 3 + 3),
        size: Vector2(2, (rng.nextInt(3) + 3).toDouble()),
        paint: Paint()..color = const Color(0xFF306230),
      ));
    }

    // Pitch
    add(RectangleComponent(
      position: Vector2(34, 14),
      size: Vector2(52, 122),
      paint: Paint()..color = const Color(0xFFC4E060),
    ));

    // Crease lines
    final creasePaint = Paint()..color = const Color(0xFF0F380F);
    add(RectangleComponent(position: Vector2(34, 18), size: Vector2(52, 1), paint: creasePaint));
    add(RectangleComponent(position: Vector2(34, 28), size: Vector2(52, 1), paint: creasePaint));
    add(RectangleComponent(position: Vector2(34, 118), size: Vector2(52, 1), paint: creasePaint));

    bowler = Bowler();
    batsman = Batsman();
    ball = Ball();
    batsmanStumps = Stumps();

    add(batsmanStumps);
    add(bowler);
    add(batsman);
    add(ball);

    resetG();
  }

  void resetG() {
    score = 0; wickets = 0; balls = 0;
    sixes = 0; fours = 0; boundaries = 0;
    perfects = 0; combo = 0; maxCombo = 0;
    shotsPlayed.clear(); ballLog.clear();
    
    scoreNotifier.value = 0;
    wicketNotifier.value = 0;
    gameOverNotifier.value = false;
    state = GameState.PLAY;
    bowlT = 45;
  }

  BallType pickBType() {
    double r = rng.nextDouble();
    double c = 0;
    for (var bt in BTYPES) {
      c += bt.p;
      if (r < c) return bt;
    }
    return BTYPES[0];
  }

  void startBowl() {
    if (ball.isActive || bowler.phase != 'idle') return;
    bowler.phase = 'runup';
    bowler.frame = 0;
  }

  void releaseBall() {
    BallType bt = pickBType();
    ball.x = 60 + (rng.nextDouble() * 10 - 5);
    ball.y = 22;
    // Speed multiplier based on ball type
    ball.vy = (1.5 + rng.nextDouble() * 1.5) * bt.sm; 
    ball.isActive = true;
    ball.bounced = false;
    ball.bounceAt = bt.br[0] + rng.nextDouble() * (bt.br[1] - bt.br[0]);
    
    if (bt.label.isNotEmpty) {
      bLabelText = bt.label;
      bLabelTimer = 0.5; // seconds
    }
    bowler.phase = 'deliver';
    bowler.frame = 0;
  }

  ShotType? detectShot(double by) {
    for (var entry in SHOTS.entries) {
      if (by >= entry.value.yr[0] && by < entry.value.yr[1]) {
        shotsPlayed.add(entry.key);
        return entry.value;
      }
    }
    return null;
  }

  void checkHit() {
    if (state != GameState.PLAY || !ball.isActive || batsman.swing) return;
    batsman.swing = true;
    batsman.swingTimer = 0.20;

    double by = ball.y;
    ShotType? sh = detectShot(by);

    if (sh != null) {
      // Contact
      ball.isActive = false;
      int runs = sh.runs[0] + rng.nextInt(sh.runs[1] - sh.runs[0] + 1);

      combo++;
      if (combo > maxCombo) maxCombo = combo;
      if (combo >= 3 && runs < 6) runs = min(runs + 1, 6);

      if (runs == 6) { sixes++; boundaries++; }
      else if (runs == 4) { fours++; boundaries++; }
      
      if (sh.name == 'STRAIGHT!') perfects++;
      
      score += runs;
      balls++;
      ballLog.add(runs);
      scoreNotifier.value = score;

      rMsg = runs == 6 ? 'SIX!' : runs == 4 ? 'FOUR!' : '$runs RUNS';
      rShot = sh.name;
      endBall(1.5);
    } else if (by > 139) {
      // Too late
      ball.isActive = false;
      combo = 0; balls++; ballLog.add(0);
      rMsg = 'MISSED!'; rShot = '';
      endBall(1.0);
    }
  }

  void endBall(double delay) {
    state = GameState.RESULT;
    rTimer = delay;
    bowler.phase = 'idle';
    bowler.frame = 0;
  }

  void finishInnings() {
    gameOverNotifier.value = true;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (gameOverNotifier.value) return;

    if (bLabelTimer > 0) bLabelTimer -= dt;

    if (state == GameState.PLAY) {
      if (bowler.phase == 'runup') {
        bowler.frame++;
        if (bowler.frame >= 24) releaseBall();
      } else if (bowler.phase == 'deliver') {
        bowler.frame++;
        if (bowler.frame > 12) {
          bowler.phase = 'idle';
          bowler.frame = 0;
        }
      } else if (bowler.phase == 'idle' && !ball.isActive) {
        bowlT -= dt * 60; 
        if (bowlT <= 0) startBowl();
      }

      if (ball.isActive) {
        if (!ball.bounced && ball.y >= ball.bounceAt) {
          ball.vy = ball.vy * 0.7 + 0.4;
          ball.bounced = true;
        }
        ball.y += ball.vy;

        // Hit Stumps
        if (ball.y >= 120 && ball.y <= 128 && (ball.x - 60).abs() < 8) {
          ball.isActive = false;
          wickets++; balls++; combo = 0; ballLog.add('W');
          wicketNotifier.value = wickets;
          batsmanStumps.broken = true;
          batsmanStumps.t = 0.6; // 600ms animation
          rMsg = 'OUT! W'; rShot = '';
          endBall(1.8);
        }
        // Keeper caught
        if (ball.y > 160) {
          ball.isActive = false; combo = 0; balls++; ballLog.add(0);
          rMsg = 'DOT'; rShot = '';
          endBall(0.8);
        }
      }

      if (batsman.swing) {
        batsman.swingTimer -= dt;
        if (batsman.swingTimer <= 0) batsman.swing = false;
      }
      
      if (batsmanStumps.broken && batsmanStumps.t > 0) {
        batsmanStumps.t -= dt;
      }

    } else if (state == GameState.RESULT) {
      rTimer -= dt;
      if (rTimer <= 0) {
        batsmanStumps.broken = false;
        if (balls >= maxBalls || wickets >= maxWickets) {
          finishInnings();
        } else {
          state = GameState.PLAY;
          ball.isActive = false;
          bowler.phase = 'idle';
          bowlT = 35;
        }
      }
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    onTap();
  }

  void onTap() {
    if (gameOverNotifier.value) return;
    checkHit();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Ball label
    if (bLabelTimer > 0) {
      final msgPaint = TextPaint(
        style: const TextStyle(color: Color(0xFF0F380F), fontSize: 5, fontFamily: 'Press Start 2P'),
      );
      msgPaint.render(canvas, bLabelText, Vector2(60, 40), anchor: Anchor.center);
    }

    // Result popup
    if (state == GameState.RESULT) {
      canvas.drawRect(const Rect.fromLTWH(15, 58, 90, 34), Paint()..color = const Color(0xFF0F380F));
      canvas.drawRect(const Rect.fromLTWH(17, 60, 86, 30), Paint()..color = const Color(0xFFC4E060));
      
      final rPaint = TextPaint(style: TextStyle(color: const Color(0xFF0F380F), fontSize: rMsg.length > 6 ? 8 : 10, fontWeight: FontWeight.bold));
      rPaint.render(canvas, rMsg, Vector2(60, 73), anchor: Anchor.center);
      
      if (rShot.isNotEmpty) {
        final sPaint = TextPaint(style: const TextStyle(color: Color(0xFF306230), fontSize: 5));
        sPaint.render(canvas, rShot, Vector2(60, 83), anchor: Anchor.center);
      }
    }
  }
}

class Ball extends Component {
  double x = 60;
  double y = 22;
  double vy = 0;
  bool isActive = false;
  bool bounced = false;
  double bounceAt = 0;

  @override
  void render(Canvas canvas) {
    if (!isActive) return;
    canvas.drawRect(Rect.fromLTWH(x - 1, y - 1, 3, 3), Paint()..color = const Color(0xFF0F380F));
    canvas.drawRect(Rect.fromLTWH(x, y + 1, 2, 1), Paint()..color = const Color(0xFF306230));
  }
}

class Bowler extends Component {
  double x = 60;
  double y = 19;
  String phase = 'idle';
  int frame = 0;

  @override
  void render(Canvas canvas) {
    final p0 = Paint()..color = const Color(0xFF0F380F);
    void p(double px, double py, double w, double h) => canvas.drawRect(Rect.fromLTWH(px, py, w, h), p0);

    if (phase == 'idle') {
      p(x - 1, y - 7, 3, 2); p(x - 2, y - 5, 5, 4);
      p(x - 1, y - 1, 1, 3); p(x + 1, y - 1, 1, 3);
      p(x - 3, y - 4, 2, 1); p(x + 2, y - 4, 2, 1);
    } else if (phase == 'runup') {
      int f = (frame / 4).floor() % 2;
      p(x - 1, y - 7, 3, 2); p(x - 2, y - 5, 5, 4);
      if (f == 0) { p(x - 2, y - 1, 1, 3); p(x + 1, y, 1, 3); p(x - 4, y - 3, 2, 1); p(x + 2, y - 5, 2, 1); }
      else { p(x - 1, y, 1, 3); p(x + 2, y - 1, 1, 3); p(x - 4, y - 5, 2, 1); p(x + 2, y - 3, 2, 1); }
    } else if (phase == 'deliver') {
      p(x - 1, y - 7, 3, 2); p(x - 2, y - 5, 5, 4);
      p(x - 2, y - 1, 1, 3); p(x + 2, y, 1, 4);
      p(x + 2, y - 8, 1, 3); p(x + 3, y - 6, 1, 2);
    }
  }
}

class Batsman extends Component {
  double x = 60;
  double y = 126;
  bool swing = false;
  double swingTimer = 0;

  @override
  void render(Canvas canvas) {
    final p0 = Paint()..color = const Color(0xFF0F380F);
    final p1 = Paint()..color = const Color(0xFF306230);
    void p(double px, double py, double w, double h, Paint pt) => canvas.drawRect(Rect.fromLTWH(px, py, w, h), pt);

    p(x - 3, y + 4, 8, 1, p1);
    p(x - 1, y - 9, 4, 3, p0); p(x + 2, y - 8, 1, 2, p0);
    p(x - 3, y - 6, 7, 5, p0);
    p(x - 3, y - 1, 3, 6, p0); p(x + 1, y - 1, 3, 6, p0);
    
    if (swing) {
      p(x - 11, y - 3, 9, 2, p0); p(x - 12, y - 5, 2, 5, p0);
    } else {
      p(x + 4, y - 3, 2, 9, p0); p(x + 3, y + 4, 4, 2, p0);
    }
  }
}

class Stumps extends Component {
  bool broken = false;
  double t = 0;

  @override
  void render(Canvas canvas) {
    final p0 = Paint()..color = const Color(0xFF0F380F);
    final p1 = Paint()..color = const Color(0xFF306230);
    void p(double px, double py, double w, double h, Paint pt) => canvas.drawRect(Rect.fromLTWH(px, py, w, h), pt);

    if (!broken) {
      for(var sx in [56.0, 59.0, 62.0]) p(sx, 120, 1, 7, p0);
      p(55, 119, 11, 1, p0);
    } else {
      double sp = 1 - (t / 0.6).clamp(0.0, 1.0);
      p(56 - sp * 7, 120 + sp * 5, 1, 5, p0);
      p(59, 120 + sp * 3, 1, 5, p0);
      p(62 + sp * 6, 120 + sp * 6, 1, 5, p0);
      p(55 - sp * 4, 119 - sp * 3, 11, 1, p1);
    }
  }
}
