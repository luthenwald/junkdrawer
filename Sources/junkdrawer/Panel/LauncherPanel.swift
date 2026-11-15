import AppKit
import Carbon.HIToolbox
import JunkdrawerCore

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
   /// ⇧⌘↵.
   var onTertiary: () -> Void = {}
   /// The commands with a key equivalent, as in apps with a menu.
   var onCommand: (Command) -> Void = { _ in }
   /// ⌘H, which hides the selected row for good.
   var onHide: () -> Void = {}
   let query = QueryField()
   private let details = Details()
   var list: ResultList { details.list }
   var footer: Footer { details.footer }
   var definition: DefinitionPane { details.definition }
   private var height: NSLayoutConstraint!
   /// True while the panel moves itself, so a move the user made can be
   /// told apart.
   private(set) var movesItself = false

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
      // Dragged by anything but the query field.
      isMovableByWindowBackground = true

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

   func move(topLeft: NSPoint) {
      movingItself { setFrameTopLeftPoint(topLeft) }
   }

   /// Shows the prefix legend and the definition pane or not, and fits the
   /// panel to what shows. The top edge stays where it is, unless the panel
   /// would leave the bottom of the screen; then it moves up.
   func fit(legend: Bool, definition: Bool) {
      details.showsLegend = legend
      details.showsDefinition = definition
      details.needsLayout = true
      let target = Self.queryHeight + details.height
      guard target != frame.height else { return }
      height.constant = target
      var next = frame
      next.origin.y += next.height - target
      next.size.height = target
      if let visible = screen?.visibleFrame, next.minY < visible.minY {
         next.origin.y = min(visible.minY, visible.maxY - target)
      }
      movingItself { setFrame(next, display: true) }
      invalidateShadow()
   }

   private func movingItself(_ change: () -> Void) {
      movesItself = true
      change()
      movesItself = false
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

   /// By key code, all with ⌘ alone.
   private static let commands: [Int: Command] = [kVK_ANSI_Comma: .settings, kVK_ANSI_Q: .quit]

   override func performKeyEquivalent(with event: NSEvent) -> Bool {
      let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
      if [kVK_Return, kVK_ANSI_KeypadEnter].contains(Int(event.keyCode)) {
         if modifiers == .command {
            onSecondary()
            return true
         }
         if modifiers == [.command, .shift] {
            onTertiary()
            return true
         }
      }
      if modifiers == .command, Int(event.keyCode) == kVK_ANSI_H {
         onHide()
         return true
      }
      if modifiers == .command, let command = Self.commands[Int(event.keyCode)] {
         onCommand(command)
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

/// Under the query field: a hairline, the list, then for a dictionary
/// entry a hairline and its definition, or for an empty query a hairline
/// and the prefix legend, then a hairline and the footer.
private final class Details: NSView {
   let list = ResultList()
   let footer = Footer()
   let definition = DefinitionPane()
   private let legend = Legend()
   private let rules = [Rule(), Rule(), Rule(), Rule()]
   var showsLegend = false {
      didSet {
         legend.isHidden = !showsLegend
         rules[2].isHidden = !showsLegend
      }
   }
   var showsDefinition = false {
      didSet {
         definition.isHidden = !showsDefinition
         rules[3].isHidden = !showsDefinition
      }
   }

   override var isFlipped: Bool { true }

   init() {
      super.init(frame: .zero)
      rules.forEach { $0.wantsLayer = true }
      [rules[0], list, rules[1], footer, rules[2], legend, rules[3], definition].forEach(addSubview)
      [legend, rules[2], definition, rules[3]].forEach { $0.isHidden = true }
   }

   required init?(coder: NSCoder) {
      fatalError("not used")
   }

   var height: CGFloat {
      list.height + Footer.height + 2 * Rule.width
         + (showsDefinition ? definition.height + Rule.width : 0)
         + (showsLegend ? Legend.height + Rule.width : 0)
   }

   override func layout() {
      super.layout()
      let width = bounds.width
      rules[0].frame = NSRect(x: 0, y: 0, width: width, height: Rule.width)
      list.frame = NSRect(x: 0, y: rules[0].frame.maxY, width: width, height: list.height)
      var y = list.frame.maxY
      if showsDefinition {
         rules[3].frame = NSRect(x: 0, y: y, width: width, height: Rule.width)
         definition.frame = NSRect(x: 0, y: rules[3].frame.maxY, width: width, height: definition.height)
         y = definition.frame.maxY
      }
      if showsLegend {
         rules[2].frame = NSRect(x: 0, y: y, width: width, height: Rule.width)
         legend.frame = NSRect(x: 0, y: rules[2].frame.maxY, width: width, height: Legend.height)
         y = legend.frame.maxY
      }
      rules[1].frame = NSRect(x: 0, y: y, width: width, height: Rule.width)
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

/// The query field, with a gray caret and selection instead of the accent
/// colour.
final class QueryField: NSTextField {
   override class var cellClass: AnyClass? {
      get { QueryCell.self }
      set {}
   }
}

/// Sets the colours each time editing starts. The cell resets the field
/// editor's selection colour then, so setting it once on the editor does
/// not last.
private final class QueryCell: NSTextFieldCell {
   override func setUpFieldEditorAttributes(_ text: NSText) -> NSText {
      let editor = super.setUpFieldEditorAttributes(text)
      if let editor = editor as? NSTextView {
         editor.insertionPointColor = .text
         editor.selectedTextAttributes = [.backgroundColor: NSColor.line]
      }
      return editor
   }
}

/// The four prefixes, under the recent list.
private final class Legend: NSView {
   static let height: CGFloat = 36
   private static let inset: CGFloat = 18
   private static let mono = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
   private static let entries = [("\\", "latex"), (":", "unicode"), ("?", "dictionary"), ("", "no prefix  apps and bookmarks")]

   private let label = NSTextField.line()

   init() {
      super.init(frame: .zero)
      label.attributedStringValue = .spaced(Self.entries.map { key, word in
         let text = NSMutableAttributedString(attributedString: .small(key, .text, font: Self.mono))
         text.append(.small(key.isEmpty ? word : "  " + word, .secondary))
         return text
      }, by: 22)
      addSubview(label)
   }

   required init?(coder: NSCoder) {
      fatalError("not used")
   }

   override func layout() {
      super.layout()
      let size = label.drawnSize
      label.frame = NSRect(x: Self.inset, y: (bounds.height - size.height) / 2, width: size.width, height: size.height)
   }
}
