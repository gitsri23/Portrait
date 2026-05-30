import 'package:shared_preferences/shared_preferences.dart';

class GameData {
  static late SharedPreferences prefs;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
  }

  // కాయిన్స్
  static int get coins => prefs.getInt('coins') ?? 0;
  static set coins(int value) => prefs.setInt('coins', value);

  // లెవెల్
  static int get level => prefs.getInt('level') ?? 1;
  static set level(int value) => prefs.setInt('level', value);

  // బ్యాట్స్ సిస్టమ్ (షాప్ కోసం)
  static String get equippedBat => prefs.getString('equippedBat') ?? 'WOOD';
  static set equippedBat(String value) => prefs.setString('equippedBat', value);

  static bool isBatBought(String batName) {
    if (batName == 'WOOD') return true; // డిఫాల్ట్ బ్యాట్
    return prefs.getBool('bat_$batName') ?? false;
  }

  static Future<void> buyBat(String batName) async {
    await prefs.setBool('bat_$batName', true);
  }

  // బెస్ట్ స్కోర్స్
  static int getBestScore(String league) => prefs.getInt('best_$league') ?? 0;
  
  static Future<void> setBestScore(String league, int score) async {
    int currentBest = getBestScore(league);
    if (score > currentBest) {
      await prefs.setInt('best_$league', score);
    }
  }
}
