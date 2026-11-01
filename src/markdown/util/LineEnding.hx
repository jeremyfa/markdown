// Ported from markdown 1.0.0: src/util/line_ending.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.util;

/**
 * Type of line endings in markdown (`LineEnding` in `line_ending.rs`).
 */
enum abstract LineEnding(Int) {
    /** Both a carriage return (`\r`) and a line feed (`\n`). */
    var CarriageReturnLineFeed = 0;
    /** Sole carriage return (`\r`). */
    var CarriageReturn = 1;
    /** Sole line feed (`\n`), the default. */
    var LineFeed = 2;

    /** Turn the line ending into a string. */
    public function asStr():String {
        return switch (cast this : LineEnding) {
            case CarriageReturnLineFeed: '\r\n';
            case CarriageReturn: '\r';
            case LineFeed: '\n';
        }
    }

    /** `FromStr`: throws `Expected CR, LF, or CRLF` on other values. */
    public static function fromStr(s:String):LineEnding {
        return switch s {
            case '\r\n': CarriageReturnLineFeed;
            case '\r': CarriageReturn;
            case '\n': LineFeed;
            default: throw 'Expected CR, LF, or CRLF';
        }
    }
}
