// Ported from markdown 1.0.0: src/util/normalize_identifier.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.util;

import haxe.io.BytesBuffer;

/**
 * Normalize identifiers (`normalize_identifier.rs`).
 */
class NormalizeIdentifier {

    /**
     * Normalize an identifier, as found in references and definitions, so it
     * can be compared when matching: collapse markdown whitespace, trim, and
     * do `to_lowercase().to_uppercase()` (Unicode, like Rust).
     */
    public static function normalizeIdentifier(value:String):String {
        var bytes = Utf8.bytesOf(value);
        var result = new BytesBuffer();
        var inWhitespace = true;
        var index = 0;
        var start = 0;
        var len = bytes.length;

        while (index < len) {
            var b = bytes.get(index);
            if (b == '\t'.code || b == '\n'.code || b == '\r'.code || b == ' '.code) {
                // First whitespace we see after non-whitespace.
                if (!inWhitespace) {
                    fold(bytes, start, index, result);
                    inWhitespace = true;
                }
            }
            // First non-whitespace we see after whitespace.
            else if (inWhitespace) {
                if (start != 0) {
                    result.addByte(' '.code);
                }

                start = index;
                inWhitespace = false;
            }

            index += 1;
        }

        if (!inWhitespace) {
            fold(bytes, start, len, result);
        }

        return Utf8.bytesToString(result.getBytes());
    }

    static function fold(bytes:haxe.io.Bytes, start:Int, end:Int, out:BytesBuffer):Void {
        var i = start;
        while (i < end) {
            var code = Utf8.codeAt(bytes, i);
            i += Utf8.seqLen(bytes.get(i));
            CaseMap.fold(code, out);
        }
    }

}
