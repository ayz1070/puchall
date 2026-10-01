import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    configureWorkoutTrackingChannels()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureWorkoutTrackingChannels() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }

    let methodChannel = FlutterMethodChannel(
      name: "puchall/workout_tracking",
      binaryMessenger: controller.binaryMessenger
    )
    methodChannel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "startTracking":
        do {
          try WorkoutTrackingManager.shared.start(args: args)
          result(nil)
        } catch WorkoutTrackingManager.StartError.permissionRequired {
          result(FlutterError(
            code: "PERMISSION_REQUIRED",
            message: "Workout permissions are required.",
            details: nil
          ))
        } catch {
          result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
        }
      case "stopTracking":
        result(WorkoutTrackingManager.shared.stop())
      case "resetTracking":
        WorkoutTrackingManager.shared.reset()
        result(nil)
      case "startCalibration":
        WorkoutTrackingManager.shared.startCalibration()
        result(nil)
      case "stopCalibration":
        WorkoutTrackingManager.shared.stopCalibration()
        result(nil)
      case "getTrackingState":
        result(WorkoutTrackingManager.shared.currentStateMap())
      case "consumeCompletedSession":
        result(WorkoutTrackingManager.shared.consumeCompletedSession())
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let eventChannel = FlutterEventChannel(
      name: "puchall/workout_tracking_events",
      binaryMessenger: controller.binaryMessenger
    )
    eventChannel.setStreamHandler(WorkoutTrackingStreamHandler())
  }
}

private final class WorkoutTrackingStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    events(Self.tagged(WorkoutTrackingManager.shared.currentStateMap()))

    WorkoutTrackingManager.shared.onStateChange = { state in
      events(Self.tagged(state))
    }
    // 측정 상태와 캘리브레이션 샘플이 같은 채널을 쓰므로 `type`으로 구분한다.
    WorkoutTrackingManager.shared.onCalibrationSample = { verticalAcceleration, timestampMs in
      events([
        "type": "calibrationSample",
        "verticalAcceleration": verticalAcceleration,
        "timestampMs": timestampMs,
      ])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    WorkoutTrackingManager.shared.onStateChange = nil
    WorkoutTrackingManager.shared.onCalibrationSample = nil
    return nil
  }

  private static func tagged(_ state: [String: Any]) -> [String: Any] {
    var tagged = state
    tagged["type"] = "state"
    return tagged
  }
}
