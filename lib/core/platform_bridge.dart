import 'package:flutter/services.dart';

class NativeCameraBridge {
  static const MethodChannel _channel = MethodChannel('cinematic_camera/methods');

  static Future<int?> initializeCamera() async {
    try {
      final int? textureId = await _channel.invokeMethod('initCamera');
      return textureId;
    } on PlatformException catch (e) {
      debugPrint("Failed to initialize camera: '${e.message}'.");
      return null;
    }
  }

  static Future<void> startRecording() async {
    await _channel.invokeMethod('startRecording');
  }

  static Future<void> stopRecording() async {
    await _channel.invokeMethod('stopRecording');
  }

  static Future<void> setMode(String mode) async {
    await _channel.invokeMethod('setMode', {'mode': mode});
  }

  static Future<void> switchCamera() async {
    await _channel.invokeMethod('switchCamera');
  }
}
