import ApplicationServices
import os

/// Accessibility access, which posting key events needs: inserting
/// symbols and locking the screen.
@MainActor
enum Accessibility {
   private static var asked = false

   /// Shows the system prompt the first time in a launch that access is
   /// missing; later calls only check.
   static func isTrusted() -> Bool {
      if AXIsProcessTrusted() { return true }
      if !asked {
         asked = true
         // The value of kAXTrustedCheckOptionPrompt, a global var Swift 6
         // does not allow from here.
         _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
         Logger.app.notice("asked for Accessibility access")
      }
      return false
   }
}
