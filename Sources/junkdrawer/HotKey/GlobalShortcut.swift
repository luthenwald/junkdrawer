import Foundation
import Observation
import os

/// The hotkey that toggles the panel, kept in step with the settings.
/// When the default ⌘Space is taken, as it is while Spotlight's shortcut
/// is on, it listens for ⌃⇧Space instead.
@MainActor @Observable
final class GlobalShortcut {
   /// The shortcut that toggles the panel now, nil when none could be
   /// registered.
   private(set) var active: Shortcut?
   @ObservationIgnored private let settings: Settings
   @ObservationIgnored private let hotKey: HotKey

   init(settings: Settings, action: @escaping () -> Void) {
      self.settings = settings
      hotKey = HotKey(action: action)
      resume()
   }

   var current: Shortcut { settings.shortcut }

   /// Why the shortcut shown is not the one that works, if it is not.
   var notice: String? {
      switch active {
      case current: nil
      case Shortcut.fallback? where current == .toggle: "Taken, using \(Shortcut.fallback)"
      default: "Already in use"
      }
   }

   /// Releases the shortcut while a new one is recorded, so typing it does
   /// not toggle the panel.
   func pause() {
      hotKey.unregister()
   }

   func resume() {
      if register(settings.shortcut) {
         active = settings.shortcut
      } else if settings.shortcut == .toggle, register(.fallback) {
         active = .fallback
      } else {
         active = nil
      }
      Logger.app.notice("listening for \(self.active?.description ?? "no shortcut", privacy: .public)")
   }

   /// Keeps the old shortcut when the new one cannot be registered, and
   /// says why.
   func change(to shortcut: Shortcut) -> String? {
      guard register(shortcut) else {
         resume()
         return "Already in use"
      }
      settings.shortcut = shortcut
      active = shortcut
      Logger.app.notice("listening for \(shortcut.description, privacy: .public)")
      return nil
   }

   private func register(_ shortcut: Shortcut) -> Bool {
      do {
         try hotKey.register(shortcut)
         return true
      } catch {
         Logger.app.error("registering \(shortcut.description, privacy: .public) failed with status \(error.status, privacy: .public)")
         return false
      }
   }
}
