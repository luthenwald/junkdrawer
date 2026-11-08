import AppKit

/// A borderless panel that takes key focus without activating the app, so
/// the app that was in front stays there.
final class LauncherPanel: NSPanel {
   static let width: CGFloat = 680
   static let queryHeight: CGFloat = 56

   /// For keys that reach the panel rather than the query field.
   var onCancel: () -> Void = {}
   let query = NSTextField()
   /// Shared by the text fields, with a gray caret and selection.
   private let fieldEditor = NSTextView()

   init() {
      super.init(
         contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.queryHeight),
         styleMask: [.borderless, .nonactivatingPanel],
         backing: .buffered,
         defer: true
      )
      level = .floating
      collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
      becomesKeyOnlyIfNeeded = false
      hidesOnDeactivate = false
      isReleasedWhenClosed = false
      // The surface draws the rounded background; the shadow follows it.
      isOpaque = false
      backgroundColor = .clear
      hasShadow = true

      fieldEditor.isFieldEditor = true
      fieldEditor.insertionPointColor = .text
      fieldEditor.selectedTextAttributes = [.backgroundColor: NSColor.line]

      let font = NSFont.systemFont(ofSize: 19, weight: .light)
      query.isBordered = false
      query.isBezeled = false
      query.drawsBackground = false
      query.focusRingType = .none
      query.usesSingleLineMode = true
      query.lineBreakMode = .byClipping
      query.cell?.isScrollable = true
      query.font = font
      query.textColor = .text
      query.placeholderAttributedString = NSAttributedString(
         string: "Search apps and bookmarks",
         attributes: [.font: font, .foregroundColor: NSColor.secondary]
      )

      let surface = Surface()
      query.translatesAutoresizingMaskIntoConstraints = false
      surface.addSubview(query)
      // Otherwise the window shrinks to the placeholder's width.
      NSLayoutConstraint.activate([
         surface.widthAnchor.constraint(equalToConstant: Self.width),
         surface.heightAnchor.constraint(equalToConstant: Self.queryHeight),
         query.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 18),
         query.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -18),
         query.centerYAnchor.constraint(equalTo: surface.topAnchor, constant: Self.queryHeight / 2),
      ])
      contentView = surface
      initialFirstResponder = query
   }

   override var canBecomeKey: Bool { true }

   override func fieldEditor(_ createFlag: Bool, for object: Any?) -> NSText? {
      object is NSTextField ? fieldEditor : super.fieldEditor(createFlag, for: object)
   }

   /// Tiling window managers such as AeroSpace leave system floating
   /// windows alone, as they do other launchers.
   override func accessibilitySubrole() -> NSAccessibility.Subrole? {
      .systemFloatingWindow
   }

   override func cancelOperation(_ sender: Any?) {
      onCancel()
   }

   /// The editing keys, which a text field otherwise gets from the Edit
   /// menu; the app has no menu.
   private static let editing: [String: (modifiers: NSEvent.ModifierFlags, action: Selector)] = [
      "x": ([.command], #selector(NSText.cut(_:))),
      "c": ([.command], #selector(NSText.copy(_:))),
      "v": ([.command], #selector(NSText.paste(_:))),
      "a": ([.command], #selector(NSText.selectAll(_:))),
      "z": ([.command], Selector(("undo:"))),
      "Z": ([.command, .shift], Selector(("redo:"))),
   ]

   override func performKeyEquivalent(with event: NSEvent) -> Bool {
      let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
      if let key = event.charactersIgnoringModifiers, let edit = Self.editing[key], edit.modifiers == modifiers,
         NSApp.sendAction(edit.action, to: nil, from: self) {
         return true
      }
      return super.performKeyEquivalent(with: event)
   }
}

/// The panel's background with a hairline border and rounded corners.
private final class Surface: NSView {
   override init(frame: NSRect) {
      super.init(frame: frame)
      wantsLayer = true
      layer?.cornerRadius = 12
      layer?.cornerCurve = .continuous
      layer?.borderWidth = 1
      layer?.masksToBounds = true
   }

   required init?(coder: NSCoder) {
      fatalError("not used")
   }

   override var wantsUpdateLayer: Bool { true }

   /// Runs again on appearance changes, which resolves the colors anew.
   override func updateLayer() {
      layer?.backgroundColor = NSColor.background.cgColor
      layer?.borderColor = NSColor.line.cgColor
   }

   override func viewDidChangeEffectiveAppearance() {
      needsDisplay = true
   }
}
