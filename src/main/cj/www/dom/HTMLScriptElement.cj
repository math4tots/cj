package www.dom

import www.JSObject
import www.dom.HTMLElement

class HTMLScriptElement : HTMLElement {
    static val tagName = "script"
    val _obj :  JSObject
    def cls() : JSObject = js!(JSObject, "HTMLScriptElement")

    def __get_type(self: Self): String = js0!(self, ".type")

    def __get_text(self: Self): String = js0!(self, ".text")
}
