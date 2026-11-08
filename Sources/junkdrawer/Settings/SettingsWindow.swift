import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A standard window with the settings. The app has no menu, so the window
/// closes on ⌘W itself, and closing it hands the focus back to the app
/// that was in front.
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
   private let window: Window
   private let loginItem: LoginItem

   init(settings: Settings, loginItem: LoginItem, shortcut: GlobalShortcut) {
      self.loginItem = loginItem
      let hosting = NSHostingController(rootView: SettingsView(settings: settings, loginItem: loginItem, shortcut: shortcut))
      hosting.sizingOptions = .preferredContentSize
      window = Window(contentViewController: hosting)
      window.title = "Junkdrawer Settings"
      window.styleMask = [.titled, .closable]
      window.isReleasedWhenClosed = false
      window.center()
      super.init()
      window.delegate = self
   }

   var isVisible: Bool { window.isVisible }

   func show() {
      loginItem.refresh()
      NSApp.activate()
      window.makeKeyAndOrderFront(nil)
   }

   func windowWillClose(_ notification: Notification) {
      NSApp.hide(nil)
   }

   private final class Window: NSWindow {
      override func performKeyEquivalent(with event: NSEvent) -> Bool {
         let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
         if modifiers == .command, Int(event.keyCode) == kVK_ANSI_W {
            performClose(nil)
            return true
         }
         return super.performKeyEquivalent(with: event)
      }
   }
}
