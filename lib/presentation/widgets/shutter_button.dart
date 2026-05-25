import 'package:flutter/material.dart';

class ShutterButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onPressed;

  const ShutterButton({
    super.key,
    required this.isRecording,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isRecording ? Colors.redAccent.withOpacity(0.5) : Colors.white,
            width: 4,
          ),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: isRecording ? 32 : 66,
            height: isRecording ? 32 : 66,
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: isRecording ? BorderRadius.circular(8) : BorderRadius.circular(33),
            ),
          ),
        ),
      ),
    );
  }
}
