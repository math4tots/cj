package compiler.main

import cj.FS
import cj.Argv
import compiler.CJLexer

## Sample main class that will simply lex and print each token in the given file
class Lexer {
    def main() {
        for filename in Argv() {
            val data = FS.readFile(filename)
            IO.println("Lexing " + filename)
            val tokens = CJLexer.lex(filename, data)
            for token in tokens {
                IO.println(token)
            }
        }
    }
}
