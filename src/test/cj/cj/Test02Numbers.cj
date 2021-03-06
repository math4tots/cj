package cj

class Test02Numbers {

    @test
    def intOps() = {
        Assert.equal(21 + 42, 63)
        Assert.equal(21 - 42, -21)
        Assert.equal(21 * 42, 882)
        Assert.equal(21 % 42, 21)
        Assert.equal(21 // 42, 0)
        Assert.equal(21 / 42, 0.5)
        Assert.equal(+21, 21)
        Assert.equal(~21, -22)
    }

    class Foo {
        static var staticField : Int = 10
        var instanceField : Int
    }

    @test
    def augassignField() = {
        Assert.equal(Foo.staticField, 10)
        Foo.staticField += 24
        Assert.equal(Foo.staticField, 34)

        val foo = Foo.__malloc(24)
        Assert.equal(foo.instanceField, 24)
        foo.instanceField += 92
        Assert.equal(foo.instanceField, 116)
    }

    @test
    def approximate() = {
        Assert.that((1.0).approximates(1.00001, 0.001))
        Assert.approximate(1.0, 1.000001, 0.001)
        Assert.approximate(1.0, 1, 0.001)
        Assert.approximate(1.0, 1, 1e-14)
        Assert.approximate(1.0, 1.0000000000000001, 1e-14)
    }

    @test
    def plusplus() {
        var i = 3
        Assert.equal(i, 3)
        i++
        Assert.equal(i, 4)

        var j = 10
        Assert.equal(j, 10)
        j--
        Assert.equal(j, 9)
    }

    @test
    def gcd() {
        Assert.equal(Int.gcd(2, 5), 1)
        Assert.equal(Int.gcd(14, 21), 7)

        # negative numbers
        Assert.equal(Int.gcd(-14, 42), 14)
        Assert.equal(Int.gcd(14, -42), 14)
        Assert.equal(Int.gcd(-14, -42), 14)

        # misc sample cases from the internet
        # https://users-cs.au.dk/chili/PBI04/ExamplePrograms/gcd_function_test.py
        {
            Assert.equal(Int.gcd(13, 13), 13)
            Assert.equal(Int.gcd(37, 600), 1)
            Assert.equal(Int.gcd(20, 100), 20)
            Assert.equal(Int.gcd(100, 20), 20)
            Assert.equal(Int.gcd(624129, 2061517), 18913)
        }
    }
}
