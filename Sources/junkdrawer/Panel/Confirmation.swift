import AppKit

/// A short line near the bottom of the screen that says what an action did,
/// then fades. It never takes focus or clicks.
@MainActor
final class Confirmation {
   private static let bottom: CGFloat = 88
   private static let padding = NSSize(width: 14, height: 8)
   private static let shown: TimeInterval = 2.6

   private let panel: NSPanel
   private let label = NSTextField.line()
   private var fade: Task<Void, Never>?

   init() {
      panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
      panel.level = .floating
      panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .transient]
      panel.ignoresMouseEvents = true
      panel.isOpaque = false
      panel.backgroundColor = .clear
      panel.hasShadow = false
      panel.isReleasedWhenClosed = false
      let box = Box()
      box.addSubview(label)
      panel.contentView = box
   }

   /// Shows `text` centred near the bottom of `screen`, replacing any line
   /// that still shows.
   func show(_ text: String, on screen: NSScreen?) {
      guard let screen = screen ?? NSScreen.main else { return }
      label.attributedStringValue = NSAttributedString(
         string: text, attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.secondary]
      )
      let size = label.drawnSize
      let width = min(size.width + 2 * Self.padding.width, screen.visibleFrame.width - 32)
      let frame = NSRect(
         x: (screen.visibleFrame.midX - width / 2).rounded(), y: screen.visibleFrame.minY + Self.bottom,
         width: width, height: size.height + 2 * Self.padding.height
      )
      panel.setFrame(frame, display: false)
      label.frame = NSRect(x: Self.padding.width, y: Self.padding.height, width: width - 2 * Self.padding.width, height: size.height)

      fade?.cancel()
      panel.alphaValue = panel.isVisible ? panel.alphaValue : 0
      panel.orderFrontRegardless()
      animate(to: 1, over: 0.12)
      fade = Task {
         try? await Task.sleep(for: .seconds(Self.shown))
         guard !Task.isCancelled else { return }
         animate(to: 0, over: 0.2) { [panel] in
            MainActor.assumeIsolated { if panel.alphaValue == 0 { panel.orderOut(nil) } }
         }
      }
   }

   private func animate(to alpha: CGFloat, over duration: TimeInterval, then done: (@Sendable () -> Void)? = nil) {
      NSAnimationContext.runAnimationGroup({ context in
         context.duration = duration
         panel.animator().alphaValue = alpha
      }, completionHandler: done)
   }
}

/// The line's background with a hairline border and rounded corners.
private final class Box: NSView {
   override init(frame: NSRect) {
      super.init(frame: frame)
      wantsLayer = true
      layer?.cornerRadius = 8
      layer?.cornerCurve = .continuous
      layer?.borderWidth = 1
   }

   required init?(coder: NSCoder) {
      fatalError("not used")
   }

   override var wantsUpdateLayer: Bool { true }

   override func updateLayer() {
      layer?.backgroundColor = NSColor.background.cgColor
      layer?.borderColor = NSColor.line.cgColor
   }

   override func viewDidChangeEffectiveAppearance() {
      needsDisplay = true
   }
}
