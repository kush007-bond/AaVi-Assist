import Flutter
import UIKit
import ARKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  private var depthChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    depthChannel = FlutterMethodChannel(
      name: "com.visionaid/depth",
      binaryMessenger: controller.binaryMessenger
    )

    depthChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "hasDepthSensor":
        // LiDAR is available on iPhone 12 Pro+, iPad Pro 2020+
        if #available(iOS 14.0, *) {
          result(ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh))
        } else {
          result(false)
        }

      case "getDepthReadings":
        // Return a single forward-facing depth estimate.
        // For a real integration use ARSession + ARDepthData.
        // Here we return nil so the server uses camera-only.
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
