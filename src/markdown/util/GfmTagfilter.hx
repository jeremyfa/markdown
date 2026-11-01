// Ported from markdown 1.0.0: src/util/gfm_tagfilter.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.util;

/**
 * Make dangerous HTML a tiny bit safer (`gfm_tagfilter.rs`).
 */
class GfmTagfilter {

    /** Make dangerous HTML a tiny bit safer. */
    public static function gfmTagfilter(value:String):String {
        var len = value.length;
        var result:StringBuf = null;
        var index = 0;
        var start = 0;

        while (index < len) {
            if (StringTools.fastCodeAt(value, index) == '<'.code) {
                var nameStart = index + 1;

                // Optional `/`.
                if (nameStart < len && StringTools.fastCodeAt(value, nameStart) == '/'.code) {
                    nameStart += 1;
                }

                // Tag name.
                var nameEnd = nameStart;

                while (nameEnd < len
                    && nameEnd - nameStart < Constant.GFM_HTML_TAGFILTER_SIZE_MAX
                    && CharUtil.isAsciiAlphabetic(StringTools.fastCodeAt(value, nameEnd))) {
                    nameEnd += 1;
                }

                // Non-empty.
                if (nameEnd == len || (nameEnd != nameStart && isTagEnd(StringTools.fastCodeAt(value, nameEnd)))) {
                    if (Constant.GFM_HTML_TAGFILTER_NAMES.indexOf(CharUtil.asciiLowercase(value.substring(nameStart, nameEnd))) != -1) {
                        if (result == null)
                            result = new StringBuf();
                        result.addSub(value, start, index - start);
                        result.add('&lt;');
                        start = index + 1;
                    }
                }

                // There was no `<` before `nameEnd`, so move to that next.
                index = nameEnd;
                continue;
            }

            index += 1;
        }

        if (result == null)
            return value;
        result.addSub(value, start, len - start);
        return result.toString();
    }

    static inline function isTagEnd(b:Int):Bool {
        return b == '\t'.code || b == '\n'.code || b == 12 || b == '\r'.code || b == ' '.code || b == '/'.code || b == '>'.code;
    }

}
