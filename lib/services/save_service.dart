import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SaveService {

  static const String coinsKey = "coins";
  static const String xpKey = "xp";
  static const String levelKey = "level";

  static const String bestKey = "best_score";

  static const String unlockKey =
      "unlocked_bats";

  static const String selectedBatKey =
      "selected_bat";

  // COINS

  static Future<void> saveCoins(
    int coins,
  ) async {

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setInt(
      coinsKey,
      coins,
    );
  }

  static Future<int> loadCoins()
  async {

    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getInt(
          coinsKey,
        ) ??
        0;
  }

  // XP

  static Future<void> saveXP(
    int xp,
  ) async {

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setInt(
      xpKey,
      xp,
    );
  }

  static Future<int> loadXP()
  async {

    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getInt(
          xpKey,
        ) ??
        0;
  }

  // LEVEL

  static Future<void> saveLevel(
    int level,
  ) async {

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setInt(
      levelKey,
      level,
    );
  }

  static Future<int> loadLevel()
  async {

    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getInt(
          levelKey,
        ) ??
        1;
  }

  // BEST SCORE

  static Future<void>
      saveBestScore(
    int score,
  ) async {

    final prefs =
        await SharedPreferences.getInstance();

    int currentBest =
        prefs.getInt(bestKey) ?? 0;

    if (score > currentBest) {

      await prefs.setInt(
        bestKey,
        score,
      );
    }
  }

  static Future<int>
      loadBestScore()
  async {

    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getInt(
          bestKey,
        ) ??
        0;
  }

  // BATS

  static Future<void>
      saveUnlockedBats(
    List<String> bats,
  ) async {

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      unlockKey,
      jsonEncode(
        bats,
      ),
    );
  }

  static Future<List<String>>
      loadUnlockedBats()
  async {

    final prefs =
        await SharedPreferences.getInstance();

    final data =
        prefs.getString(
      unlockKey,
    );

    if (data == null) {

      return [
        "WOOD",
      ];
    }

    return List<String>.from(
      jsonDecode(data),
    );
  }

  // SELECTED BAT

  static Future<void>
      saveSelectedBat(
    String bat,
  ) async {

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      selectedBatKey,
      bat,
    );
  }

  static Future<String>
      loadSelectedBat()
  async {

    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getString(
          selectedBatKey,
        ) ??
        "WOOD";
  }

  // RESET

  static Future<void>
      resetAll()
  async {

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.clear();
  }
}
