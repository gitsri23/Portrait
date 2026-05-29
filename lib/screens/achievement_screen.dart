import 'package:flutter/material.dart';

class Achievement {
  final String title;
  final String description;
  final bool unlocked;

  // ఇక్కడ const యాడ్ చేశాం
  const Achievement({
    required this.title,
    required this.description,
    required this.unlocked,
  });
}

class AchievementScreen extends StatelessWidget {
  // ఇక్కడ const కన్‌స్ట్రక్టర్ యాడ్ చేశాం
  const AchievementScreen({super.key});

  // లిస్ట్‌కి కూడా const యాడ్ చేశాం
  final List<Achievement> achievements = const [
    Achievement(
      title: "First Run",
      description: "Score your first run",
      unlocked: true,
    ),
    Achievement(
      title: "Boundary King",
      description: "Hit 10 fours",
      unlocked: true,
    ),
    Achievement(
      title: "Six Machine",
      description: "Hit 25 sixes",
      unlocked: false,
    ),
    Achievement(
      title: "Half Century",
      description: "Score 50 runs",
      unlocked: true,
    ),
    Achievement(
      title: "Century Hero",
      description: "Score 100 runs",
      unlocked: false,
    ),
    Achievement(
      title: "Combo Master",
      description: "5 combo hits",
      unlocked: false,
    ),
    Achievement(
      title: "World Cup Winner",
      description: "Win World Cup",
      unlocked: false,
    ),
    Achievement(
      title: "Legend Player",
      description: "Reach Level 25",
      unlocked: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Achievements",
        ),
      ),
      body: ListView.builder(
        itemCount: achievements.length,
        itemBuilder: (context, index) {
          final a = achievements[index];

          return Card(
            child: ListTile(
              leading: Icon(
                a.unlocked ? Icons.emoji_events : Icons.lock,
              ),
              title: Text(
                a.title,
              ),
              subtitle: Text(
                a.description,
              ),
              trailing: Text(
                a.unlocked ? "DONE" : "LOCKED",
              ),
            ),
          );
        },
      ),
    );
  }
}
