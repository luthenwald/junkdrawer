# Junkdrawer

A minimal, keyboard-only launcher for macOS.

## What it does

- Launches at login and stays out of the way until summoned with `⌃⇧Space`.
- Opens apps, and bookmarks from a plain text file in the default browser.
- `\` searches LaTeX commands and `:` Unicode names, keywords and emoji; `↵` inserts the symbol into the app you were in.
- `?` looks a word up in the macOS dictionary and shows its definition under the list; a one-word search also ends with a row that does this.
- Remembers what you pick: frequent and recent picks rank higher, and an empty search lists your recent ones.
- Has no menu. Reload data, Edit bookmarks, Show logs and Quit junkdrawer are found and run like apps.

## Keyboard

| Shortcut | Action |
| --- | --- |
| `⌃⇧Space` | Show or hide the launcher |
| `↑` `↓` / `⌃N` `⌃P` | Move the selection |
| `↵` | Open, insert, or look up |
| `⌘↵` | Reveal, copy the URL, copy the command or codepoint, copy the definition |
| `Esc` | Clear the query, then hide |

## Inserting symbols

Inserting types the symbol into the app that was in front, which macOS only allows once junkdrawer is turned on in System Settings, Privacy & Security, Accessibility. The first insert asks for it. Until then, and while a password field has focus, symbols are copied to the clipboard instead.

## Bookmarks

`~/.config/junkdrawer/bookmarks`, one per line: the URL, the title, then optional `#tags`. Lines starting with `;` are comments. Edit bookmarks creates the file and opens it, and changes show up as soon as you save.

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
