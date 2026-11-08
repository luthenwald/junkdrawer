import Foundation

// Milestone 04/06: parse UnicodeData.txt, NameAliases.txt, the CLDR
// annotations, unimathsymbols.txt and unicode-math-table.tex from the data
// folder, and write one line per symbol to the output file, tab separated:
// string, name, aliases, keywords, LaTeX commands with their packages.

let arguments = CommandLine.arguments.dropFirst()
guard arguments.count == 2 else {
   FileHandle.standardError.write(Data("usage: gen <data folder> <output .tsv>\n".utf8))
   exit(2)
}
FileHandle.standardError.write(Data("gen: not implemented yet\n".utf8))
exit(1)
