import 'package:flutter/material.dart';
import 'league_screen.dart';
import 'shop_screen.dart';
import 'achievement_screen.dart';
import '../game_data.dart'; // GameData ఫైల్ కచ్చితంగా ఇంపోర్ట్ చేయాలి

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selected = 0;
  final List<String> menuItems = [
    "PLAY",
    "SHOP",
    "STATS",
    "ACHIEVEMENTS",
    "EXIT"
  ];

  void moveUp() {
    setState(() {
      selected--;
      if (selected < 0) {
        selected = menuItems.length - 1;
      }
    });
  }

  void moveDown() {
    setState(() {
      selected++;
      if (selected >= menuItems.length) {
        selected = 0;
      }
    });
  }

  // నావిగేషన్ తర్వాత డేటా రిఫ్రెష్ చేయడానికి async వాడాము
  void selectItem() async {
    String item = menuItems[selected];

    if (item == "PLAY") {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LeagueScreen()),
      );
      setState(() {}); // ఆడి వచ్చాక కాయిన్స్ రిఫ్రెష్ అవుతాయి
    } else if (item == "SHOP") {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ShopScreen()),
      );
      setState(() {}); // కొని వచ్చాక కాయిన్స్ రిఫ్రెష్ అవుతాయి
    } else if (item == "ACHIEVEMENTS") {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AchievementScreen()),
      );
      setState(() {});
    } else if (item == "EXIT") {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$item Coming Soon"),
        ),
      );
    }
  }

  Widget buildMenuItem(String text, bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF0F380F) : Colors.transparent,
      ),
      child: Text(
        active ? "> $text" : text,
        style: TextStyle(
          color: active ? const Color(0xFFC4E060) : const Color(0xFF306230),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildPhone() {
    return Container(
      width: 320,
      height: 620,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF555555),
            Color(0xFF222222),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 30,
            color: Colors.black87,
            offset: Offset(0, 15),
          )
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          const Text(
            "NOKIA",
            style: TextStyle(
              color: Color(0xFF3A94D4),
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 250,
            height: 340,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8BAC0F),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.black,
                width: 4,
              ),
            ),
            child: Column(
              children: [
                const Text(
                  "NOKIA CRICKET",
                  style: TextStyle(
                    color: Color(0xFF0F380F),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 2,
                  color: const Color(0xFF306230),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "COINS: ${GameData.coins}", // రియల్ కాయిన్స్
                      style: const TextStyle(
                        color: Color(0xFF0F380F),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "LV:${GameData.level}", // రియల్ లెవెల్
                      style: const TextStyle(
                        color: Color(0xFF0F380F),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      menuItems.length,
                      (index) => buildMenuItem(
                        menuItems[index],
                        selected == index,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "SELECT WITH KEYPAD",
                  style: TextStyle(
                    color: Color(0xFF306230),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: moveUp,
                child: const Icon(Icons.arrow_upward),
              ),
              ElevatedButton(
                onPressed: selectItem,
                child: const Text("5"),
              ),
              ElevatedButton(
                onPressed: moveDown,
                child: const Icon(Icons.arrow_downward),
              ),
            ],
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: buildPhone(),
      ),
    );
  }
}
