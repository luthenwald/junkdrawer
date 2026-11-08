import Foundation
import Observation
import os
import ServiceManagement

/// The app as a login item. The state is read from the system rather than
/// stored, so it reflects changes made in System Settings.
@MainActor @Observable
final class LoginItem {
   private static let registeredKey = "DidRegisterLoginItem"

   private(set) var isEnabled = false

   init() {
      refresh()
   }

   func refresh() {
      isEnabled = SMAppService.mainApp.status == .enabled
   }

   func set(_ enabled: Bool) {
      do {
         if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
      } catch {
         Logger.app.error("changing the login item failed: \(String(describing: error), privacy: .public)")
      }
      // The user turned it off in System Settings before and has to allow it there.
      if enabled, SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
      refresh()
   }

   /// Adds the app once, on its first launch from an Applications folder,
   /// so a development build elsewhere does not become the login item.
   func registerOnFirstLaunch() {
      let defaults = UserDefaults.standard
      guard !defaults.bool(forKey: Self.registeredKey),
            Bundle.main.bundleURL.deletingLastPathComponent().lastPathComponent == "Applications" else { return }
      set(true)
      defaults.set(true, forKey: Self.registeredKey)
   }
}
