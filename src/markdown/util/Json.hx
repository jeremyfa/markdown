// Part of the Haxe port of markdown 1.0.0 (markdown-rs by Titus Wormer, MIT).
// Writes JSON exactly like serde_json does. See README.md.

package markdown.util;

/**
 * JSON helpers matching serde_json's output.
 */
class Json {

    /** A JSON string literal, escaped like serde_json. */
    public static function quote(value:String):String {
        var b = new StringBuf();
        addQuoted(b, value);
        return b.toString();
    }

    /** `null` or a JSON string literal. */
    public static inline function quoteOpt(value:Null<String>):String {
        return value == null ? 'null' : quote(value);
    }

    /** Append a JSON string literal, escaped like serde_json. */
    public static function addQuoted(b:StringBuf, value:String):Void {
        b.addChar('"'.code);
        var start = 0;
        var len = value.length;
        for (i in 0...len) {
            var c = StringTools.fastCodeAt(value, i);
            if (c < 0x20 || c == '"'.code || c == '\\'.code) {
                if (i > start)
                    b.addSub(value, start, i - start);
                start = i + 1;
                switch c {
                    case '"'.code: b.add('\\"');
                    case '\\'.code: b.add('\\\\');
                    case '\n'.code: b.add('\\n');
                    case '\r'.code: b.add('\\r');
                    case '\t'.code: b.add('\\t');
                    case 0x08: b.add('\\b');
                    case 0x0C: b.add('\\f');
                    default:
                        b.add('\\u00');
                        b.add(StringTools.hex(c, 2).toLowerCase());
                }
            }
        }
        if (len > start)
            b.addSub(value, start, len - start);
        b.addChar('"'.code);
    }

    /**
     * Re-indent compact JSON (as written by `toJson`) like
     * `serde_json::to_string_pretty`: two spaces, `": "`, empty arrays and
     * objects as `[]` and `{}`.
     */
    public static function pretty(compact:String):String {
        var b = new StringBuf();
        var depth = 0;
        var i = 0;
        var len = compact.length;
        inline function newline() {
            b.addChar('\n'.code);
            for (_ in 0...depth)
                b.add('  ');
        }
        while (i < len) {
            var c = StringTools.fastCodeAt(compact, i);
            if (c == '"'.code) {
                var start = i;
                i++;
                while (i < len) {
                    var d = StringTools.fastCodeAt(compact, i);
                    if (d == '\\'.code) {
                        i += 2;
                        continue;
                    }
                    i++;
                    if (d == '"'.code)
                        break;
                }
                b.addSub(compact, start, i - start);
                continue;
            }
            if (c == '{'.code || c == '['.code) {
                var close = c == '{'.code ? '}'.code : ']'.code;
                if (i + 1 < len && StringTools.fastCodeAt(compact, i + 1) == close) {
                    b.addChar(c);
                    b.addChar(close);
                    i += 2;
                    continue;
                }
                b.addChar(c);
                depth++;
                newline();
            }
            else if (c == '}'.code || c == ']'.code) {
                depth--;
                newline();
                b.addChar(c);
            }
            else if (c == ','.code) {
                b.addChar(c);
                newline();
            }
            else if (c == ':'.code) {
                b.add(': ');
            }
            else {
                b.addChar(c);
            }
            i++;
        }
        return b.toString();
    }

}
