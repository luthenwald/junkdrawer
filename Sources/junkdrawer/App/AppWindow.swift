import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A standard window of the app, such as the settings or the statistics.
/// The app has no menu, so the window closes on ⌘W and quits the app on ⌘Q
/// itself, and closing the last one hands the focus back to the app that
/// was in front.
///
/// Showing it where the user is takes a new window: a tiling window manager
/// such as AeroSpace keeps every workspace on one Space and parks the
/// windows of the others in a screen corner, so bringing the old window to
/// the front would leave it there. A new window joins the focused workspace.
@MainActor
final class AppWindow: NSObject, NSWindowDelegate {
   private let title: String
   private let willShow: () -> Void
   private let content: () -> AnyView
   private var window: Window?

   /// `willShow` runs before each show, for state the content reads once.
   init(title: String, willShow: @escaping () -> Void = {}, content: @escaping () -> some View) {
      self.title = title
      self.willShow = willShow
      self.content = { AnyView(content()) }
      super.init()
   }

   func show() {
      willShow()
      if let window, window.isVisible, window.isOnActiveSpace, Self.isMostlyOnScreen(window.frame) {
         NSApp.activate()
         window.makeKeyAndOrderFront(nil)
         return
      }
      // The old window goes before the app activates: AeroSpace follows the
      // focus to the app's window, and would switch to the old window's
      // workspace and open the new one there.
      retire()
      let window = makeWindow()
      self.window = window
      NSApp.activate()
      window.makeKeyAndOrderFront(nil)
   }

   /// Hides the app, unless another of its windows still shows.
   func windowWillClose(_ notification: Notification) {
      let closing = notification.object as? NSWindow
      guard !NSApp.windows.contains(where: { $0 !== closing && $0.isVisible && $0.canBecomeMain }) else { return }
      NSApp.hide(nil)
   }

   private func makeWindow() -> Window {
      let hosting = NSHostingController(rootView: content())
      hosting.sizingOptions = .preferredContentSize
      let window = Window(contentViewController: hosting)
      window.title = title
      window.styleMask = [.titled, .closable]
      window.isReleasedWhenClosed = false
      // The content's size, so the window centres at its real size.
      window.setContentSize(hosting.view.fittingSize)
      window.center()
      window.delegate = self
      return window
   }

   /// Closes the old window without hiding the app, which `windowWillClose`
   /// would do.
   private func retire() {
      guard let window else { return }
      window.delegate = nil
      window.orderOut(nil)
      window.close()
      self.window = nil
   }

   /// Whether at least half of the frame lies on one screen, which a window
   /// parked in a corner by a window manager does not.
   private static func isMostlyOnScreen(_ frame: NSRect) -> Bool {
      let area = frame.width * frame.height
      return NSScreen.screens.contains { screen in
         let overlap = screen.frame.intersection(frame)
         return overlap.width * overlap.height >= area / 2
      }
   }

   private final class Window: NSWindow {
      override func performKeyEquivalent(with event: NSEvent) -> Bool {
         let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
         guard modifiers == .command else { return super.performKeyEquivalent(with: event) }
         switch Int(event.keyCode) {
         case kVK_ANSI_W: performClose(nil)
         case kVK_ANSI_Q: NSApp.terminate(nil)
         default: return super.performKeyEquivalent(with: event)
         }
         return true
      }
   }
}
