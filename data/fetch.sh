#!/bin/sh
# Downloads the source files for the symbol table into data/ and records what
# was fetched in data/VERSION. Run from the repository root (`just data`).
# The files are committed; see data/README.md for where each comes from.
set -e
cd "$(dirname "$0")"

UCD_VERSION=18.0.0
CLDR_TAG=release-49
# unimathsymbols.txt lost its home on sourceforge; this repository keeps an
# unmodified copy. Pinned by commit and checked by hash.
TOOBIB_COMMIT=325724d1a300aef4a696ffefae6d95bfd192a44f
UNIMATH_SHA256=55841895e75fa72d42e9a8533592b333990f90ded7903cee521c9e4f8693aa9d

UCD="https://www.unicode.org/Public/$UCD_VERSION"
CLDR="https://raw.githubusercontent.com/unicode-org/cldr/$CLDR_TAG/common"

fetch() {
   echo "fetching $2"
   curl -fsSL "$1" -o "$2"
}

fetch "$UCD/ucd/UnicodeData.txt" UnicodeData.txt
fetch "$UCD/ucd/NameAliases.txt" NameAliases.txt
fetch "$UCD/ucd/ReadMe.txt" UCD-ReadMe.txt
fetch "$UCD/emoji/emoji-test.txt" emoji-test.txt
fetch https://www.unicode.org/license.txt UNICODE-LICENSE.txt
fetch "$CLDR/annotations/en.xml" cldr-annotations-en.xml
fetch "$CLDR/annotationsDerived/en.xml" cldr-annotations-derived-en.xml
fetch https://mirrors.ctan.org/macros/unicodetex/latex/unicode-math/unicode-math-table.tex unicode-math-table.tex
fetch "https://raw.githubusercontent.com/mmarchywka/toobib/$TOOBIB_COMMIT/unimathsymbols.txt" unimathsymbols.txt
fetch https://www.latex-project.org/lppl/lppl-1-3c.txt LPPL-1.3c.txt

echo "$UNIMATH_SHA256  unimathsymbols.txt" | shasum -a 256 -c -

{
   echo "fetched $(date -u +%Y-%m-%d)"
   echo "UCD $UCD_VERSION"
   grep -m1 -o '^# Version: .*' emoji-test.txt | sed 's/^# Version: /emoji /' || true
   echo "CLDR $CLDR_TAG"
   echo "unimathsymbols.txt from mmarchywka/toobib $TOOBIB_COMMIT"
   grep -m1 -o 'Last revised.*' unimathsymbols.txt | sed 's/^/   /' || true
   curl -fsSL https://ctan.org/json/2.0/pkg/unicode-math \
      | grep -o '"version":{[^}]*}' | sed 's/.*"number":"\([^"]*\)","date":"\([^"]*\)".*/unicode-math \1 (\2), from CTAN/' || true
} > VERSION
cat VERSION
