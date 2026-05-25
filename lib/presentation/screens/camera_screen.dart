import 'package:flutter/material.dart';
import '../../core/platform_bridge.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/glass_bottom_bar.dart';
import '../widgets/mode_selector.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  int? _textureId;
  String _currentMode = 'PORTRAIT';
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initNativeCamera();
  }

  Future<void> _initNativeCamera() async {
    final textureId = await NativeCameraBridge.initializeCamera();
    if (mounted) {
      setState(() => _textureId = textureId);
    }
  }

  void _toggleRecording() {
    setState(() => _isRecording = !_isRecording);
    if (_isRecording) {
      NativeCameraBridge.startRecording();
    } else {
      NativeCameraBridge.stopRecording();
    }
  }

  void _onModeChanged(String mode) {
    setState(() => _currentMode = mode);
    NativeCameraBridge.setMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Native Viewfinder
          if (_textureId != null)
            Texture(textureId: _textureId!)
          else
            const Center(
              child: Text(
                "INITIALIZING ENGINE...",
                style: TextStyle(letterSpacing: 2, fontSize: 12, color: Colors.white54),
              ),
            ),

          // Safe Area Overlays
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const GlassAppBar(),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ModeSelector(
                      currentMode: _currentMode,
                      onModeChanged: _onModeChanged,
                    ),
                    const SizedBox(height: 24),
                    GlassBottomBar(
                      isRecording: _isRecording,
                      onRecordPressed: _toggleRecording,
                      onSwitchCamera: NativeCameraBridge.switchCamera,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
