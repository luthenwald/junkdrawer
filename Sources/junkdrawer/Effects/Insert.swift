import AppKit
import ApplicationServices
import Carbon.HIToolbox
import JunkdrawerCore
import os

/// Types a string into the frontmost app. Posting events needs
/// Accessibility access, which is asked for on the first insert; until it
/// is granted, and while a password field has focus, the string is copied.
@MainActor
final class Inserter {
   /// Apps that ignore typed Unicode events and get a paste instead, by
   /// bundle identifier.
   static let pasteApps: Set<String> = []
   /// Events carry at most 20 UTF-16 units each.
   private static let chunkLength = 20
   /// Time for focus to go back to the app in front after the panel hid.
   private static let delay = 0.05
   /// How long a paste may take before the old pasteboard comes back.
   private static let restoreDelay = 0.5

   private var askedForAccess = false

   func insert(_ string: String) -> Outcome {
      if IsSecureEventInputEnabled() {
         copy(string)
         return .copiedSecureInput
      }
      guard isTrusted() else {
         copy(string)
         return .copiedNoAccess
      }
      let usePaste = NSWorkspace.shared.frontmostApplication?.bundleIdentifier.map(Self.pasteApps.contains) ?? false
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.delay) { [self] in
         if usePaste { paste(string) } else { type(string) }
      }
      return .done
   }

   /// Shows the system prompt on the first insert of a launch without
   /// access; later inserts only check.
   private func isTrusted() -> Bool {
      if AXIsProcessTrusted() { return true }
      if !askedForAccess {
         askedForAccess = true
         // The value of kAXTrustedCheckOptionPrompt, a global var Swift 6
         // does not allow from here.
         _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
         Logger.app.notice("asked for Accessibility access")
      }
      return false
   }

   /// A key-down and key-up per chunk of whole characters, with no
   /// modifiers, so a held key does not turn the text into shortcuts.
   private func type(_ string: String) {
      let source = CGEventSource(stateID: .hidSystemState)
      for chunk in chunks(string) {
         let units = Array(chunk.utf16)
         for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else { continue }
            event.flags = []
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            event.post(tap: .cghidEventTap)
         }
      }
   }

   private func chunks(_ string: String) -> [String] {
      string.reduce(into: [""]) { chunks, character in
         if chunks[chunks.count - 1].utf16.count + character.utf16.count > Self.chunkLength { chunks.append("") }
         chunks[chunks.count - 1].append(character)
      }
   }

   /// Pastes the string marked transient, so clipboard managers skip it,
   /// then puts back what the pasteboard held unless something else wrote
   /// to it meanwhile.
   private func paste(_ string: String) {
      let board = NSPasteboard.general
      let saved = (board.pasteboardItems ?? []).map { item in
         item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
      }
      let item = NSPasteboardItem()
      item.setString(string, forType: .string)
      item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
      board.clearContents()
      board.writeObjects([item])
      let written = board.changeCount

      let source = CGEventSource(stateID: .hidSystemState)
      for down in [true, false] {
         guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: down) else { continue }
         event.flags = .maskCommand
         event.post(tap: .cghidEventTap)
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.restoreDelay) {
         guard board.changeCount == written else { return }
         board.clearContents()
         board.writeObjects(saved.map { pairs in
            let item = NSPasteboardItem()
            pairs.forEach { item.setData($1, forType: $0) }
            return item
         })
      }
   }

   private func copy(_ string: String) {
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(string, forType: .string)
   }
}
