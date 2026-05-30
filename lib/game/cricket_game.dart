import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/camera.dart'; // కొత్త Viewport కోసం ఇది యాడ్ చేశాం
import 'package:flutter/material.dart';

// TapDetector బదులు TapCallbacks వాడుతున్నాం
class CricketGame extends FlameGame with TapCallbacks {

  final Random rng = Random();

  // Score
  int score = 0;
  int wickets = 0;

  int balls = 0;
  int maxBalls = 12;
  int maxWickets = 3; // GameScreen నుండి దీనికి వాల్యూ వస్తుంది

  // GameScreen కి డేటా పంపడానికి Notifiers
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> wicketNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> gameOverNotifier = ValueNotifier<bool>(false);

  String message = "";
  double messageTimer = 0;

  late Ball ball;
  late Batsman batsman;
  late Bowler bowler;

  bool gameOver = false;

  @override
  Future<void> onLoad() async {

    // పాత FixedResolutionViewport బదులు ఇది
    camera.viewport = FixedAspectRatioViewport(
      aspectRatio: 360 / 640,
    );

    add(
      RectangleComponent(
        size: Vector2(360, 640),
        paint: Paint()
          ..color = const Color(0xFF8BAC0F),
      ),
    );

    bowler = Bowler();
    batsman = Batsman();
    ball = Ball();

    add(bowler);
    add(batsman);
    add(ball);

    startBall();
  }

  void startBall() {

    if (gameOver) return;

    ball.reset();

    ball.position = Vector2(
      180,
      120,
    );

    ball.speed = 220 +
        rng.nextDouble() * 120;
  }

  @override
  void update(double dt) {

    super.update(dt);

    if (gameOver) return;

    if (messageTimer > 0) {
      messageTimer -= dt;
    }

    ball.position.y +=
        ball.speed * dt;

    if (ball.position.y >= 520 &&
        !ball.hitChecked) {

      ball.hitChecked = true;

      wickets++;
      wicketNotifier.value = wickets; // Notifier అప్‌డేట్

      balls++;

      showMessage("OUT!");

      if (balls >= maxBalls ||
          wickets >= maxWickets) { // ఇక్కడ maxWickets తో చెక్ చేస్తున్నాం
        finishGame();
      } else {
        startBall();
      }
    }

    if (batsman.swinging) {

      batsman.swingTimer -= dt;

      if (batsman.swingTimer <= 0) {
        batsman.swinging = false;
      }
    }
  }

  // TapCallbacks వల్ల వచ్చే మెథడ్. ఇది పబ్లిక్ onTap() ని పిలుస్తుంది
  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    onTap();
  }

  // GameScreen నుండి మరియు స్క్రీన్ మీద నొక్కినప్పుడు రన్ అయ్యే మెథడ్
  void onTap() {

    if (gameOver) {
      resetMatch();
      return;
    }

    batsman.swing();

    attemptHit();
  }

  void attemptHit() {

    double distance =
        (ball.position.y - 470).abs();

    if (distance < 15) {

      score += 6;
      balls++;
      showMessage("SIX!");

    } else if (distance < 30) {

      score += 4;
      balls++;
      showMessage("FOUR!");

    } else if (distance < 50) {

      score += 2;
      balls++;
      showMessage("2 RUNS");

    } else if (distance < 80) {

      score += 1;
      balls++;
      showMessage("1 RUN");

    } else {
      return;
    }

    scoreNotifier.value = score; // Notifier అప్‌డేట్

    ball.position.y = -500;

    if (balls >= maxBalls) {
      finishGame();
    } else {
      startBall();
    }
  }

  void showMessage(
    String txt,
  ) {

    message = txt;
    messageTimer = 1.2;
  }

  void finishGame() {

    gameOver = true;
    gameOverNotifier.value = true; // Notifier అప్‌డేట్

    message =
        "GAME OVER\nScore: $score";

    messageTimer = 9999;
  }

  void resetMatch() {

    score = 0;
    wickets = 0;
    balls = 0;

    scoreNotifier.value = 0;
    wicketNotifier.value = 0;
    gameOverNotifier.value = false;

    gameOver = false;

    startBall();
  }

  @override
  void render(Canvas canvas) {

    super.render(canvas);

    final scorePaint = TextPaint(
      style: const TextStyle(
        color: Color(0xFF0F380F),
        fontWeight: FontWeight.bold,
        fontSize: 24,
      ),
    );

    scorePaint.render(
      canvas,
      "$score/$wickets",
      Vector2(
        20,
        20,
      ),
    );

    scorePaint.render(
      canvas,
      "$balls/$maxBalls",
      Vector2(
        250,
        20,
      ),
    );

    final pitchPaint = Paint()
      ..color =
          const Color(0xFFC4E060);

    canvas.drawRect(
      const Rect.fromLTWH(
        120,
        80,
        120,
        460,
      ),
      pitchPaint,
    );

    if (messageTimer > 0) {

      final msgPaint = TextPaint(
        style: const TextStyle(
          color: Color(0xFF0F380F),
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
      );

      msgPaint.render(
        canvas,
        message,
        Vector2(
          80,
          280,
        ),
      );
    }
  }
}

class Ball extends CircleComponent {

  double speed = 250;

  bool hitChecked = false;

  Ball()
      : super(
          radius: 10,
          paint: Paint()
            ..color =
                const Color(0xFF0F380F),
        );

  void reset() {

    hitChecked = false;

    position = Vector2(
      180,
      120,
    );
  }
}

class Batsman
    extends RectangleComponent {

  bool swinging = false;

  double swingTimer = 0;

  Batsman()
      : super(
          position: Vector2(
            150,
            470,
          ),
          size: Vector2(
            60,
            60,
          ),
          paint: Paint()
            ..color =
                const Color(0xFF306230),
        );

  void swing() {

    swinging = true;
    swingTimer = 0.20;
  }

  @override
  void render(Canvas canvas) {

    super.render(canvas);

    final batPaint = Paint()
      ..color =
          const Color(0xFF0F380F);

    if (swinging) {

      canvas.drawRect(
        const Rect.fromLTWH(
          40,
          10,
          70,
          10,
        ),
        batPaint,
      );

    } else {

      canvas.drawRect(
        const Rect.fromLTWH(
          55,
          -30,
          10,
          50,
        ),
        batPaint,
      );
    }
  }
}

class Bowler
    extends RectangleComponent {

  Bowler()
      : super(
          position: Vector2(
            160,
            60,
          ),
          size: Vector2(
            40,
            40,
          ),
          paint: Paint()
            ..color =
                const Color(0xFF306230),
        );
}
