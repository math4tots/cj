package cj

class Test07String {
    @test
    def charAndInt() = {
        {
            val i : Int = 'H'
            Assert.equal(i, 72)
            Assert.equal(65, 'A')
            Assert.equal(97, 'a')
        }
        Assert.equal('Z'.toInt(), 90)
        Assert.equal((90).toChar(), 'Z')
    }

    @test
    def unicode() = {
        {
            val s = "한글"
            Assert.equal(s.size(), '한'.size() + '글'.size())
            Assert.equal(s.charAt(0), '한')
            Assert.equal(s.charAt(0).toInt(), 0xD55C)
            Assert.equal(s.charAt('한'.size()).toInt(), 0xAE00)
        }
    }

    @test
    def nonBMP() = {
        Assert.that('👌'.size() > 1)
        {
            val s = "hello😊world"
            Assert.that(s.size() > "hello world".size())
            var i = 0
            var chars = List[Char].empty()
            while i < s.size() {
                val ch = s.charAt(i)
                chars.add(ch)
                i += ch.size()
            }
            Assert.equal(chars, [
                'h', 'e', 'l', 'l', 'o', '😊', 'w', 'o', 'r', 'l', 'd'
            ])
            Assert.equal(chars, s.iter().toList())
        }
    }

    @test
    def pad() {
        Assert.equal("hi".lpad(5, " "), "   hi")
        Assert.equal("hi".rpad(5, "0"), "hi000")
        Assert.equal("hi".rpad(1, "0"), "hi")
        Assert.equal("hi".lpad(1, "0"), "hi")
    }

    @test
    def stripChar() {
        Assert.equal("xxxasdfyyyxx".lstripChar('x'), "asdfyyyxx")
        Assert.equal("xxxasdfyyyxx".lstripChar('a'), "xxxasdfyyyxx")
        Assert.equal("xxxasdfyyyxx".rstripChar('x'), "xxxasdfyyy")
        Assert.equal("xxxasdfyyyxx".rstripChar('a'), "xxxasdfyyyxx")
    }

    @test
    def trim() {
        Assert.equal("tyouw".trim(), "tyouw")
        Assert.equal("  tyouw".trim(), "tyouw")
        Assert.equal("tyouw  ".trim(), "tyouw")
        Assert.equal("  tyouw  ".trim(), "tyouw")
        Assert.equal("  tyo uw  ".trim(), "tyo uw")
        Assert.equal("  tyo  uw  ".trim(), "tyo  uw")
    }

    @test
    def split() {
        Assert.equal("tyouw".split(","), ["tyouw"])
        Assert.equal("a,b,cdef,g".split(","), ["a", "b", "cdef", "g"])
        Assert.equal("a,b,cdef , g ".split(","), ["a", "b", "cdef ", " g "])
    }
}
