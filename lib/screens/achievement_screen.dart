import 'package:flutter/material.dart';
import '../game_data.dart';

class Achievement {
  final String id;
  final String title;
  final String description;

  Achievement({required this.id, required this.title, required this.description});
}

class AchievementScreen extends StatelessWidget {
  const AchievementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // రియల్ టైమ్ డేటా అచీవ్‌మెంట్స్!
    final List<Achievement> achievements = [
      Achievement(id: "first_run", title: "First Run", description: "Score your first run"),
      Achievement(id: "boundary_king", title: "Boundary King", description: "Hit 10 fours in total"),
      Achievement(id: "six_machine", title: "Six Machine", description: "Hit 25 sixes in total"),
      Achievement(id: "half_century", title: "Half Century", description: "Score 50 runs in a match"),
      Achievement(id: "century_hero", title: "Century Hero", description: "Score 100 runs in a match"),
      Achievement(id: "combo_master", title: "Combo Master", description: "Hit 5 shots in a row"),
      Achievement(id: "world_cup", title: "World Cup Winner", description: "Win World Cup (Score 50+)"),
      Achievement(id: "legend", title: "Legend Player", description: "Reach Level 25"),
    ];

    return Scaffold(
      backgroundColor: Colors.black, // వైట్ స్క్రీన్ తీసేసి బ్లాక్ పెట్టాం
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("ACHIEVEMENTS", style: TextStyle(color: Colors.white)),
      ),
      body: ListView.builder(
        itemCount: achievements.length,
        itemBuilder: (context, index) {
          final a = achievements[index];
          // అన్‌లాక్ అయ్యిందో లేదో డేటాబేస్ నుండి తెచ్చుకోవడం
          bool isUnlocked = GameData.isAchievementUnlocked(a.id);

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              // అన్‌లాక్ అయితే గ్రీన్ కలర్, లేకపోతే డార్క్ గ్రే
              color: isUnlocked ? const Color(0xFF8BAC0F) : const Color(0xFF222222),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0F380F), width: 3),
            ),
            child: Row(
              children: [
                Icon(
                  isUnlocked ? Icons.emoji_events : Icons.lock,
                  color: isUnlocked ? const Color(0xFF0F380F) : Colors.black54,
                  size: 30,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title, 
                        style: TextStyle(
                          color: isUnlocked ? const Color(0xFF0F380F) : Colors.white54, 
                          fontSize: 16, 
                          fontWeight: FontWeight.bold
                        )
                      ),
                      const SizedBox(height: 5),
                      Text(
                        a.description, 
                        style: TextStyle(
                          color: isUnlocked ? const Color(0xFF306230) : Colors.white38, 
                          fontSize: 10
                        )
                      ),
                    ],
                  ),
                ),
                Text(
                  isUnlocked ? "DONE" : "LOCKED",
                  style: TextStyle(
                    color: isUnlocked ? const Color(0xFF0F380F) : Colors.white38, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
