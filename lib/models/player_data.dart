class PlayerData {

  int coins;
  int xp;
  int level;

  int bestScore;

  String selectedBat;

  List<String> unlockedBats;

  PlayerData({
    required this.coins,
    required this.xp,
    required this.level,
    required this.bestScore,
    required this.selectedBat,
    required this.unlockedBats,
  });
}
