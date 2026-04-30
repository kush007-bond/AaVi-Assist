package com.visionaid.flutter_app

import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val DEPTH_CHANNEL = "com.visionaid/depth"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEPTH_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasDepthSensor" -> result.success(hasToFSensor())
                    "getDepthReadings" -> result.success(null) // real ToF streaming TBD
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Returns true if any back-facing camera advertises a depth/ToF capability.
     * Covers devices with structured-light or ToF depth sensors (e.g. Samsung S20+,
     * Google Pixel 4, OnePlus 8 Pro, etc.).
     */
    private fun hasToFSensor(): Boolean {
        return try {
            val mgr = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            mgr.cameraIdList.any { id ->
                val chars = mgr.getCameraCharacteristics(id)
                val facing = chars.get(CameraCharacteristics.LENS_FACING)
                val caps = chars.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES) ?: intArrayOf()
                facing == CameraCharacteristics.LENS_FACING_BACK &&
                    caps.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_DEPTH_OUTPUT)
            }
        } catch (e: Exception) {
            false
        }
    }
}
