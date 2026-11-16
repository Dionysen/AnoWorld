import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var allowProgrammaticZoom = false
  private var dragMouseUpMonitor: Any?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.styleMask.insert(.fullSizeContentView)
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    // Drag and zoom go through the Flutter title band so controls in that
    // strip are not stolen by the system title bar.
    self.isMovable = false
    self.isMovableByWindowBackground = false
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerWindowChannel(flutterViewController)

    super.awakeFromNib()
  }

  override func zoom(_ sender: Any?) {
    allowProgrammaticZoom = true
    super.zoom(sender)
    allowProgrammaticZoom = false
  }

  override func performZoom(_ sender: Any?) {
    guard allowProgrammaticZoom else { return }
    super.performZoom(sender)
  }

  private func registerWindowChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "app/window",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "unavailable",
            message: "Window was released.",
            details: nil
          )
        )
        return
      }
      switch call.method {
      case "immersiveTitleBar":
        result(true)
      case "metrics":
        result(self.chromeMetrics())
      case "startDragging":
        self.beginChromeDrag()
        result(nil)
      case "toggleMaximize":
        self.zoom(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func beginChromeDrag() {
    guard let event = currentEvent else { return }
    isMovable = true
    performDrag(with: event)
    if dragMouseUpMonitor != nil { return }
    dragMouseUpMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseUp]
    ) { [weak self] event in
      self?.endChromeDrag()
      return event
    }
  }

  private func endChromeDrag() {
    if let dragMouseUpMonitor {
      NSEvent.removeMonitor(dragMouseUpMonitor)
      self.dragMouseUpMonitor = nil
    }
    isMovable = false
  }

  /// Distances from the content view so the toolbar lines up with the traffic lights.
  private func chromeMetrics() -> [String: Double] {
    contentView?.layoutSubtreeIfNeeded()
    guard
      let closeButton = standardWindowButton(.closeButton),
      let zoomButton = standardWindowButton(.zoomButton),
      let contentView
    else {
      return ["centerY": 14, "leading": 80]
    }
    let closeInWindow = closeButton.convert(closeButton.bounds, to: nil)
    let zoomInWindow = zoomButton.convert(zoomButton.bounds, to: nil)
    let contentInWindow = contentView.convert(contentView.bounds, to: nil)
    let centerY = contentInWindow.maxY - closeInWindow.midY
    let leading = zoomInWindow.maxX - contentInWindow.minX + 8
    return [
      "centerY": Double(centerY),
      "leading": Double(leading),
    ]
  }
}
