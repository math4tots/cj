package cj

native class Fn4[A0?, A1?, A2?, A3?, R?] {
    @generic def call(self: Self, a0: A0, a1: A1, a2: A2, a3: A3): R = js!(
        R, self, "(", a0, ",", a1, ",", a2, ",", a3, ")")
}
