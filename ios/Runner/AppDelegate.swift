import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "app.havenlife.haven/reminders",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "schedule", let arguments = call.arguments as? [String: Any],
        let tasks = arguments["tasks"] as? [[String: Any]] else {
          result(FlutterMethodNotImplemented)
          return
      }
      let center = UNUserNotificationCenter.current()
      if arguments["permission"] as? Bool == true {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in
          self.schedule(tasks, center: center, result: result)
        }
      } else {
        self.schedule(tasks, center: center, result: result)
      }
    }
  }

  private func schedule(
    _ tasks: [[String: Any]], center: UNUserNotificationCenter, result: @escaping FlutterResult
  ) {
    let calendar = Calendar.current
    let now = Date()
    var requests: [(Date, UNNotificationRequest)] = []
    for task in tasks {
      guard let id = task["id"] as? String, let title = task["title"] as? String,
            let epoch = task["at"] as? NSNumber, let repeatDays = task["repeat"] as? Int else { continue }
      let first = Date(timeIntervalSince1970: epoch.doubleValue / 1000)
      let directRepeat = repeatDays == 1 || repeatDays == 7
      let offsets = directRepeat || repeatDays == 0 ? 0..<1 : 0..<8
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = "Haven task reminder"
      content.sound = .default
      for index in offsets {
        guard let at = calendar.date(byAdding: .day, value: repeatDays * index, to: first), at > now else { continue }
        let components: Set<Calendar.Component>
        if repeatDays == 1 {
          components = [.hour, .minute]
        } else if repeatDays == 7 {
          components = [.weekday, .hour, .minute]
        } else {
          components = [.year, .month, .day, .hour, .minute]
        }
        let trigger = UNCalendarNotificationTrigger(
          dateMatching: calendar.dateComponents(components, from: at), repeats: directRepeat
        )
        // A repeating trigger could fire for today's already completed task.
        let safeRepeat = directRepeat && abs((trigger.nextTriggerDate() ?? at).timeIntervalSince(at)) < 60
        let request = UNNotificationRequest(
          identifier: "haven-reminder-\(id)-\(index)", content: content,
          trigger: safeRepeat ? trigger : UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: at),
            repeats: false
          )
        )
        requests.append((at, request))
      }
    }
    let ordered = requests.sorted { $0.0 < $1.0 }.prefix(50)
    center.removeAllPendingNotificationRequests()
    for (_, request) in ordered {
      center.add(request)
    }
    DispatchQueue.main.async { result(nil) }
  }
}
