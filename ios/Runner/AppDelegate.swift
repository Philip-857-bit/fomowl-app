import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let receiptFilesChannelName = "owllet/receipt_files"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: receiptFilesChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "saveReceiptImage", "shareReceiptImage":
          self?.shareReceiptImage(arguments: call.arguments, result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func receiptImage(arguments: Any?) -> (String, URL, String)? {
    guard let args = arguments as? [String: Any],
          let dataUrl = args["dataUrl"] as? String,
          let markerRange = dataUrl.range(of: "base64,") else {
      return nil
    }
    let encoded = String(dataUrl[markerRange.upperBound...])
    guard dataUrl.hasPrefix("data:image/png"),
          let data = Data(base64Encoded: encoded) else {
      return nil
    }
    let rawName: String
    if let suppliedName = args["filename"] as? String, !suppliedName.isEmpty {
      rawName = suppliedName
    } else {
      rawName = "owllet-receipt"
    }
    let safeName = rawName
      .replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "-", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    let baseName = safeName.isEmpty ? "owllet-receipt" : safeName
    let filename = baseName.hasSuffix(".png") ? baseName : "\(baseName).png"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    do {
      try data.write(to: url, options: .atomic)
    } catch {
      return nil
    }
    let text = args["text"] as? String ?? ""
    return (filename, url, text)
  }

  private func shareReceiptImage(arguments: Any?, result: @escaping FlutterResult) {
    guard let (_, url, text) = receiptImage(arguments: arguments) else {
      result(["ok": false, "error": "Invalid receipt image."])
      return
    }
    var items: [Any] = [url]
    if !text.isEmpty {
      items.append(text)
    }
    DispatchQueue.main.async {
      guard let root = self.window?.rootViewController else {
        result(["ok": false, "error": "Unable to open share sheet."])
        return
      }
      let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
      if let popover = controller.popoverPresentationController {
        popover.sourceView = root.view
        popover.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
        popover.permittedArrowDirections = []
      }
      root.present(controller, animated: true)
      result(["ok": true])
    }
  }
}
