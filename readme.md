# Junkdrawer

A minimal, keyboard-only launcher for macOS.

## What it does

- Launches at login and stays out of the way until summoned with `⌘Space`.
- Opens apps, the panes of System Settings, and bookmarks from a plain text file in the default browser.
- `\` searches LaTeX commands and `:` Unicode names, keywords and emoji; `↵` inserts the symbol into the app you were in.
- `?` looks a word up in the macOS dictionary and shows its definition under the list; a one-word search also ends with a row that does this.
- Remembers what you pick: frequent and recent picks rank higher, and an empty search lists your recent ones.
- Has no menu. Reload data, Edit bookmarks, Show logs, Settings, Statistics and Quit junkdrawer are found and run like apps, and so are Sleep, Sleep displays, Lock screen, Log out, Restart, Shut down and Empty Trash. Restart, Shut down and Log out show the system's dialog first.
- Can be dragged anywhere, and opens there again on that screen.
- Counts what you use and draws it in a Statistics window, with an export as JSON or CSV.

## Keyboard

| Shortcut | Action |
| --- | --- |
| `⌘Space` | Show or hide the launcher |
| `↑` `↓` / `⌃N` `⌃P` | Move the selection |
| `↵` | Open, insert, or look up |
| `⌘↵` | Reveal, copy the URL, copy the command or codepoint, copy the word |
| `⇧⌘↵` | Copy the definition of a dictionary entry |
| `⌘H` | Hide the selected app or settings pane from the results |
| `Esc` | Clear the query, then hide |
| `⌘,` | Open Settings |
| `⌘Q` | Quit junkdrawer |

`⌘Space` is Spotlight's shortcut too, so turn that off in System Settings, Keyboard, Keyboard Shortcuts, Spotlight. While Spotlight holds it, junkdrawer listens for `⌃⇧Space` instead. You can record another shortcut in Settings.

## Settings

Settings holds the shortcut, launching at login, extra folders to search for apps (one level deep, like the Applications folders), the bookmarks file, the appearance, and Reset for the launcher's position. Running Settings while its window is open on another Space opens it where you are.

Keep the query sets how many seconds the launcher remembers its query after you hide it, up to 60. At Off, the default, it always opens empty. Running an action always leaves it empty.

Apps and settings panes you hid with `⌘H` are listed under Hidden items, each with a button that shows it again.

## Statistics

Every action counts once, by day and by kind, and once for the item itself. A dictionary look-up counts for the entry on screen when the launcher hides. The Statistics window draws the last 30 days, the last 12 weeks or everything, lists what you used most, and exports everything as JSON or the daily counts as CSV. The counts stay on your Mac, in `~/Library/Application Support/Junkdrawer/stats.json`.

## Inserting symbols

Inserting types the symbol into the app that was in front, which macOS only allows once junkdrawer is turned on in System Settings, Privacy & Security, Accessibility. The first insert asks for it. Until then, and while a password field has focus, symbols are copied to the clipboard instead. Lock screen uses the same access, and Empty Trash asks once to let junkdrawer control Finder.

## Bookmarks

`~/.config/junkdrawer/bookmarks` unless you choose another file in Settings, one per line: the URL, the title, then optional `#tags`. Lines starting with `;` are comments. Edit bookmarks creates the file and opens it, and changes show up as soon as you save.

```
https://codeberg.org Codeberg #git #forge
```

## Building

Needs the Command Line Tools and `just`.

The Unicode, CLDR and LaTeX tables in `data/` are committed with their licences; `data/README.md` says where each comes from.

```sh
just data     # download the Unicode and LaTeX tables again
just gen      # write Resources/symbols.tsv
just install  # build, sign and copy to /Applications
```

## Uninstalling

Quit junkdrawer with `⌘Q` while the launcher shows, then remove what it left:

```sh
rm -rf /Applications/Junkdrawer.app
rm -rf ~/Library/Application\ Support/Junkdrawer   # usage.json and stats.json
rm -rf ~/Library/Logs/Junkdrawer                   # the file Show logs writes
rm -rf ~/.config/junkdrawer                        # your bookmarks, unless you keep them elsewhere
defaults delete junkdrawer.junkdrawer              # the settings
tccutil reset All junkdrawer.junkdrawer            # the Accessibility and Automation grants
```

The login item goes with the app; if it still shows in System Settings, General, Login Items, remove it there. A build from source also leaves `.build/` and `build/` in the repository, and the signing certificate `junkdrawer local` in Keychain Access, if you made one.
