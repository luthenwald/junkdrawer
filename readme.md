# Junkdrawer

A minimal, keyboard-only launcher for macOS.

## What it does

- Launches at login and stays out of the way until summoned with `⌃⇧Space`.
- Opens apps, and bookmarks from a plain text file in the default browser.
- `\` searches LaTeX commands and `:` Unicode names; `↵` inserts the symbol into the app you were in.
- `?` looks a word up in the macOS dictionary.
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

## Bookmarks

`~/.config/junkdrawer/bookmarks`, one per line: the URL, the title, then optional `#tags`. Lines starting with `;` are comments. Edit bookmarks creates the file and opens it, and changes show up as soon as you save.

```
https://codeberg.org Codeberg #git #forge
```

## Building

Needs the Command Line Tools and `just`.

```sh
just data     # download the Unicode and LaTeX tables
just gen      # write Resources/symbols.tsv
just install  # build, sign and copy to /Applications
```
