package cjx.re

import cj.Range
import cj.StringBuilder
import cj.Error

## Simple Regex implementation
##
## For simplicity, all non-ASCII characters are mapped to 128.
##
class Regex {

    val nfa: CachingNFA

    @variadic
    def new(patterns: List[String]): Self = Self.fromPatterns(patterns)

    def fromPatterns(patterns: List[String]): Self = (
        Self.__malloc(CachingNFA(NFA.fromPatterns(patterns))))

    def match(self: Self, string: String): Nullable[MatchResult] = (
        self.matchEx(string, 0, string.size(), false))

    def matchFrom(self: Self, string: String, start: Int): Nullable[MatchResult] = (
        self.matchEx(string, start, string.size(), false))

    def fullMatch(self: Self, string: String): Nullable[MatchResult] = (
        self.matchEx(string, 0, string.size(), true))

    def matches(self: Self, string: String): Bool = self.fullMatch(string).isPresent()

    private def matchEx(
            self: Self,
            string: String,
            start: Int,
            end: Int,
            fullMatch: Bool): Nullable[MatchResult] = {
        val nfa = self.nfa
        var states = nfa.newStart()
        val patternCount = nfa.patternCount
        var i = start
        var lastMatchEnd = -1
        var lastMatchPatternIndex = -1
        while i < end and states {
            if not fullMatch {
                val representative = nfa.getRepresentative(states)
                if representative < patternCount {
                    lastMatchEnd = i
                    lastMatchPatternIndex = representative
                }
            }
            val ch = string.charAt(i)
            states = nfa.transition(states, ch.toInt())
            i += ch.size()
        }
        if states {
            val representative = nfa.getRepresentative(states)
            if representative < patternCount {
                lastMatchEnd = i
                lastMatchPatternIndex = representative
            }
        }
        if lastMatchEnd == -1 { null } else {
            null(MatchResult.__malloc(string, start, lastMatchEnd, lastMatchPatternIndex))
        }
    }

    class CachingNFA {
        val nfa: NFA
        val idToStates: List[Set[Int]]
        val statesToId: Map[Set[Int], Int]
        val idToRepresentative: List[Int]
        val transitionMap: List[List[Int]]

        def new(nfa: NFA): Self = {
            val self = Self.__malloc(nfa, [], Map(), [], [])
            Assert.equal(self.getId(Set()), 0)
            self
        }

        def __get_patternCount(self: Self): Int = self.nfa.patternCount

        def getId(self: Self, states: Set[Int]): Int = {
            if null(id) = self.statesToId.getOrNull(states) {
                id
            } else {
                val id = self.idToStates.size()
                self.idToRepresentative.add(if states.isEmpty() { self.nfa.patternCount } else {
                    states.min()
                })
                self.idToStates.add(states)
                self.statesToId[states] = id
                self.transitionMap.add([-1] * 129)
                id
            }
        }

        def getRepresentative(self: Self, id: Int): Int = self.idToRepresentative[id]

        def newStart(self: Self): Int = self.getId(self.nfa.newStart())

        def transition(self: Self, id: Int, var ch: Int): Int = {
            if ch > 127 { ch = NFA.nonAscii }
            val newId = self.transitionMap[id][ch]
            if newId == -1 {
                val computedNewId = self.transitionNoCache(id, ch)
                self.transitionMap[id][ch] = computedNewId
                computedNewId
            } else {
                newId
            }
        }

        def transitionNoCache(self: Self, id: Int, ch: Int): Int = {
            val beforeStates = self.idToStates[id]
            val afterStates = self.nfa.transition(beforeStates, ch)
            self.getId(afterStates)
        }
    }

    class NFA {
        static val epsilon: Int = -2
        static val nonAscii: Int = 128

        ## Number of patterns in this compiled Regex
        ##
        ## State patternCount is the start state,
        ## states 0..(patternCount - 1) are the accept states.
        val patternCount: Int

        ## NFAGraph describing transitions
        val transitionMap: List[Map[Int, Set[Int]]]

        def fromTrees(trees: List[Tree]): Self = {
            val graph = NFAGraph()
            for i = 0; i < trees.size(); i += 1 {
                Assert.equal(graph.newNode(), i)
            }
            val startState = graph.newNode()
            Assert.equal(startState, trees.size())
            for i = 0; i < trees.size(); i += 1 {
                val tree = trees[i]
                graph.buildBlock(tree, startState, i)
            }
            Self.__malloc(trees.size(), graph.transitionMap)
        }

        def fromPatterns(patterns: List[String]): Self = (
            Self.fromTrees(patterns.map(pattern -> PatternParser(pattern).parsePattern())))

        def newStart(self: Self): Set[Int] = self.closure(Set(self.patternCount))

        def transition(self: Self, states: Set[Int], var ch: Int): Set[Int] = {
            if ch > 127 { ch = NFA.nonAscii }
            val map = self.transitionMap
            self.closure(states.flatMap(state -> map[state].getOrElse(ch, () -> Set())))
        }

        def closure(self: Self, set: Set[Int]): Set[Int] = {
            val ret = Set[Int].empty()
            val empty = Set[Int].empty()
            val map = self.transitionMap
            val epsilon = NFA.epsilon
            for state in set {
                ret.add(state)
                ret.addAll(map[state].getOrDefault(epsilon, empty))
            }
            ret
        }

        def dump(self: Self): String = {
            val sb = StringBuilder()
            sb.add("NFA (start = " + self.patternCount + ")\n")
            for i = 0; i < self.transitionMap.size(); i += 1 {
                sb.add("  " + i + ":\n")
                val keys = self.transitionMap[i].keys().toList()
                for j = 0; j < keys.size(); j += 1 {
                    val start = j
                    val out = self.transitionMap[i][keys[j]]
                    while (j + 1 < keys.size() and
                            keys[j] + 1 == keys[j + 1] and
                            out == self.transitionMap[i][keys[j + 1]]) {
                        j += 1
                    }
                    sb.add("    ")
                    if j > start {
                        sb.add("" + keys[start].toChar().repr() + "-" + keys[j - 1].toChar().repr())
                    } else if keys[start] == NFA.epsilon {
                        sb.add("epsilon")
                    } else {
                        sb.add(keys[start].toChar().repr())
                    }
                    sb.add(" -> " + out + "\n")
                }
            }
            sb.toString()
        }
    }

    class MatchResult {
        val originalString: String

        ## Index from which the match starts
        val start: Int

        ## Index at which this match ends
        val end: Int

        ## The matching pattern index
        val matchIndex: Int

        def __get_matchText(self: Self): String = self.originalString[self.start:self.end]
    }

    ## NFA graph along the lines of Thompson's construction
    private class NFAGraph {
        ## Transition map
        ## maps (node) -> (char-or-edge) -> (new-nodes)
        val transitionMap: List[Map[Int, Set[Int]]]

        def new(): Self = Self.__malloc([])

        def newNode(self: Self): Int = {
            val node = self.transitionMap.size()
            self.transitionMap.add(Map())
            node
        }

        def connect(self: Self, a: Int, var ch: Int, b: Int) = {
            if ch > 127 { ch = NFA.nonAscii }
            self.transitionMap[a].getOrInsert(ch, () -> Set()).add(b)
        }

        def buildBlock(self: Self, tree: Tree, var start: Int, var end: Int): Block = {
            start = if start == -1 { self.newNode() } else { start }
            end = if end == -1 { self.newNode() } else { end }
            union tree {
                case char(c) = {
                    self.connect(start, c.toInt(), end)
                }
                case cat(left, right) = {
                    val leftBlock = self.buildBlock(left, start, -1)
                    self.buildBlock(right, leftBlock.end, end)
                }
                case alt(left, right) = {
                    val leftBlock = self.buildBlock(left, -1, -1)
                    val rightBlock = self.buildBlock(right, -1, -1)
                    self.connect(start, NFA.epsilon, leftBlock.start)
                    self.connect(start, NFA.epsilon, rightBlock.start)
                    self.connect(leftBlock.end, NFA.epsilon, end)
                    self.connect(rightBlock.end, NFA.epsilon, end)
                }
                case star(inner) = self.buildIntervalBlock(start, end, inner, 0, -1)
                case plus(inner) = self.buildIntervalBlock(start, end, inner, 1, -1)
                case optional(inner) = self.buildIntervalBlock(start, end, inner, 0, 1)
                case interval(inner, min, max) = self.buildIntervalBlock(start, end, inner, min, max)
                case set(chars) = {
                    for c in chars {
                        self.connect(start, c.toInt(), end)
                    }
                }
            }
            Block(start, end)
        }

        private def buildIntervalBlock(
                self: Self, var start: Int, end: Int, inner: Tree, min: Int, max: Int) = {
            val epsilon = NFA.epsilon
            switch max {
                case -1 = {
                    if min == 0 {
                        # case 1: max is infinite and min = 0
                        # i.e. kleene star
                        self.buildBlock(inner, start, end)
                        self.connect(start, epsilon, end)
                        self.connect(end, epsilon, start)
                    } else {
                        # case 2: max is infinite and max > 0
                        # we build min blocks, with the last one using the overall end state.
                        # when min = 1, this is '+'
                        for i = 0; i + 1 < min; i += 1 {
                            start = self.buildBlock(inner, start, -1).start
                        }
                        self.buildBlock(inner, start, end)
                        self.connect(end, epsilon, start)
                    }
                }
                case 0 = {
                    # case 3: max = 0
                    self.connect(start, epsilon, end)
                }
                default = {
                    # case 4: 0 < max < infinity
                    # when min = 0 and max = 1, this is '?'
                    for i = 0; i < max; i += 1 {
                        if i >= min {
                            self.connect(start, epsilon, end)
                        }
                        start = self.buildBlock(inner, start, if i + 1 == max { end } else { -1 }).end
                    }
                }
            }
        }
    }

    @derive(pod)
    class Block {
        val start: Int
        val end: Int
    }

    @derive(repr)
    private union Tree {
        case char(Char)
        case cat(Tree, Tree)
        case alt(Tree, Tree)
        case star(Tree)
        case plus(Tree)
        case optional(Tree)
        case interval(Tree, Int, Int)
        case set(Set[Int])
    }

    private class PatternParser {
        private static val allLetters: Set[Int] = Range.upto(129).toSet()
        private static val allDigits: Set[Int] = Range.inclusive('0', '9').toSet()
        private static val allNonDigits: Set[Int] = Self.allLetters.filter(x -> x not in Self.allDigits)
        private static val allSpace: Set[Int] = Set(' ', '\n', '\t', '\f', '\r')
        private static val allNonSpace: Set[Int] = Self.allLetters.filter(x -> x not in Self.allSpace)
        private static val allWord: Set[Int] = (
            Range.inclusive('a', 'z').toSet() + Range.inclusive('A', 'Z').toSet() + Set('_'))
        private static val allNonWord: Set[Int] = Self.allLetters.filter(x -> x not in Self.allWord)

        private val pattern: String
        private var i: Int

        def new(pattern: String): Self = Self.__malloc(pattern, 0)

        def err(self: Self, message: String): Error = Error(message)

        def peek(self: Self): Char = (
            if self.i < self.pattern.size() { self.pattern.charAt(self.i) } else { '\0' })

        def next(self: Self): Char = {
            val ch = self.peek()
            self.i += 1
            ch
        }

        def at(self: Self, ch: Char): Bool = self.peek() == ch

        def consume(self: Self, ch: Char): Bool = {
            if self.at(ch) {
                self.next()
                true
            } else {
                false
            }
        }

        def expect(self: Self, ch: Char) = {
            if not self.consume(ch) {
                throw self.err("Expected " + ch.repr() + " but got " + self.peek().repr())
            }
        }

        def parsePattern(self: Self): Tree = self.parseOr()

        def parseOr(self: Self): Tree = {
            var tree = self.parseAnd()
            while self.consume('|') {
                val rhs = self.parseAnd()
                tree = Tree.alt(tree, rhs)
            }
            tree
        }

        def parseAnd(self: Self): Tree = {
            var tree = self.parsePostfix()
            var repeat = true
            while repeat {
                switch self.peek() {
                    case '|'
                    case ')'
                    case '\0' = {
                        repeat = false
                    }
                    default = {
                        val rhs = self.parsePostfix()
                        tree = Tree.cat(tree, rhs)
                    }
                }
            }
            tree
        }

        def parsePostfix(self: Self): Tree = {
            val inner = self.parseAtom()
            switch self.peek() {
                case '*' = { self.next() ; Tree.star(inner) }
                case '+' = { self.next() ; Tree.plus(inner) }
                case '?' = { self.next() ; Tree.optional(inner) }
                case '{' = {
                    self.next()
                    val min = if self.at(',') { 0 } else { self.parseInt() }
                    val max = if self.consume(',') {
                        if self.at('}') { -1 } else { self.parseInt() }
                    } else {
                        min
                    }
                    self.expect('}')
                    Tree.interval(inner, min, max)
                }
                default = inner
            }
        }

        def parseInt(self: Self): Int = {
            val start = self.i
            while self.peek().isDigit() {
                self.next()
            }
            self.pattern[start:self.i].parseInt().get()
        }

        def parseAtom(self: Self): Tree = {
            switch self.peek() {
                case '\0' = throw self.err("unexpected end of string")
                case '\\' = {
                    self.next()
                    val ch = self.next()
                    self.fromEscapeChar(ch)
                }
                case '(' = {
                    self.next()
                    val tree = self.parsePattern()
                    self.expect(')')
                    tree
                }
                case '.' = {
                    self.next()
                    Tree.set(Self.allLetters)
                }
                case '[' = {
                    self.next()
                    val set = Set[Int]()
                    while not self.consume(']') {
                        val ch = self.next()
                        if (ch.isLetter() or ch.isDigit()) and self.peek() == '-' {
                            self.next()
                            val peek = self.peek()
                            if (peek.isUpper() and ch.isUpper() or
                                    peek.isLower() and ch.isLower() or
                                    peek.isDigit() and ch.isDigit()) {
                                val limit = self.next().toInt()
                                for i = ch.toInt(); i < limit; i += 1 {
                                    set.add(i)
                                }
                            } else {
                                throw self.err("Invalid character class range: " + ch.repr() + "-" + peek.repr())
                            }
                        } else {
                            switch ch {
                                case '\\' = {
                                    val escapeChar = self.next()
                                    union self.fromEscapeChar(escapeChar) {
                                        case set(escapedSet) = set.addAll(escapedSet)
                                        case char(c) = set.add(c.toInt())
                                        default = throw self.err(
                                            "Invalid escape in character class: " + escapeChar.repr())
                                    }
                                }
                                default = set.add(ch.toInt())
                            }
                        }
                    }
                    Tree.set(set)
                }
                case '?'
                case '*'
                case '+'
                case '{'
                case '|'
                case ']'
                case ')' = throw self.err("Misplaced operator: " + self.peek())
                default = Tree.char(self.next())
            }
        }

        def fromEscapeChar(self: Self, ch: Char): Tree = {
            switch ch {
                case 'd' = Tree.set(Self.allDigits)
                case 'D' = Tree.set(Self.allNonDigits)
                case 'w' = Tree.set(Self.allWord)
                case 'W' = Tree.set(Self.allNonWord)
                case 's' = Tree.set(Self.allSpace)
                case 'S' = Tree.set(Self.allNonSpace)
                case '?' = Tree.char('?')
                case '*' = Tree.char('*')
                case '+' = Tree.char('+')
                case '|' = Tree.char('|')
                case '[' = Tree.char('[')
                case ']' = Tree.char(']')
                case '(' = Tree.char('(')
                case ')' = Tree.char(')')
                case '{' = Tree.char('{')
                case '}' = Tree.char('}')
                case '.' = Tree.char('.')
                case '\n' = Tree.char('\n')
                case '\\' = Tree.char('\\')
                case '0' = Tree.char('\0')
                default = throw self.err("Invalid escape char: " + ch)
            }
        }
    }
}