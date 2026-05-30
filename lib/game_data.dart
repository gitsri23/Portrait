import 'package:shared_preferences/shared_preferences.dart';

class GameData {
  static late SharedPreferences prefs;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
  }

  static int get coins => prefs.getInt('coins') ?? 0;
  static set coins(int value) => prefs.setInt('coins', value);

  // లైఫ్‌టైమ్ స్టాట్స్ (అచీవ్‌మెంట్స్ & లెవెల్స్ కోసం)
  static int get totalRuns => prefs.getInt('totalRuns') ?? 0;
  static set totalRuns(int value) => prefs.setInt('totalRuns', value);

  static int get totalSixes => prefs.getInt('totalSixes') ?? 0;
  static set totalSixes(int value) => prefs.setInt('totalSixes', value);

  static int get totalFours => prefs.getInt('totalFours') ?? 0;
  static set totalFours(int value) => prefs.setInt('totalFours', value);

  // లెవెల్ సిస్టమ్: ప్రతి 50 రన్స్‌కి ఆటోమేటిక్‌గా 1 లెవెల్ పెరుగుతుంది!
  static int get level => 1 + (totalRuns ~/ 50);

  // బ్యాట్స్ సిస్టమ్
  static String get equippedBat => prefs.getString('equippedBat') ?? 'WOOD';
  static set equippedBat(String value) => prefs.setString('equippedBat', value);

  static bool isBatBought(String batName) {
    if (batName == 'WOOD') return true;
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

  // అచీవ్‌మెంట్స్ ట్రాకింగ్
  static bool isAchievementUnlocked(String id) => prefs.getBool('achv_$id') ?? false;
  static Future<void> unlockAchievement(String id) async => await prefs.setBool('achv_$id', true);
}
