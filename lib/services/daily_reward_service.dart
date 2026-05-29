import 'package:shared_preferences/shared_preferences.dart';

class DailyRewardService {

  static const key =
      "last_reward";

  static Future<bool>
      canClaimReward() async {

    final prefs =
        await SharedPreferences
            .getInstance();

    final saved =
        prefs.getString(key);

    if(saved == null){
      return true;
    }

    final last =
        DateTime.parse(saved);

    final now =
        DateTime.now();

    return now.difference(last)
        .inHours >= 24;
  }

  static Future<void>
      claimReward() async {

    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setString(
      key,
      DateTime.now().toIso8601String(),
    );
  }
}
