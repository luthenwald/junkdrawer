import AppKit

/// Shows and hides the panel. It opens empty on the screen under the
/// pointer and hides on Esc, on focus loss and on the hotkey.
@MainActor
final class PanelController: NSObject, NSWindowDelegate, NSTextFieldDelegate {
   /// Where the panel's top edge sits, as a share of the visible height
   /// measured from the top.
   private static let topOffset: CGFloat = 0.22

   private let panel = LauncherPanel()

   override init() {
      super.init()
      panel.delegate = self
      panel.query.delegate = self
      panel.onCancel = { [unowned self] in hide() }
   }

   func toggle() {
      if panel.isVisible { hide() } else { show() }
   }

   /// Without activating the app, so an insert later lands in the app that
   /// was in front, and hiding needs no focus hand-back.
   func show() {
      place()
      panel.makeKeyAndOrderFront(nil)
      panel.makeFirstResponder(panel.query)
      panel.invalidateShadow()
   }

   func hide() {
      guard panel.isVisible else { return }
      panel.orderOut(nil)
      panel.query.stringValue = ""
      // Reopening from Finder activates the app; hiding it hands focus back.
      if NSApp.isActive { NSApp.hide(nil) }
   }

   func windowDidResignKey(_ notification: Notification) {
      hide()
   }

   /// Esc clears the query, and on an empty query hides the panel. The field
   /// editor would otherwise take it for completion.
   func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
      guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
      if panel.query.stringValue.isEmpty { hide() } else { panel.query.stringValue = "" }
      return true
   }

   /// Centred on the screen under the pointer, near the top.
   private func place() {
      let mouse = NSEvent.mouseLocation
      guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
      let visible = screen.visibleFrame
      let size = panel.frame.size
      let top = visible.maxY - Self.topOffset * visible.height
      panel.setFrameOrigin(NSPoint(x: (visible.midX - size.width / 2).rounded(), y: (top - size.height).rounded()))
   }
}
