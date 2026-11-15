# Data

The source files for the symbol table, as downloaded by `fetch.sh`. `VERSION` records when they were fetched and which versions they are. `swift run gen data Resources/symbols.tsv`, run from the repository root, turns them into `Resources/symbols.tsv`. The files are kept exactly as downloaded.

| File | From | Licence |
| --- | --- | --- |
| `UnicodeData.txt`, `NameAliases.txt`, `UCD-ReadMe.txt` | Unicode Character Database 18.0.0, https://www.unicode.org/Public/18.0.0/ucd/ | Unicode License v3, `UNICODE-LICENSE.txt` |
| `emoji-test.txt` | Unicode emoji 18.0, https://www.unicode.org/Public/18.0.0/emoji/ | Unicode License v3, `UNICODE-LICENSE.txt` |
| `cldr-annotations-en.xml`, `cldr-annotations-derived-en.xml` | CLDR 49, `common/annotations/en.xml` and `common/annotationsDerived/en.xml` at tag `release-49` of https://github.com/unicode-org/cldr | Unicode License v3, `UNICODE-LICENSE.txt` |
| `unicode-math-table.tex` | The unicode-math package by Will Robertson and others, from CTAN, https://ctan.org/pkg/unicode-math | LPPL 1.3c, `LPPL-1.3c.txt` |
| `unimathsymbols.txt` | Günter Milde's table of Unicode characters and LaTeX math commands, see below | LPPL 1.3 or later, `LPPL-1.3c.txt` |

`unimathsymbols.txt` was published at http://milde.users.sourceforge.net/LUCR/Math/data/unimathsymbols.txt, which no longer serves it. The copy here comes from https://github.com/mmarchywka/toobib at commit `325724d1a300aef4a696ffefae6d95bfd192a44f`, which keeps the file with its original header, copyright notice and licence statement. `fetch.sh` checks its SHA-256.
