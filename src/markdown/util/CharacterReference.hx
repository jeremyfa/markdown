// Ported from markdown 1.0.0: src/util/character_reference.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.util;

import haxe.ds.StringMap;

/**
 * Helpers for character references (`character_reference.rs`).
 */
class CharacterReference {

    static var html5:StringMap<String> = null;
    static var html4:StringMap<String> = null;

    static function build(list:Array<String>):StringMap<String> {
        var map = new StringMap<String>();
        var i = list.length - 2;
        // Walk backwards so that the first pair wins, like `find`.
        while (i >= 0) {
            map.set(list[i], list[i + 1]);
            i -= 2;
        }
        return map;
    }

    /** Decode named character references (`null` when not found). */
    public static function decodeNamed(value:String, isHtml5:Bool):Null<String> {
        if (isHtml5) {
            if (html5 == null)
                html5 = build(Constant.CHARACTER_REFERENCES);
            return html5.get(value);
        }
        else {
            if (html4 == null)
                html4 = build(Constant.CHARACTER_REFERENCES_HTML_4);
            return html4.get(value);
        }
    }

    /** Decode numeric character references. */
    public static function decodeNumeric(value:String, radix:Int):String {
        var code = 0;
        var overflow = false;
        for (i in 0...value.length) {
            var c = StringTools.fastCodeAt(value, i);
            var d = c >= '0'.code && c <= '9'.code ? c - '0'.code : c >= 'a'.code && c <= 'f'.code ? c - 'a'.code + 10 : c - 'A'.code + 10;
            code = code * radix + d;
            if (code > 0x10FFFF)
                overflow = true;
        }
        if (!overflow && !(code >= 0xD800 && code <= 0xDFFF)) {
            if (!((code >= 0 && code <= 0x08) || code == 0x0B || (code >= 0x0E && code <= 0x1F) || (code >= 0x7F && code <= 0x9F))) {
                return Utf8.fromCode(code);
            }
        }
        return '\u{FFFD}';
    }

    /** Decode a character reference. */
    public static function decode(value:String, marker:Int, isHtml5:Bool):Null<String> {
        return switch marker {
            case '#'.code: decodeNumeric(value, 10);
            case 'x'.code: decodeNumeric(value, 16);
            case '&'.code: decodeNamed(value, isHtml5);
            default: throw 'Unexpected marker `' + marker + '`';
        }
    }

    /** Get the maximum size of a value for different kinds of references. */
    public static function valueMax(marker:Int):Int {
        return switch marker {
            case '&'.code: Constant.CHARACTER_REFERENCE_NAMED_SIZE_MAX;
            case 'x'.code: Constant.CHARACTER_REFERENCE_HEXADECIMAL_SIZE_MAX;
            case '#'.code: Constant.CHARACTER_REFERENCE_DECIMAL_SIZE_MAX;
            default: throw 'Unexpected marker `' + marker + '`';
        }
    }

    /** Check if a byte is allowed in the value of a reference of this kind. */
    public static function valueTest(marker:Int, byte:Int):Bool {
        return switch marker {
            case '&'.code: CharUtil.isAsciiAlphanumeric(byte);
            case 'x'.code: CharUtil.isAsciiHexdigit(byte);
            case '#'.code: CharUtil.isAsciiDigit(byte);
            default: throw 'Unexpected marker `' + marker + '`';
        }
    }

    /** Decode character references in a string (HTML 4 names only). */
    public static function parse(value:String):String {
        if (value.indexOf('&') == -1)
            return value;
        var bytes = Utf8.bytesOf(value);
        var index = 0;
        var len = bytes.length;
        var result = new StringBuf();
        var start = 0;

        while (index < len) {
            if (bytes.get(index) == '&'.code) {
                var marker:Int;
                var valueStart:Int;
                if (index + 1 < len && bytes.get(index + 1) == '#'.code) {
                    if (index + 2 < len && (bytes.get(index + 2) == 'x'.code || bytes.get(index + 2) == 'X'.code)) {
                        marker = 'x'.code;
                        valueStart = index + 3;
                    }
                    else {
                        marker = '#'.code;
                        valueStart = index + 2;
                    }
                }
                else {
                    marker = '&'.code;
                    valueStart = index + 1;
                }

                var max = valueMax(marker);
                var valueIndex = 0;
                while (valueIndex < max && (valueStart + valueIndex) < len) {
                    if (!valueTest(marker, bytes.get(valueStart + valueIndex))) {
                        break;
                    }
                    valueIndex += 1;
                }

                var valueEnd = valueStart + valueIndex;

                // Non empty and terminated.
                if (valueIndex > 0 && valueEnd < len && bytes.get(valueEnd) == ';'.code) {
                    var decoded = decode(bytes.getString(valueStart, valueEnd - valueStart), marker, false);
                    if (decoded != null) {
                        result.add(Utf8.slice(bytes, start, index));
                        result.add(decoded);
                        start = valueEnd + 1;
                        index = start;
                        continue;
                    }
                }
            }

            index += 1;
        }

        result.add(Utf8.slice(bytes, start, len));
        return result.toString();
    }

}
