import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../game/cricket_game.dart';

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
    // cricket_game.dart లో maxBalls మరియు maxWickets వేరియబుల్స్ ఉండాలి
    game.maxBalls = widget.balls;
    game.maxWickets = widget.wickets;
  }

  Widget buildScoreBar() {
    return Positioned(
      top: 40,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: const Color(0xCC0F380F),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: game.scoreNotifier,
              builder: (_, value, __) {
                return Text(
                  "RUNS $value",
                  style: const TextStyle(
                    color: Color(0xFFC4E060),
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            ValueListenableBuilder<int>(
              valueListenable: game.wicketNotifier,
              builder: (_, value, __) {
                return Text(
                  "WKT $value",
                  style: const TextStyle(
                    color: Color(0xFFC4E060),
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBottomBar() {
    return Positioned(
      bottom: 25,
      left: 15,
      right: 15,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              game.pauseEngine();
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Paused"),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        game.resumeEngine();
                      },
                      child: const Text("Resume"),
                    )
                  ],
                ),
              );
            },
            icon: const Icon(Icons.pause),
            label: const Text("Pause"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              game.onTap(); // cricket_game.dart లో ఈ మెథడ్ ఉండాలి
            },
            icon: const Icon(Icons.sports_cricket),
            label: const Text("Hit"),
          ),
        ],
      ),
    );
  }

  Widget buildLeagueLabel() {
    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0F380F),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.leagueName,
            style: const TextStyle(
              color: Color(0xFFC4E060),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildGameOverWatcher() {
    return ValueListenableBuilder<bool>(
      valueListenable: game.gameOverNotifier,
      builder: (_, value, __) {
        if (value == false) {
          return const SizedBox();
        }

        Future.delayed(
          const Duration(milliseconds: 400),
          () {
            if (!mounted) return;

            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) {
                return AlertDialog(
                  title: const Text("Match Finished"),
                  content: ValueListenableBuilder<int>(
                    valueListenable: game.scoreNotifier,
                    builder: (_, score, __) {
                      int coins = score * 2; // ఇక్కడ ఇరువైపులా int అవ్వడం వల్ల ఎర్రర్ రాదు

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Score : $score"),
                          const SizedBox(height: 10),
                          Text("Coins : $coins"),
                        ],
                      );
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: const Text("Back"),
                    )
                  ],
                );
              },
            );
          },
        );

        return const SizedBox();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            GameWidget(game: game),
            buildLeagueLabel(),
            buildScoreBar(),
            buildBottomBar(),
            buildGameOverWatcher(),
          ],
        ),
      ),
    );
  }
}
