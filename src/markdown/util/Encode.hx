// Ported from markdown 1.0.0: src/util/encode.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.util;

/**
 * Encode HTML (`encode.rs`).
 */
class Encode {

    /** Encode dangerous html characters: `\0` always, and `&`, `"`, `<`, `>` when `encodeHtml`. */
    public static function encode(value:String, encodeHtml:Bool):String {
        var len = value.length;
        var index = 0;
        var start = 0;
        var result:StringBuf = null;

        while (index < len) {
            var byte = StringTools.fastCodeAt(value, index);
            if (byte == 0 || (encodeHtml && (byte == '&'.code || byte == '"'.code || byte == '<'.code || byte == '>'.code))) {
                if (result == null)
                    result = new StringBuf();
                result.addSub(value, start, index - start);
                result.add(switch byte {
                    case 0: '\u{FFFD}';
                    case '&'.code: '&amp;';
                    case '"'.code: '&quot;';
                    case '<'.code: '&lt;';
                    default: '&gt;';
                });
                start = index + 1;
            }
            index += 1;
        }

        if (result == null)
            return value;
        result.addSub(value, start, len - start);
        return result.toString();
    }

}
