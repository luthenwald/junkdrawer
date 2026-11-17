# Changelog

## Unreleased

- New: Type `/` to find files and folders by name in the folders you choose in Settings. `↵` opens one, `⌘↵` shows it in Finder and `⇧⌘↵` copies its path.
- New: Settings has a Files section for those folders and how deep to look into them.
- Improved: The Settings window scrolls when it is taller than your screen.
- Fixed: Keychain Access and the other apps macOS keeps in its core services folder, such as Archive Utility and Ticket Viewer, now show up.

## A keyboard launcher for apps, bookmarks, symbols and words

0.1.0 · 2026-11-15 · `lyxrmktr::xtktmopy`

- New: ⌘Space opens a search field that finds your apps as you type, with their icons in gray, and ↵ opens the selected one.
- New: ⌘↵ shows the selected app in Finder instead.
- New: ↑ and ↓, or ⌃N and ⌃P, move through the results, and the footer shows what ↵ and ⌘↵ will do.
- New: Apps you install or remove show up in the list on their own, without restarting.
- New: Cut, copy, paste, select all and undo work in the search field.
- New: Bookmarks from `~/.config/junkdrawer/bookmarks` show up next to your apps; ↵ opens one in your browser and ⌘↵ copies its address.
- New: What you open often and recently ranks higher, and opening the launcher shows your recent picks.
- New: Reload data, Edit bookmarks, Show logs and Quit junkdrawer can be found and run like apps.
- New: A short line at the bottom of the screen confirms what an action did.
- New: Type `\` and a LaTeX command, such as `\alpha`, to insert its symbol into the app you were in. Each symbol is listed once, under the command closest to what you typed, and ⌘↵ copies that command.
- New: Type `:` and words from a character's name, such as `:arrow right` or `:heart`, to insert any Unicode character or emoji, drawn in its own colors; ⌘↵ copies its code point.
- New: Type `?` and a word to see its entry from the macOS dictionary as you type, with suggestions when the spelling is off; ↵ opens it in Dictionary, ⌘↵ copies the word and ⇧⌘↵ copies the definition.
- New: A search for a single word ends with a row that looks the word up in the dictionary.
- New: Settings, opened with ⌘, in the launcher or by searching for Settings. There you can record another shortcut for showing the launcher, turn launching at login on or off, add folders to search for apps, choose another bookmarks file, and pick a light or dark appearance instead of following the system. Settings opens where you are, also when it was left open on another Space.
- New: The panes of System Settings, such as Appearance, Privacy & Security or Desktop & Dock, can be found like apps, also by words like "dock", "wifi" or "camera", and ↵ opens the pane.
- New: ⌘Q quits junkdrawer while the launcher or Settings is in front.
- New: Sleep, Restart, Shut down, Log out, Lock screen, Sleep displays and Empty Trash can be found and run like apps. Restart, Shut down and Log out ask first with the system's own dialog, and none of these four show up among your recent picks.
- New: You can drag the launcher anywhere. It opens there again on that screen, and Reset in Settings puts it back in the middle.
- New: Keep the query, in Settings, makes the launcher remember what it showed for up to a minute after you hide it, so a word you looked up is still there when you come back. It is off until you set a number of seconds.
- New: ⌘H hides the selected app or System Settings pane from the results. Settings lists what you have hidden and brings each one back.
- New: Statistics, found like an app or opened from Settings, shows how often you used apps, bookmarks, commands, settings panes, symbols and the dictionary, day by day, and what you used most. You can export the counts as JSON or CSV.
- New: The first time you insert a symbol, macOS asks to let junkdrawer control your computer. Until you allow it, and whenever a password field has focus, the symbol is copied and the line at the bottom says so.
- New: junkdrawer has an icon, which shows in Finder, in Login Items and in the Privacy & Security lists.
