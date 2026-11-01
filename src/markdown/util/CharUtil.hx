// Ported from markdown 1.0.0: src/util/char.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.util;

import haxe.io.Bytes;

/** Character kinds (`Kind` in `char.rs`). */
enum abstract CharKind(Int) {
    /** Whitespace. */
    var Whitespace = 0;
    /** Punctuation. */
    var Punctuation = 1;
    /** Everything else. */
    var Other = 2;
}

/**
 * Deal with bytes, chars, and kinds (`char.rs`). Chars are code points,
 * `-1` stands for `None`.
 */
class CharUtil {

    /** Get the (Unicode) character before `index`. */
    public static function beforeIndex(bytes:Bytes, index:Int):Int {
        var start = index < 4 ? 0 : index - 4;
        var chars = Utf8.decodeLossy(bytes, start, index);
        return chars.length == 0 ? -1 : chars[chars.length - 1];
    }

    /** Get the (Unicode) character at `index`. */
    public static function afterIndex(bytes:Bytes, index:Int):Int {
        var end = index + 4 > bytes.length ? bytes.length : index + 4;
        var chars = Utf8.decodeLossy(bytes, index, end);
        return chars.length == 0 ? -1 : chars[0];
    }

    /** Classify a byte (or `char`). */
    public static function kindAfterIndex(bytes:Bytes, index:Int):CharKind {
        if (index == bytes.length) {
            return Whitespace;
        }
        else {
            var byte = bytes.get(index);
            if (isAsciiWhitespace(byte)) {
                return Whitespace;
            }
            else if (isAsciiPunctuation(byte)) {
                return Punctuation;
            }
            else if (isAsciiAlphanumeric(byte)) {
                return Other;
            }
            else {
                // Otherwise: seems to be an ASCII control, so it seems to be a non-ASCII `char`.
                return classifyOpt(afterIndex(bytes, index));
            }
        }
    }

    /** Classify whether a `char` represents whitespace, punctuation, or something else. */
    public static function classify(char:Int):CharKind {
        // Note: unicode whitespace is a bit different than what is used in CommonMark.
        if (Unicode.isWhitespace(char)) {
            return Whitespace;
        }
        // Unicode punctuation.
        else if (isAsciiPunctuation(char) || Unicode.isPunctuation(char)) {
            return Punctuation;
        }
        // Everything else.
        else {
            return Other;
        }
    }

    /** Like `classify`, but supports eof as whitespace. */
    public static inline function classifyOpt(char:Int):CharKind {
        return char == -1 ? Whitespace : classify(char);
    }

    /** Format an optional `char` (`none` means eof). */
    public static function formatOpt(char:Int):String {
        return char == -1 ? 'end of file' : 'character ' + format(char);
    }

    /** Format a `char`. */
    public static function format(char:Int):String {
        var hex = StringTools.hex(char);
        while (hex.length < 4)
            hex = '0' + hex;
        var representation = 'U+' + hex;
        var printable:Null<String> = if (char == '`'.code) '`` ` ``' else if (char >= '!'.code && char <= '~'.code) '`' + String.fromCharCode(char) + '`' else null;
        return printable != null ? printable + ' (' + representation + ')' : representation;
    }

    /** Format a byte (`u8`). */
    public static inline function formatByte(byte:Int):String {
        return format(byte);
    }

    // ASCII helpers (Rust's `u8::is_ascii_*`).

    public static inline function isAsciiWhitespace(b:Int):Bool {
        return b == '\t'.code || b == '\n'.code || b == 0x0C || b == '\r'.code || b == ' '.code;
    }

    public static inline function isAsciiPunctuation(b:Int):Bool {
        return (b >= 0x21 && b <= 0x2F) || (b >= 0x3A && b <= 0x40) || (b >= 0x5B && b <= 0x60) || (b >= 0x7B && b <= 0x7E);
    }

    public static inline function isAsciiAlphanumeric(b:Int):Bool {
        return (b >= '0'.code && b <= '9'.code) || (b >= 'a'.code && b <= 'z'.code) || (b >= 'A'.code && b <= 'Z'.code);
    }

    public static inline function isAsciiAlphabetic(b:Int):Bool {
        return (b >= 'a'.code && b <= 'z'.code) || (b >= 'A'.code && b <= 'Z'.code);
    }

    public static inline function isAsciiDigit(b:Int):Bool {
        return b >= '0'.code && b <= '9'.code;
    }

    public static inline function isAsciiHexdigit(b:Int):Bool {
        return (b >= '0'.code && b <= '9'.code) || (b >= 'a'.code && b <= 'f'.code) || (b >= 'A'.code && b <= 'F'.code);
    }

    public static inline function isAsciiControl(b:Int):Bool {
        return (b >= 0 && b <= 0x1F) || b == 0x7F;
    }

    public static inline function isAsciiAlphanumericOrDash(b:Int):Bool {
        return isAsciiAlphanumeric(b) || b == '-'.code;
    }

    public static inline function toAsciiLowercase(b:Int):Int {
        return b >= 'A'.code && b <= 'Z'.code ? b + 32 : b;
    }

    /** ASCII lowercase of a string (`to_ascii_lowercase`). */
    public static function asciiLowercase(value:String):String {
        var buf = new StringBuf();
        for (i in 0...value.length) {
            var c = StringTools.fastCodeAt(value, i);
            buf.addChar(c >= 'A'.code && c <= 'Z'.code ? c + 32 : c);
        }
        return buf.toString();
    }

}
