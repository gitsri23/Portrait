import 'package:flutter/material.dart';
import 'camera_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: BokehHomeScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class BokehHomeScreen extends StatefulWidget {
  const BokehHomeScreen({super.key});

  @override
  State<BokehHomeScreen> createState() => _BokehHomeScreenState();
}

class _BokehHomeScreenState extends State<BokehHomeScreen> {
  final BokehCameraService _service = BokehCameraService();
  int? _textureId;
  double _depth = 0.5;
  double _colorBalance = 1.0;
  String _aspectRatio = "9:16";
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initNativePipeline();
  }

  Future<void> _initNativePipeline() async {
    final id = await _service.initializeCamera();
    if (mounted) {
      setState(() => _textureId = id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Texture output directly mapping native camera stream via GPU pointer
          if (_textureId != null)
            Center(
              child: ClipRRect(
                child: AspectRatio(
                  aspectRatio: _aspectRatio == "9:16" ? 9 / 16 : 1 / 1,
                  child: Texture(textureId: _textureId!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          _buildTopMenu(),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildTopMenu() {
    return Positioned(
      top: 60, left: 0, right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white10, width: 1)
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: ["9:16", "1:1"].map((ratio) => GestureDetector(
                onTap: () => setState(() => _aspectRatio = ratio),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: _aspectRatio == ratio ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ratio,
                    style: TextStyle(
                      color: _aspectRatio == ratio ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Colors.black95],
            begin: Alignment.topCenter, end: Alignment.bottomCenter
          )
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSliderSetting("DEPTH INTENSITY", _depth, (val) {
              setState(() => _depth = val);
              _service.updateDepthIntensity(val);
            }),
            const SizedBox(height: 16),
            _buildSliderSetting("COLOR BALANCE", _colorBalance, (val) {
              setState(() => _colorBalance = val);
              _service.updateColorBalance(val);
            }, minVal: 0.5, maxVal: 1.5),
            const SizedBox(height: 32),
            
            // Record Shutter Trigger Button
            GestureDetector(
              onTap: () {
                setState(() => _isRecording = !_isRecording);
                _service.toggleRecording(_isRecording, _aspectRatio);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 80, width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4)
                ),
                padding: EdgeInsets.all(_isRecording ? 22 : 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red : Colors.white,
                    borderRadius: BorderRadius.circular(_isRecording ? 8 : 40)
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSetting(String title, double val, ValueChanged<double> onChange, {double minVal = 0.0, double maxVal = 1.0}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: val, min: minVal, max: maxVal,
                  activeColor: Colors.white, inactiveColor: Colors.white12,
                  onChanged: onChange,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
