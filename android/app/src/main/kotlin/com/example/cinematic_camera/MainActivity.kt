package com.example.cinematic_camera

import android.graphics.SurfaceTexture
import android.util.Size
import android.view.Surface
import androidx.annotation.NonNull
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "cinematic_camera/methods"

    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var lensFacing = CameraSelector.LENS_FACING_BACK
    private lateinit var cameraExecutor: ExecutorService

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Dedicated background thread for camera operations
        cameraExecutor = Executors.newSingleThreadExecutor()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initCamera" -> {
                    // Create a texture registry entry that Flutter can render
                    textureEntry = flutterEngine.renderer.createSurfaceTexture()
                    startCamera(result)
                }
                "startRecording" -> {
                    // Implementation for hardware MediaCodec muxing goes here
                    result.success(null)
                }
                "stopRecording" -> {
                    // Stop MediaCodec muxing and save MP4
                    result.success(null)
                }
                "setMode" -> {
                    val mode = call.argument<String>("mode") ?: "PORTRAIT"
                    // Trigger MediaPipe segmentation pipeline activation here
                    result.success(null)
                }
                "switchCamera" -> {
                    lensFacing = if (CameraSelector.LENS_FACING_FRONT == lensFacing) {
                        CameraSelector.LENS_FACING_BACK
                    } else {
                        CameraSelector.LENS_FACING_FRONT
                    }
                    // Restart camera with new lens
                    startCamera(null) 
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startCamera(result: MethodChannel.Result?) {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)

        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()

            // Set up a 1080x1920 (Portrait) preview 
            val preview = Preview.Builder()
                .setTargetResolution(Size(1080, 1920))
                .build()

            // Bind the native Android Surface to the Flutter Texture
            textureEntry?.surfaceTexture?.apply {
                setDefaultBufferSize(1080, 1920)
                val surface = Surface(this)

                preview.setSurfaceProvider { request ->
                    request.provideSurface(surface, cameraExecutor) {
                        // Surface lifecycle handled natively
                    }
                }
            }

            val cameraSelector = CameraSelector.Builder()
                .requireLensFacing(lensFacing)
                .build()

            try {
                cameraProvider?.unbindAll()
                cameraProvider?.bindToLifecycle(
                    this as LifecycleOwner, 
                    cameraSelector, 
                    preview
                )
                // Return the exact Texture ID back to Dart
                result?.success(textureEntry?.id())
            } catch (exc: Exception) {
                result?.error("CAMERA_ERROR", "Hardware bind failed", exc.localizedMessage)
            }

        }, ContextCompat.getMainExecutor(this))
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
    }
}
