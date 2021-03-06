function cj$Char$repr(self) {
    return "'" + String.fromCodePoint(self).replace(/\n|\r|\t|[\x00-\x1E]|"/g, m => {
        switch (m) {
            case '\0': return "\\0";
            case '\n': return "\\n";
            case '\r': return "\\r";
            case '\t': return "\\t";
            case "'": return "\\'";
            default:
                const ch = m.codePointAt(0);
                if (ch < 32) {
                    const rawStr = ch.toString(16);
                    return "\\x" + rawStr.length < 2 ? '0'.repeat(2 - rawStr.length) + rawStr : rawStr;
                } else {
                    const rawStr = ch.toString(16);
                    return "\\u" + rawStr.length < 4 ? '0'.repeat(4 - rawStr.length) + rawStr : rawStr;
                }
        }
    }) + "'";
}
