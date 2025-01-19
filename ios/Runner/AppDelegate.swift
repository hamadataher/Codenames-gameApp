import UIKit
import Flutter
import JitsiMeetSDK

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Ensure background audio continues
    if #available(iOS 10.0, *) {
      AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: .allowBluetooth)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
