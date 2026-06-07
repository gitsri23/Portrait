package blur.bokeh.and

import android.content.Context
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.media.MediaRecorder
import android.os.Environment
import android.view.Surface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "blur.bokeh.and/camera"
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var previewRequestBuilder: CaptureRequest.Builder? = null
    private var mediaRecorder: MediaRecorder? = null
    private var isRecording = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeCamera" -> {
                    textureEntry = flutterEngine.renderer.createSurfaceTexture()
                    val surfaceTexture = textureEntry?.surfaceTexture()
                    val textureId = textureEntry?.id()

                    if (surfaceTexture != null && textureId != null) {
                        surfaceTexture.setDefaultBufferSize(1920, 1080)
                        openNativeCamera(surfaceTexture)
                        result.success(textureId)
                    } else {
                        result.error("UNAVAILABLE", "GPU Texture allocation tracking failed.", null)
                    }
                }
                "updateDepth" -> {
                    val intensity = call.argument<Double>("intensity")?.toFloat() ?: 0.5f
                    // Update OpenGL Fragment Uniform Depth radius modifier here
                    result.success(null)
                }
                "updateColor" -> {
                    val balance = call.argument<Double>("balance")?.toFloat() ?: 1.0f
                    // Update OpenGL pipeline color processing matrix transformation parameters here
                    result.success(null)
                }
                "toggleRecord" -> {
                    val start = call.argument<Boolean>("start") ?: false
                    val ratio = call.argument<String>("ratio") ?: "9:16"
                    if (start) startRecordingPipeline(ratio) else stopAndExportPipeline()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openNativeCamera(surfaceTexture: SurfaceTexture) {
        val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        try {
            val cameraId = manager.cameraIdList[0] // Primary Rear Sensor Lookups
            manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    val surface = Surface(surfaceTexture)
                    createCameraPreviewSession(surface)
                }
                override fun onDisconnected(camera: CameraDevice) { camera.close() }
                override fun onError(camera: CameraDevice, error: Int) { camera.close() }
            }, null)
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    private fun createCameraPreviewSession(surface: Surface) {
        previewRequestBuilder = cameraDevice?.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
        previewRequestBuilder?.addTarget(surface)

        // Noise Mitigation Engineering configurations
        previewRequestBuilder?.set(CaptureRequest.NOISE_REDUCTION_MODE, CaptureRequest.NOISE_REDUCTION_MODE_HIGH_QUALITY)
        previewRequestBuilder?.set(CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE, CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE_ON)
        previewRequestBuilder?.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_AUTO)

        cameraDevice?.createCaptureSession(listOf(surface), object : CameraCaptureSession.StateCallback() {
            override fun onConfigured(session: CameraCaptureSession) {
                captureSession = session
                previewRequestBuilder?.build()?.let { captureSession?.setRepeatingRequest(it, null, null) }
            }
            override fun onConfigureFailed(session: CameraCaptureSession) {}
        }, null)
    }

    private fun startRecordingPipeline(ratio: String) {
        val movieFolder = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM)
        val file = File(movieFolder, "BOKEH_${System.currentTimeMillis()}.mp4")
        
        mediaRecorder = MediaRecorder(this).apply {
            setVideoSource(MediaRecorder.VideoSource.SURFACE)
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setOutputFile(file.absolutePath)
            setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setVideoSize(1920, 1080)
            setVideoEncodingBitRate(24000000) // Ultra crisp high-profile profile matrix output 
            setVideoFrameRate(30)
            prepare()
            start()
        }
        isRecording = true
    }

    private fun stopAndExportPipeline() {
        if (isRecording) {
            mediaRecorder?.apply {
                stop()
                reset()
                release()
            }
            mediaRecorder = null
            isRecording = false
        }
    }
}
