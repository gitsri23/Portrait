import 'package:flutter/material.dart';
import 'game_screen.dart'; 
import '../game_data.dart';

class League {
  final String name;
  final String subtitle;
  final int balls;
  final int wickets;
  final double reward;
  final int stars;

  const League({
    required this.name,
    required this.subtitle,
    required this.balls,
    required this.wickets,
    required this.reward,
    required this.stars,
  });
}

class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  int current = 0;

  final leagues = const [
    League(name: "GULLY", subtitle: "Street Cricket", balls: 6, wickets: 1, reward: 1.0, stars: 1),
    League(name: "CLUB", subtitle: "Club Match", balls: 12, wickets: 3, reward: 1.2, stars: 2),
    League(name: "T20", subtitle: "League Cricket", balls: 20, wickets: 5, reward: 1.5, stars: 3),
    League(name: "IPL", subtitle: "Premier League", balls: 24, wickets: 7, reward: 1.8, stars: 4),
    League(name: "WORLD CUP", subtitle: "Championship", balls: 30, wickets: 10, reward: 2.0, stars: 5),
  ];

  void prevLeague() {
    if (current > 0) {
      setState(() {
        current--;
      });
    }
  }

  void nextLeague() {
    if (current < leagues.length - 1) {
      setState(() {
        current++;
      });
    }
  }

  void startMatch() async {
    final lg = leagues[current];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Starting ${lg.name}"),
        duration: const Duration(seconds: 1),
      ),
    );

    // మ్యాచ్ స్టార్ట్ అవుతుంది. గేమ్ ఆడి రాగానే కింద ఉన్న setState రన్ అవుతుంది
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          leagueName: lg.name,
          balls: lg.balls,
          wickets: lg.wickets,
        ),
      ),
    );
    
    // స్కోర్ అప్‌డేట్ అవ్వడానికి రిఫ్రెష్
    setState(() {}); 
  }

  Widget starRow(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        5,
        (index) {
          bool active = index < count;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.star,
              size: 18,
              color: active ? const Color(0xFFC4E060) : const Color(0xFF306230),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lg = leagues[current];

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
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 15),
              const Text(
                "NOKIA",
                style: TextStyle(color: Color(0xFF3A94D4), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
              const SizedBox(height: 20),
              Container(
                width: 250,
                height: 350,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF8BAC0F),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 4),
                ),
                child: Column(
                  children: [
                    const Text("SELECT LEAGUE", style: TextStyle(color: Color(0xFF0F380F), fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    Container(height: 2, color: const Color(0xFF306230)),
                    const SizedBox(height: 20),
                    Text(lg.name, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF0F380F), fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(lg.subtitle, style: const TextStyle(color: Color(0xFF306230), fontSize: 12)),
                    const SizedBox(height: 18),
                    starRow(lg.stars),
                    const SizedBox(height: 20),
                    Text("BALLS : ${lg.balls}", style: const TextStyle(color: Color(0xFF0F380F), fontSize: 12)),
                    const SizedBox(height: 8),
                    Text("WICKETS : ${lg.wickets}", style: const TextStyle(color: Color(0xFF0F380F), fontSize: 12)),
                    const SizedBox(height: 8),
                    Text("REWARD : ${lg.reward}x", style: const TextStyle(color: Color(0xFF0F380F), fontSize: 12)),
                    const SizedBox(height: 25),
                    Container(height: 2, color: const Color(0xFF306230)),
                    const SizedBox(height: 18),
                    const Text("BEST SCORE", style: TextStyle(color: Color(0xFF306230), fontSize: 10)),
                    const SizedBox(height: 10),
                    
                    // రియల్ బెస్ట్ స్కోర్ చూపిస్తున్నాం
                    Text(
                      "${GameData.getBestScore(lg.name)}",
                      style: const TextStyle(color: Color(0xFF0F380F), fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    
                    const Spacer(),
                    const Text("◄ ► CHANGE", style: TextStyle(color: Color(0xFF306230), fontSize: 10)),
                    const SizedBox(height: 6),
                    const Text("5 START", style: TextStyle(color: Color(0xFF0F380F), fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(onPressed: prevLeague, child: const Icon(Icons.arrow_back)),
                  ElevatedButton(onPressed: startMatch, child: const Text("5")),
                  ElevatedButton(onPressed: nextLeague, child: const Icon(Icons.arrow_forward)),
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
