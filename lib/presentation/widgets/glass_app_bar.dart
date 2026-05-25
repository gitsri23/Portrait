import 'package:flutter/material.dart';
import 'dart:ui';

class GlassAppBar extends StatelessWidget {
  const GlassAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            color: Colors.black.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Icon(Icons.flash_off, size: 20),
                Text(
                  "4K • 60",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    fontSize: 14,
                  ),
                ),
                Icon(Icons.settings_outlined, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
