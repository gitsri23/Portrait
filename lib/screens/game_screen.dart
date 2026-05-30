import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/cricket_game.dart'; // కరెక్ట్ పాత్
import '../game_data.dart'; // కరెక్ట్ పాత్

class GameScreen extends StatefulWidget {
  final String leagueName;
  final int balls;
  final int wickets;

  const GameScreen({
    super.key,
    required this.leagueName,
    required this.balls,
    required this.wickets,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late CricketGame game;

  @override
  void initState() {
    super.initState();
    game = CricketGame();
    game.maxBalls = widget.balls;
    game.maxWickets = widget.wickets;
  }

  Widget buildScoreBar() {
    return Positioned(
      top: 30,
      left: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xCC0F380F),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: game.scoreNotifier,
              builder: (_, value, __) => Text("RUNS $value",
                  style: const TextStyle(
                      color: Color(0xFFC4E060),
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
            ValueListenableBuilder<int>(
              valueListenable: game.wicketNotifier,
              builder: (_, value, __) => Text("WKT $value",
                  style: const TextStyle(
                      color: Color(0xFFC4E060),
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildLeagueLabel() {
    return Positioned(
      top: 5,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F380F),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.leagueName,
            style: const TextStyle(
                color: Color(0xFFC4E060),
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget buildGameOverWatcher() {
    return ValueListenableBuilder<bool>(
      valueListenable: game.gameOverNotifier,
      builder: (_, isGameOver, __) {
        if (!isGameOver) return const SizedBox();

        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;

          int finalScore = game.scoreNotifier.value;
          int earnedCoins = finalScore * 2;

          GameData.coins += earnedCoins;
          GameData.setBestScore(widget.leagueName, finalScore);
          GameData.totalRuns += finalScore;
          GameData.totalSixes += game.sixes;
          GameData.totalFours += game.fours;

          if (GameData.totalRuns > 0) GameData.unlockAchievement("first_run");
          if (GameData.totalFours >= 10) GameData.unlockAchievement("boundary_king");
          if (GameData.totalSixes >= 25) GameData.unlockAchievement("six_machine");
          if (finalScore >= 50) GameData.unlockAchievement("half_century");
          if (finalScore >= 100) GameData.unlockAchievement("century_hero");
          if (game.maxCombo >= 5) GameData.unlockAchievement("combo_master");
          if (widget.leagueName == "WORLD CUP" && finalScore >= 50) {
            GameData.unlockAchievement("world_cup");
          }
          if (GameData.level >= 25) GameData.unlockAchievement("legend");

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF8BAC0F),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFF0F380F), width: 4),
                borderRadius: BorderRadius.circular(8),
              ),
              title: const Text("INNINGS OVER",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFF0F380F), fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("$finalScore RUNS",
                      style: const TextStyle(
                          color: Color(0xFF0F380F),
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text("COINS EARNED: +$earnedCoins",
                      style: const TextStyle(
                          color: Color(0xFF306230),
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text("TOTAL COINS: ${GameData.coins}",
                      style: const TextStyle(
                          color: Color(0xFF0F380F),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F380F)),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text("BACK TO MENU",
                      style: TextStyle(color: Color(0xFFC4E060))),
                )
              ],
            ),
          );
        });
        return const SizedBox();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: 320,
          height: 620,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              colors: [Color(0xFF555555), Color(0xFF222222)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                  blurRadius: 30, color: Colors.black87, offset: Offset(0, 15))
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Text("NOKIA",
                  style: TextStyle(
                      color: Color(0xFF3A94D4),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      fontSize: 18)),
              const SizedBox(height: 18),
              Container(
                width: 250,
                height: 350,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF090E06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: SizedBox(
                            width: 120,
                            height: 160,
                            child: GameWidget(game: game),
                          ),
                        ),
                      ),
                      buildLeagueLabel(),
                      buildScoreBar(),
                      buildGameOverWatcher(),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      backgroundColor: const Color(0xFF4A4A4A),
                      minimumSize: const Size(60, 40),
                    ),
                    onPressed: () {
                      game.pauseEngine();
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF8BAC0F),
                          title: const Text("PAUSED",
                              style: TextStyle(
                                  color: Color(0xFF0F380F),
                                  fontWeight: FontWeight.bold)),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                game.resumeEngine();
                              },
                              child: const Text("RESUME",
                                  style: TextStyle(
                                      color: Color(0xFF0F380F),
                                      fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                      );
                    },
                    child: const Icon(Icons.pause, color: Colors.white70),
                  ),
                  GestureDetector(
                    onTapDown: (_) => game.onTap(),
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0xFFEEEEEE), Color(0xFF888888)],
                          center: Alignment(-0.3, -0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Color(0xFF555555), offset: Offset(0, 4))
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text("5",
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333))),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      backgroundColor: const Color(0xFF4A4A4A),
                      minimumSize: const Size(60, 40),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.exit_to_app, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text("PAUSE",
                      style: TextStyle(color: Colors.white54, fontSize: 10)),
                  Text("HIT",
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  Text("EXIT",
                      style: TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}
