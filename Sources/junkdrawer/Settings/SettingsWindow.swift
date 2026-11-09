import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A standard window with the settings. The app has no menu, so the window
/// closes on ⌘W and quits the app on ⌘Q itself, and closing it hands the focus back to the app
/// that was in front.
///
/// Showing it where the user is takes a new window: a tiling window manager
/// such as AeroSpace keeps every workspace on one Space and parks the
/// windows of the others in a screen corner, so bringing the old window to
/// the front would leave it there. A new window joins the focused workspace.
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
   private let settings: Settings
   private let loginItem: LoginItem
   private let shortcut: GlobalShortcut
   private var window: Window?

   init(settings: Settings, loginItem: LoginItem, shortcut: GlobalShortcut) {
      self.settings = settings
      self.loginItem = loginItem
      self.shortcut = shortcut
      super.init()
   }

   var isVisible: Bool { window?.isVisible ?? false }

   func show() {
      loginItem.refresh()
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

   func windowWillClose(_ notification: Notification) {
      NSApp.hide(nil)
   }

   private func makeWindow() -> Window {
      let hosting = NSHostingController(rootView: SettingsView(settings: settings, loginItem: loginItem, shortcut: shortcut))
      hosting.sizingOptions = .preferredContentSize
      let window = Window(contentViewController: hosting)
      window.title = "Junkdrawer Settings"
      window.styleMask = [.titled, .closable]
      window.isReleasedWhenClosed = false
      // The form's size, so the window centres at its real size.
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
