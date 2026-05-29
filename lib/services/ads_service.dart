import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {

  static Future<void> init() async {
    await MobileAds.instance.initialize();
  }

  static BannerAd createBanner() {

    return BannerAd(
      size: AdSize.banner,

      adUnitId:
          BannerAd.testAdUnitId,

      listener:
          BannerAdListener(),

      request:
          const AdRequest(),
    )..load();
  }

  static InterstitialAd?
      interstitial;

  static Future<void>
      loadInterstitial() async {

    await InterstitialAd.load(
      adUnitId:
          InterstitialAd.testAdUnitId,

      request:
          const AdRequest(),

      adLoadCallback:
          InterstitialAdLoadCallback(

        onAdLoaded: (ad) {

          interstitial = ad;
        },

        onAdFailedToLoad: (_) {},
      ),
    );
  }

  static void showInterstitial() {

    interstitial?.show();

    interstitial = null;
  }

  static RewardedAd?
      rewarded;

  static Future<void>
      loadRewarded() async {

    await RewardedAd.load(
      adUnitId:
          RewardedAd.testAdUnitId,

      request:
          const AdRequest(),

      rewardedAdLoadCallback:
          RewardedAdLoadCallback(

        onAdLoaded: (ad) {

          rewarded = ad;
        },

        onAdFailedToLoad: (_) {},
      ),
    );
  }

  static void showRewarded(
    Function reward,
  ) {

    rewarded?.show(
      onUserEarnedReward:
          (_, __) {

        reward();
      },
    );
  }
}
