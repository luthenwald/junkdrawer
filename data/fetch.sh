#!/bin/sh
# Downloads the source files for the symbol table into data/ and records what
# was fetched in data/VERSION. Run from the repository root (`just data`).
set -e
cd "$(dirname "$0")"

# Check this against the latest CLDR release before relying on it.
CLDR_TAG=release-48

fetch() {
   echo "fetching $2"
   curl -fsSL "$1" -o "$2"
}

fetch https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt UnicodeData.txt
fetch https://www.unicode.org/Public/UCD/latest/ucd/NameAliases.txt NameAliases.txt
fetch https://www.unicode.org/Public/UCD/latest/ucd/ReadMe.txt UCD-ReadMe.txt
fetch https://www.unicode.org/license.txt UNICODE-LICENSE.txt
fetch "https://raw.githubusercontent.com/unicode-org/cldr/$CLDR_TAG/common/annotations/en.xml" cldr-annotations-en.xml
fetch "https://raw.githubusercontent.com/unicode-org/cldr/$CLDR_TAG/common/annotationsDerived/en.xml" cldr-annotations-derived-en.xml
fetch https://mirrors.ctan.org/macros/unicodetex/latex/unicode-math/unicode-math-table.tex unicode-math-table.tex
# Check the licence of this file before committing it.
fetch https://milde.users.sourceforge.net/LUCR/Math/data/unimathsymbols.txt unimathsymbols.txt

{
   echo "fetched $(date -u +%Y-%m-%d)"
   grep -m1 -o 'Version [0-9.]*' UCD-ReadMe.txt | sed 's/^/UCD /' || true
   echo "CLDR $CLDR_TAG"
   grep -m1 -o 'unicode-math-table.tex.*' unicode-math-table.tex | head -c 120 || true
   echo
} > VERSION
cat VERSION
