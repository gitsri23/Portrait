import 'package:flutter/material.dart';
import 'shutter_button.dart';

class GlassBottomBar extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onRecordPressed;
  final VoidCallback onSwitchCamera;

  const GlassBottomBar({
    super.key,
    required this.isRecording,
    required this.onRecordPressed,
    required this.onSwitchCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Gallery Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 1),
            ),
            child: const Icon(Icons.photo_library_outlined, size: 22),
          ),
          
          // Center Shutter
          ShutterButton(
            isRecording: isRecording,
            onPressed: onRecordPressed,
          ),
          
          // Switch Camera
          GestureDetector(
            onTap: onSwitchCamera,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flip_camera_ios_outlined, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
