package www.dom

import www.dom.DOMRect
import www.dom.Node

trait Element : Node {
    def __get_tagName(): String
    def __get_innerHTML(self): String = js0!(self, ".innerHTML")
    def __set_innerHTML(self, html: String) =  js0!(self, ".innerHTML=", html)
    def getBoundingClientRect(self): DOMRect = js0!(self, ".getBoundingClientRect()")
    def __get_clientWidth(self): Int = js0!(self, ".clientWidth")
    def __get_clientHeight(self): Int = js0!(self, ".clientHeight")
}
