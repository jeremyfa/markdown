// Part of the Haxe port of markdown 1.0.0 (markdown-rs by Titus Wormer, MIT).
// UTF-8 helpers replacing Rust's `str` / `char` conversions. See README.md.

package markdown.util;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;

/**
 * UTF-8 helpers: the port works on UTF-8 bytes like upstream.
 */
class Utf8 {

    /** UTF-8 bytes of a Haxe string. */
    public static inline function bytesOf(value:String):Bytes {
        return Bytes.ofString(value, UTF8);
    }

    /** Decode the UTF-8 bytes `start` (inclusive) to `end` (exclusive) as a Haxe string. */
    public static function slice(bytes:Bytes, start:Int, end:Int):String {
        if (end <= start)
            return '';
        // `Bytes.getString` stops at a NUL byte on some targets: decode by hand then.
        var i = start;
        while (i < end) {
            if (bytes.get(i) == 0)
                return decodeWithNul(bytes, start, end);
            i++;
        }
        return bytes.getString(start, end - start, UTF8);
    }

    /** Decode UTF-8 bytes as a Haxe string. */
    public static inline function bytesToString(bytes:Bytes):String {
        return slice(bytes, 0, bytes.length);
    }

    static function decodeWithNul(bytes:Bytes, start:Int, end:Int):String {
        var b = new StringBuf();
        for (code in decodeLossy(bytes, start, end))
            b.addChar(code);
        return b.toString();
    }

    /** Length in bytes of the UTF-8 encoding of a Haxe string. */
    public static function byteLength(value:String):Int {
        #if js
        var len = 0;
        var i = 0;
        var n = value.length;
        while (i < n) {
            var c = StringTools.fastCodeAt(value, i);
            if (c < 0x80) len += 1;
            else if (c < 0x800) len += 2;
            else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < n) {
                len += 4;
                i++;
            }
            else len += 3;
            i++;
        }
        return len;
        #else
        return Bytes.ofString(value, UTF8).length;
        #end
    }

    /** Append a code point as UTF-8. */
    public static function addCode(out:BytesBuffer, code:Int):Void {
        if (code < 0x80) {
            out.addByte(code);
        }
        else if (code < 0x800) {
            out.addByte(0xC0 | (code >> 6));
            out.addByte(0x80 | (code & 0x3F));
        }
        else if (code < 0x10000) {
            out.addByte(0xE0 | (code >> 12));
            out.addByte(0x80 | ((code >> 6) & 0x3F));
            out.addByte(0x80 | (code & 0x3F));
        }
        else {
            out.addByte(0xF0 | (code >> 18));
            out.addByte(0x80 | ((code >> 12) & 0x3F));
            out.addByte(0x80 | ((code >> 6) & 0x3F));
            out.addByte(0x80 | (code & 0x3F));
        }
    }

    /** Haxe string of one code point. */
    public static function fromCode(code:Int):String {
        var b = new BytesBuffer();
        addCode(b, code);
        return bytesToString(b.getBytes());
    }

    /**
     * Decode `bytes[start..end]` like Rust's `String::from_utf8_lossy`
     * (one U+FFFD per maximal invalid subpart), as code points.
     */
    public static function decodeLossy(bytes:Bytes, start:Int, end:Int):Array<Int> {
        var result:Array<Int> = [];
        var i = start;
        while (i < end) {
            var b = bytes.get(i);
            if (b < 0x80) {
                result.push(b);
                i++;
                continue;
            }
            var need = 0;
            var lo = 0x80;
            var hi = 0xBF;
            var code = 0;
            if (b >= 0xC2 && b <= 0xDF) {
                need = 1;
                code = b & 0x1F;
            }
            else if (b >= 0xE0 && b <= 0xEF) {
                need = 2;
                code = b & 0x0F;
                if (b == 0xE0) lo = 0xA0;
                if (b == 0xED) hi = 0x9F;
            }
            else if (b >= 0xF0 && b <= 0xF4) {
                need = 3;
                code = b & 0x07;
                if (b == 0xF0) lo = 0x90;
                if (b == 0xF4) hi = 0x8F;
            }
            else {
                result.push(0xFFFD);
                i++;
                continue;
            }
            var j = i + 1;
            var k = 0;
            var complete = true;
            while (k < need) {
                if (j < end) {
                    var c = bytes.get(j);
                    if (c >= lo && c <= hi) {
                        code = (code << 6) | (c & 0x3F);
                        j++;
                        k++;
                        lo = 0x80;
                        hi = 0xBF;
                        continue;
                    }
                }
                complete = false;
                break;
            }
            result.push(complete ? code : 0xFFFD);
            i = j;
        }
        return result;
    }

    /** Decode the code point starting at `index` of valid UTF-8 (`-1` at the end). */
    public static function codeAt(bytes:Bytes, index:Int):Int {
        if (index >= bytes.length)
            return -1;
        var b = bytes.get(index);
        if (b < 0x80) return b;
        if (b < 0xE0) return ((b & 0x1F) << 6) | (bytes.get(index + 1) & 0x3F);
        if (b < 0xF0) return ((b & 0x0F) << 12) | ((bytes.get(index + 1) & 0x3F) << 6) | (bytes.get(index + 2) & 0x3F);
        return ((b & 0x07) << 18) | ((bytes.get(index + 1) & 0x3F) << 12) | ((bytes.get(index + 2) & 0x3F) << 6) | (bytes.get(index + 3) & 0x3F);
    }

    /** Byte length of the UTF-8 sequence starting with `b`. */
    public static inline function seqLen(b:Int):Int {
        return b < 0x80 ? 1 : b < 0xE0 ? 2 : b < 0xF0 ? 3 : 4;
    }

    /** Code points of a Haxe string. */
    public static function codes(value:String):Array<Int> {
        var bytes = bytesOf(value);
        var result = [];
        var i = 0;
        while (i < bytes.length) {
            result.push(codeAt(bytes, i));
            i += seqLen(bytes.get(i));
        }
        return result;
    }

}
