import 'package:flutter/material.dart';

import '../services/save_service.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() =>
      _ShopScreenState();
}

class _ShopScreenState
    extends State<ShopScreen> {

  int coins = 0;

  String selectedBat = "WOOD";

  List<String> unlocked = [];

  final bats = [

    {
      "name":"WOOD",
      "price":0,
      "power":1.0,
    },

    {
      "name":"STEEL",
      "price":100,
      "power":1.1,
    },

    {
      "name":"GOLD",
      "price":500,
      "power":1.2,
    },

    {
      "name":"DIAMOND",
      "price":1000,
      "power":1.35,
    },

    {
      "name":"LEGEND",
      "price":2500,
      "power":1.5,
    },
  ];

  @override
  void initState() {
    super.initState();

    loadData();
  }

  Future<void> loadData() async {

    coins =
        await SaveService.loadCoins();

    selectedBat =
        await SaveService.loadSelectedBat();

    unlocked =
        await SaveService
            .loadUnlockedBats();

    setState(() {});
  }

  Future<void> buyBat(
    String bat,
    int price,
  ) async {

    if (coins < price) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text("Not enough coins"),
        ),
      );

      return;
    }

    coins -= price;

    unlocked.add(bat);

    await SaveService.saveCoins(
      coins,
    );

    await SaveService
        .saveUnlockedBats(
      unlocked,
    );

    setState(() {});
  }

  Future<void> equipBat(
    String bat,
  ) async {

    selectedBat = bat;

    await SaveService
        .saveSelectedBat(
      bat,
    );

    setState(() {});
  }

  Widget buildBatCard(
    Map bat,
  ) {

    final name =
        bat["name"] as String;

    final price =
        bat["price"] as int;

    final power =
        bat["power"];

    final owned =
        unlocked.contains(name);

    final equipped =
        selectedBat == name;

    return Container(

      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),

      padding:
          const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color:
            const Color(0xFF8BAC0F),
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color:
              const Color(0xFF0F380F),
          width: 3,
        ),
      ),

      child: Column(
        children: [

          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
              color:
                  Color(0xFF0F380F),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            "POWER x$power",
            style: const TextStyle(
              color:
                  Color(0xFF306230),
            ),
          ),

          const SizedBox(height: 8),

          if (!owned)
            Text(
              "$price Coins",
              style: const TextStyle(
                color:
                    Color(0xFF0F380F),
              ),
            ),

          const SizedBox(height: 10),

          if (!owned)

            ElevatedButton(
              onPressed: () =>
                  buyBat(
                name,
                price,
              ),
              child:
                  const Text("BUY"),
            )

          else if (!equipped)

            ElevatedButton(
              onPressed: () =>
                  equipBat(
                name,
              ),
              child:
                  const Text("EQUIP"),
            )

          else

            const Chip(
              label:
                  Text("EQUIPPED"),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {

    return Scaffold(

      backgroundColor:
          Colors.black,

      appBar: AppBar(
        title:
            const Text("BAT SHOP"),
      ),

      body: Column(
        children: [

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(16),
            color:
                const Color(0xFF0F380F),

            child: Text(
              "COINS : $coins",
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Color(0xFFC4E060),
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(

              padding:
                  const EdgeInsets.all(
                12,
              ),

              itemCount:
                  bats.length,

              itemBuilder:
                  (context,index) {

                return buildBatCard(
                  bats[index],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
