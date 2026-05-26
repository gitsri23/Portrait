import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const PortraitBlurApp());
}

class PortraitBlurApp extends StatelessWidget {
  const PortraitBlurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? selectedVideo;
  VideoPlayerController? controller;

  bool processing = false;

  Future<void> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result == null) return;

    selectedVideo = File(result.files.single.path!);

    controller = VideoPlayerController.file(selectedVideo!)
      ..initialize().then((_) {
        setState(() {});
        controller!.play();
      });
  }

  Future<void> blurBackground() async {
    if (selectedVideo == null) return;

    setState(() {
      processing = true;
    });

    final dir = await getTemporaryDirectory();

    final output =
        "${dir.path}/portrait_${DateTime.now().millisecondsSinceEpoch}.mp4";

    /// TEMP cinematic blur simulation
    /// REAL AI segmentation next step
    final command = """
    -i ${selectedVideo!.path}
    -vf "boxblur=10:1"
    -preset ultrafast
    $output
    """;

    await FFmpegKit.execute(command);

    setState(() {
      processing = false;
    });

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          videoPath: output,
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Portrait Blur"),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: selectedVideo == null
                  ? const Text(
                      "Select Video",
                      style: TextStyle(fontSize: 20),
                    )
                  : controller != null &&
                          controller!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio:
                              controller!.value.aspectRatio,
                          child: VideoPlayer(controller!),
                        )
                      : const CircularProgressIndicator(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: pickVideo,
                  child: const Text("Upload Video"),
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed:
                      processing ? null : blurBackground,
                  child: processing
                      ? const CircularProgressIndicator()
                      : const Text("Create Portrait Blur"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResultScreen extends StatefulWidget {
  final String videoPath;

  const ResultScreen({
    super.key,
    required this.videoPath,
  });

  @override
  State<ResultScreen> createState() =>
      _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();

    controller =
        VideoPlayerController.file(File(widget.videoPath))
          ..initialize().then((_) {
            setState(() {});
            controller.play();
          });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Result"),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: controller.value.isInitialized
            ? AspectRatio(
                aspectRatio:
                    controller.value.aspectRatio,
                child: VideoPlayer(controller),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
