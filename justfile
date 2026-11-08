# Lists the recipes.
_default:
   @just --list

# Builds a debug binary.
build:
   swift build

# Builds build/Junkdrawer.app, signed with the local identity when it exists.
bundle:
   ./bundle.sh

# Quits a running Junkdrawer and opens the freshly bundled app.
run: bundle _quit
   open build/Junkdrawer.app

# Replaces /Applications/Junkdrawer.app with the bundled app and opens it.
install: bundle _quit
   rm -rf /Applications/Junkdrawer.app
   cp -R build/Junkdrawer.app /Applications/
   open /Applications/Junkdrawer.app

# Downloads the pinned Unicode, CLDR and LaTeX source files into data/.
data:
   ./data/fetch.sh

# Writes Resources/symbols.tsv from the files in data/.
gen:
   swift run gen data Resources/symbols.tsv

# Shows recent log lines from the running app.
log:
   log show --last 10m --predicate 'subsystem == "junkdrawer.junkdrawer"' --style compact

# Quits a running Junkdrawer and waits until it is gone. Opening the app while
# the old process is still exiting fails with error -600.
_quit:
   pkill -x Junkdrawer && while pgrep -x Junkdrawer > /dev/null; do sleep 0.1; done || true
