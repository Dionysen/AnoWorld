import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var allowProgrammaticZoom = false
  private var dragMouseUpMonitor: Any?
  private var windowChannel: FlutterMethodChannel?

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
    // Matches AppTheme.windowMinSize until Flutter updates via the channel.
    self.contentMinSize = NSSize(width: 298, height: 116)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerWindowChannel(flutterViewController)
    registerGeometryObservers()

    super.awakeFromNib()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  override func zoom(_ sender: Any?) {
    allowProgrammaticZoom = true
    super.zoom(sender)
    allowProgrammaticZoom = false
    notifyGeometry()
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
    windowChannel = channel
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
      case "setMinimumSize":
        if let args = call.arguments as? [String: Any] {
          let width = (args["width"] as? NSNumber)?.doubleValue ?? 298
          let height = (args["height"] as? NSNumber)?.doubleValue ?? 116
          self.contentMinSize = NSSize(width: width, height: height)
        }
        result(nil)
      case "getGeometry":
        result(self.currentGeometry())
      case "setGeometry":
        if let args = call.arguments as? [String: Any] {
          self.applyGeometry(args)
        }
        result(nil)
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

  private func registerGeometryObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onGeometryChanged(_:)),
      name: NSWindow.didResizeNotification,
      object: self
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onGeometryChanged(_:)),
      name: NSWindow.didMoveNotification,
      object: self
    )
  }

  @objc private func onGeometryChanged(_ notification: Notification) {
    notifyGeometry()
  }

  private func notifyGeometry() {
    windowChannel?.invokeMethod("geometryChanged", arguments: currentGeometry())
  }

  private func currentGeometry() -> [String: Any] {
    let frame = self.frame
    return [
      "x": frame.origin.x,
      "y": frame.origin.y,
      "width": frame.size.width,
      "height": frame.size.height,
      "maximized": self.isZoomed,
    ]
  }

  private func applyGeometry(_ args: [String: Any]) {
    let x = (args["x"] as? NSNumber)?.doubleValue ?? frame.origin.x
    let y = (args["y"] as? NSNumber)?.doubleValue ?? frame.origin.y
    let width = (args["width"] as? NSNumber)?.doubleValue ?? frame.size.width
    let height = (args["height"] as? NSNumber)?.doubleValue ?? frame.size.height
    let maximized = (args["maximized"] as? NSNumber)?.boolValue ?? false
    if isZoomed {
      allowProgrammaticZoom = true
      super.zoom(nil)
      allowProgrammaticZoom = false
    }
    setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    if maximized != isZoomed {
      zoom(nil)
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
    notifyGeometry()
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
