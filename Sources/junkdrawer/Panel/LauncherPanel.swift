import AppKit
import Carbon.HIToolbox

/// A borderless panel that takes key focus without activating the app, so
/// the app that was in front stays there.
final class LauncherPanel: NSPanel {
   static let width: CGFloat = 680
   static let queryHeight: CGFloat = 56
   static let visibleRows = 7

   /// For keys that reach the panel rather than the query field.
   var onCancel: () -> Void = {}
   /// ⌘↵, which the field editor does not pass on as a command.
   var onSecondary: () -> Void = {}
   let query = NSTextField()
   private let details = Details()
   var list: ResultList { details.list }
   var footer: Footer { details.footer }
   private var height: NSLayoutConstraint!
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
      for view in [query, details] {
         view.translatesAutoresizingMaskIntoConstraints = false
         surface.addSubview(view)
      }
      details.isHidden = true
      height = surface.heightAnchor.constraint(equalToConstant: Self.queryHeight)
      // Otherwise the window shrinks to the placeholder's width.
      NSLayoutConstraint.activate([
         surface.widthAnchor.constraint(equalToConstant: Self.width),
         height,
         details.topAnchor.constraint(equalTo: surface.topAnchor, constant: Self.queryHeight),
         details.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
         details.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
         details.bottomAnchor.constraint(equalTo: surface.bottomAnchor),
         query.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 18),
         query.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -18),
         query.centerYAnchor.constraint(equalTo: surface.topAnchor, constant: Self.queryHeight / 2),
      ])
      contentView = surface
      initialFirstResponder = query
   }

   override var canBecomeKey: Bool { true }

   /// Shows the list and footer under the query field, or hides them, and
   /// fits the panel to what shows. The top edge stays where it is.
   func fit(expanded: Bool) {
      details.isHidden = !expanded
      details.needsLayout = true
      let target = Self.queryHeight + (expanded ? details.height : 0)
      guard target != frame.height else { return }
      height.constant = target
      var next = frame
      next.origin.y += next.height - target
      next.size.height = target
      setFrame(next, display: true)
      invalidateShadow()
   }

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
      if modifiers == .command, [kVK_Return, kVK_ANSI_KeypadEnter].contains(Int(event.keyCode)) {
         onSecondary()
         return true
      }
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

/// Under the query field: a hairline, the list, a hairline and the footer.
private final class Details: NSView {
   let list = ResultList()
   let footer = Footer()
   private let rules = [Rule(), Rule()]

   override var isFlipped: Bool { true }

   init() {
      super.init(frame: .zero)
      rules.forEach { $0.wantsLayer = true }
      [rules[0], list, rules[1], footer].forEach(addSubview)
   }

   required init?(coder: NSCoder) {
      fatalError("not used")
   }

   var height: CGFloat {
      list.height + Footer.height + 2 * Rule.width
   }

   override func layout() {
      super.layout()
      let width = bounds.width
      rules[0].frame = NSRect(x: 0, y: 0, width: width, height: Rule.width)
      list.frame = NSRect(x: 0, y: rules[0].frame.maxY, width: width, height: list.height)
      rules[1].frame = NSRect(x: 0, y: list.frame.maxY, width: width, height: Rule.width)
      footer.frame = NSRect(x: 0, y: rules[1].frame.maxY, width: width, height: Footer.height)
   }
}

/// A hairline in the line gray.
private final class Rule: NSView {
   static let width: CGFloat = 1

   override var wantsUpdateLayer: Bool { true }

   override func updateLayer() {
      layer?.backgroundColor = NSColor.line.cgColor
   }

   override func viewDidChangeEffectiveAppearance() {
      needsDisplay = true
   }
}
