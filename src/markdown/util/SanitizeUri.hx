// Ported from markdown 1.0.0: src/util/sanitize_uri.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.util;

/**
 * Make urls safe (`sanitize_uri.rs`).
 */
class SanitizeUri {

    /** Make a value safe for injection as a URL. */
    public static function sanitize(value:String):String {
        return Encode.encode(normalize(value), true);
    }

    /** Make a value safe for injection as a URL, and check protocols (`""` when unsafe). */
    public static function sanitizeWithProtocols(value:String, protocols:Array<String>):String {
        var value = sanitize(value);

        var end = -1;
        for (i in 0...value.length) {
            var c = StringTools.fastCodeAt(value, i);
            if (c == '?'.code || c == '#'.code || c == '/'.code) {
                end = i;
                break;
            }
        }
        var colon = value.indexOf(':');

        // If the first colon is after `?`, `#`, or `/`, it's not a protocol.
        if (end != -1 && colon != -1 && colon > end) {
            colon = -1;
        }

        // If there is no protocol, it's relative, and fine.
        if (colon != -1) {
            // If it is a protocol, it should be allowed.
            var protocol = CharUtil.asciiLowercase(value.substring(0, colon));
            if (protocols.indexOf(protocol) == -1) {
                return '';
            }
        }

        return value;
    }

    /** Normalize a URL (such as used in definitions). */
    static function normalize(value:String):String {
        var bytes = Utf8.bytesOf(value);
        var len = bytes.length;
        var result = new StringBuf();
        var index = 0;
        var start = 0;
        var changed = false;

        while (index < len) {
            var char = bytes.get(index);

            // Already percent encoded: skip it.
            if (char == '%'.code
                && index + 2 < len
                && CharUtil.isAsciiAlphanumeric(bytes.get(index + 1))
                && CharUtil.isAsciiAlphanumeric(bytes.get(index + 2))) {
                index += 3;
                continue;
            }

            if (char >= 0x80 || !(char == '!'.code || char == '#'.code || char == '$'.code
                || (char >= '&'.code && char <= ';'.code) || char == '='.code
                || (char >= '?'.code && char <= 'Z'.code) || char == '_'.code
                || (char >= 'a'.code && char <= 'z'.code) || char == '~'.code)) {
                changed = true;
                if (index > start)
                    result.add(bytes.getString(start, index - start));
                var hex = StringTools.hex(char, 2);
                result.add('%' + hex);
                start = index + 1;
            }

            index += 1;
        }

        if (!changed)
            return value;
        if (len > start)
            result.add(bytes.getString(start, len - start));
        return result.toString();
    }

}
