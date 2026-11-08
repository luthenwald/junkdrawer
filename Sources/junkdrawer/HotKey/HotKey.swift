import Carbon.HIToolbox

/// A key code plus Carbon modifier flags, and the name of the key as it
/// was typed, for display.
struct Shortcut: Hashable, Codable {
   var keyCode: UInt32
   var modifiers: UInt32
   var key: String

   /// ⌘Space, which needs Spotlight's shortcut turned off.
   static let toggle = Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey), key: "Space")
   /// ⌃⇧Space, for when ⌘Space is taken.
   static let fallback = Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | shiftKey), key: "Space")
}

struct HotKeyError: Error {
   let status: OSStatus
}

/// A system wide hotkey through Carbon, which needs no Accessibility permission.
@MainActor
final class HotKey {
   private static let signature: OSType = 0x4A4E4B44 // "JNKD"
   private static var nextID: UInt32 = 1

   private let id: UInt32
   private let action: () -> Void
   // Also released in `deinit`, which is not isolated to the main actor.
   // The hotkey lives as long as the app, so that never races.
   nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
   nonisolated(unsafe) private var handlerRef: EventHandlerRef?

   init(action: @escaping () -> Void) {
      id = Self.nextID
      Self.nextID += 1
      self.action = action

      var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
      InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
         guard let event, let userData else { return OSStatus(eventNotHandledErr) }
         var pressed = EventHotKeyID()
         GetEventParameter(
            event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
            nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed
         )
         // Carbon delivers hotkey events on the main thread.
         return MainActor.assumeIsolated {
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            guard pressed.signature == HotKey.signature, pressed.id == hotKey.id else {
               return OSStatus(eventNotHandledErr)
            }
            hotKey.action()
            return noErr
         }
      }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
   }

   func register(_ shortcut: Shortcut) throws(HotKeyError) {
      unregister()
      let status = RegisterEventHotKey(
         shortcut.keyCode, shortcut.modifiers, EventHotKeyID(signature: Self.signature, id: id),
         GetApplicationEventTarget(), 0, &hotKeyRef
      )
      guard status == noErr else { throw HotKeyError(status: status) }
   }

   func unregister() {
      if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
      hotKeyRef = nil
   }

   deinit {
      if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
      if let handlerRef { RemoveEventHandler(handlerRef) }
   }
}
