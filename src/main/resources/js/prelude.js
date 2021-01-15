/**
 * Combines the hash in a way that is consistent with
 * `java.util.List.hashCode` in the Java language.
 *
 * @param {number} h1
 * @param {number} h2
 */
function combineHash(h1, h2) {
    return (((31 * h1) | 0) + h2) | 0;
}

/**
 * Asserts that the given value is not undefined
 * @param {*} x
 */
function defined(x) {
    if (x === undefined) {
        throw new Error("Assertion error");
    }
    return x;
}
