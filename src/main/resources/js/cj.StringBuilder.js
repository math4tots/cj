class MC$cj$StringBuilder {
    M$__new() {
        return [];
    }
    M$add(self, string) {
        self.push(string);
    }
    M$char(self, ch) {
        self.push(String.fromCodePoint(ch));
    }
    M$str(self, str) {
        self.push(str);
    }
    M$toString(self) {
        return self.join("");
    }
}
