// Ported from markdown 1.0.0: src/event.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.event;

import haxe.io.Bytes;
import markdown.util.Constant;

/**
 * A location in the document (`Point` in `event.rs`): `line`, `column`,
 * `index` (UTF-8 byte offset) and `vs` (virtual spaces, used for tabs).
 */
class Point {

    public var line:Int;
    public var column:Int;
    public var index:Int;
    public var vs:Int;

    public inline function new(line:Int, column:Int, index:Int, vs:Int) {
        this.line = line;
        this.column = column;
        this.index = index;
        this.vs = vs;
    }

    public inline function clone():Point {
        return new Point(line, column, index, vs);
    }

    /** Create a unist point. */
    public inline function toUnist():markdown.unist.Point {
        return new markdown.unist.Point(line, column, index);
    }

    /**
     * Create a new point, that is shifted from the close earlier current
     * point, to `index`. Cannot move past line endings.
     */
    public function shiftTo(bytes:Bytes, index:Int):Point {
        var next = clone();
        while (next.index < index) {
            switch bytes.get(next.index) {
                case '\n'.code | '\r'.code:
                    throw 'cannot move past line endings';
                case '\t'.code:
                    var remainder = next.column % Constant.TAB_SIZE;
                    var vs = remainder == 0 ? 0 : Constant.TAB_SIZE - remainder;
                    next.index += 1;
                    next.column += 1 + vs;
                default:
                    next.index += 1;
                    next.column += 1;
            }
        }
        return next;
    }

}
