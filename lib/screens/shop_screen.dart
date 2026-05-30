import 'package:flutter/material.dart';
import '../game_data.dart';

class BatItem {
  final String name;
  final double power;
  final int price;

  BatItem(this.name, this.power, this.price);
}

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final List<BatItem> bats = [
    BatItem("WOOD", 1.0, 0),
    BatItem("STEEL", 1.1, 100),
    BatItem("GOLD", 1.2, 500),
    BatItem("DIAMOND", 1.35, 1000),
  ];

  void handleBatAction(BatItem bat) async {
    bool isBought = GameData.isBatBought(bat.name);

    if (isBought) {
      // ఇప్పటికే కొనేసి ఉంటే దాన్ని ఎక్విప్ (Equip) చేయాలి
      setState(() {
        GameData.equippedBat = bat.name;
      });
    } else {
      // కొనకపోతే ముందు కాయిన్స్ సరిపోతాయో లేదో చెక్ చేయాలి
      int currentCoins = GameData.coins;
      
      if (currentCoins >= bat.price) {
        // కాయిన్స్ సరిపోతే మైనస్ చేసి బ్యాట్ కొనాలి
        setState(() {
          GameData.coins = currentCoins - bat.price; 
          GameData.buyBat(bat.name); 
          GameData.equippedBat = bat.name; 
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${bat.name} BOUGHT SUCCESSFULLY!"),
            backgroundColor: const Color(0xFF306230),
            duration: const Duration(seconds: 1),
          )
        );
      } else {
        // కాయిన్స్ సరిపోకపోతే ఎర్రర్ చూపించాలి
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("NOT ENOUGH COINS!"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "BAT SHOP", 
          style: TextStyle(color: Colors.white, fontFamily: 'monospace')
        ),
      ),
      body: Column(
        children: [
          // టాప్ బార్‌లో రియల్ కాయిన్స్
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            color: const Color(0xFF0F380F),
            child: Text(
              "COINS : ${GameData.coins}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC4E060), 
                fontSize: 20, 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
          const SizedBox(height: 10),
          
          // బ్యాట్స్ లిస్ట్
          Expanded(
            child: ListView.builder(
              itemCount: bats.length,
              itemBuilder: (context, index) {
                final bat = bats[index];
                bool isBought = GameData.isBatBought(bat.name);
                bool isEquipped = GameData.equippedBat == bat.name;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8BAC0F),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF0F380F), width: 3),
                  ),
                  child: Column(
                    children: [
                      Text(
                        bat.name, 
                        style: const TextStyle(color: Color(0xFF0F380F), fontSize: 22, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "POWER x${bat.power}", 
                        style: const TextStyle(color: Color(0xFF306230), fontSize: 14)
                      ),
                      const SizedBox(height: 5),
                      
                      if (!isBought)
                        Text(
                          "${bat.price} Coins", 
                          style: const TextStyle(color: Color(0xFF0F380F), fontSize: 14)
                        ),
                      const SizedBox(height: 10),
                      
                      // బటన్ డిజైన్ మరియు యాక్షన్
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E1E), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                        ),
                        onPressed: () => handleBatAction(bat),
                        child: Text(
                          isEquipped ? "EQUIPPED" : (isBought ? "EQUIP" : "BUY"),
                          style: const TextStyle(color: Color(0xFFC4E060), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
