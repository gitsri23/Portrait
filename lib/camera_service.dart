import 'package:flutter/services.dart';

class BokehCameraService {
  static const _channel = MethodChannel('blur.bokeh.and/camera');

  Future<int?> initializeCamera() async {
    try {
      final int? textureId = await _channel.invokeMethod('initializeCamera');
      return textureId;
    } on PlatformException catch (e) {
      print("Failed to boot native camera: ${e.message}");
      return null;
    }
  }

  Future<void> updateDepthIntensity(double intensity) async {
    await _channel.invokeMethod('updateDepth', {'intensity': intensity});
  }

  Future<void> updateColorBalance(double balance) async {
    await _channel.invokeMethod('updateColor', {'balance': balance});
  }

  Future<void> toggleRecording(bool start, String ratio) async {
    await _channel.invokeMethod('toggleRecord', {'start': start, 'ratio': ratio});
  }
}
