import Flutter
import UIKit

import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    GeneratedPluginRegistrant.register(with: self)
    
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let timezoneChannel = FlutterMethodChannel(name: "com.aplicraft.decideat/timezone",
                                                 binaryMessenger: controller.binaryMessenger)
    
    timezoneChannel.setMethodCallHandler { call, result in
      if call.method == "getTimeZone" {
        let timeZoneName = TimeZone.current.identifier // e.g., "Europe/Warsaw"
        result(timeZoneName)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
