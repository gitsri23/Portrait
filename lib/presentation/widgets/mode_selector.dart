import 'package:flutter/material.dart';

class ModeSelector extends StatelessWidget {
  final String currentMode;
  final Function(String) onModeChanged;

  const ModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildModeButton('VIDEO'),
        const SizedBox(width: 32),
        _buildModeButton('PORTRAIT'),
      ],
    );
  }

  Widget _buildModeButton(String mode) {
    final isSelected = currentMode == mode;
    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: Text(
        mode,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          letterSpacing: 1.2,
          color: isSelected ? Colors.amberAccent : Colors.white54,
        ),
      ),
    );
  }
}
