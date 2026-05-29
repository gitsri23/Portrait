import 'package:flutter/material.dart';

class Achievement {

  final String title;
  final String description;
  final bool unlocked;

  Achievement({
    required this.title,
    required this.description,
    required this.unlocked,
  });
}

class AchievementScreen extends StatelessWidget {

  AchievementScreen({super.key});

  final List<Achievement> achievements = [

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

        itemBuilder: (context,index){

          final a =
              achievements[index];

          return Card(

            child: ListTile(

              leading: Icon(
                a.unlocked
                    ? Icons.emoji_events
                    : Icons.lock,
              ),

              title: Text(
                a.title,
              ),

              subtitle: Text(
                a.description,
              ),

              trailing: Text(
                a.unlocked
                    ? "DONE"
                    : "LOCKED",
              ),
            ),
          );
        },
      ),
    );
  }
}
