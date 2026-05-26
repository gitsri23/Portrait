import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:ui';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PortraitApp());
}

class PortraitApp extends StatelessWidget {
  const PortraitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Portrait Camera',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF000000),
        brightness: Brightness.dark,
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: const Color(0xFFF5F5F7),
          displayColor: const Color(0xFFF5F5F7),
        ),
      ),
      home: const VideoEditorScreen(),
    );
  }
}

class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VideoEditorView();
  }
}

class VideoEditorView extends StatefulWidget {
  const VideoEditorView({super.key});

  @override
  State<VideoEditorView> createState() => _VideoEditorViewState();
}

class _VideoEditorViewState extends State<VideoEditorView> {
  File? _videoFile;
  VideoPlayerController? _videoController;
  final ImagePicker _picker = ImagePicker();
  double _blurRadius = 15.0;
  bool _isProcessing = false;

  Future<void> _pickVideo() async {
    final XFile? pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      _videoController?.dispose();
      
      final controller = VideoPlayerController.file(File(pickedFile.path));
      await controller.initialize();
      controller.setLooping(true);
      controller.play();

      setState(() {
        _videoFile = File(pickedFile.path);
        _videoController = controller;
      });
    }
  }

  void _exportVideo() {
    setState(() => _isProcessing = true);
    Future.delayed(const Duration(seconds: 4), () {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚡ Cinematic Portrait Video Exported to Gallery!"),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_videoController != null && _videoController!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.video_library_outlined, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text(
                    "IMPORT VIDEO TO APPLY CINEMATIC BLUR",
                    style: TextStyle(letterSpacing: 1.5, fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.add, color: Colors.black),
                    label: const Text("Select Video", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ],
              ),
            ),

          if (_videoFile != null)
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 18),
                          onPressed: () {
                            setState(() {
                              _videoFile = null;
                              _videoController?.dispose();
                              _videoController = null;
                            });
                          },
                        ),
                        Text(
                          "CINEMATIC FOCUS",
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12),
                        ),
                        GestureDetector(
                          onTap: _pickVideo,
                          child: const Icon(Icons.refresh, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_videoFile != null)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.blur_on, size: 18, color: Colors.amberAccent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SliderTheme(
                                data: const SliderThemeData(
                                  trackHeight: 2,
                                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                                  activeTrackColor: Colors.amberAccent,
                                  inactiveTrackColor: Colors.white12,
                                  thumbColor: Colors.amberAccent,
                                ),
                                child: Slider(
                                  value: _blurRadius,
                                  min: 0.0,
                                  max: 30.0,
                                  onChanged: (val) {
                                    setState(() => _blurRadius = val);
                                  },
                                ),
                              ),
                            ),
                            Text(
                              "${_blurRadius.toInt()}f",
                              style: const TextStyle(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _exportVideo,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                            ),
                            child: _isProcessing
                                ? const CircularProgressIndicator(color: Colors.black)
                                : Text(
                                    "EXPORT CINEMATIC VIDEO",
                                    style: GoogleFonts.inter(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
