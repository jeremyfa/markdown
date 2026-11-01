// Ported from markdown 1.0.0: src/unist.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.unist;

/**
 * One place in a source file (`Point` in `unist.rs`). `offset` is a UTF-8
 * byte offset, `line` and `column` are 1-indexed (columns count bytes).
 */
class Point {

    public var line:Int;
    public var column:Int;
    public var offset:Int;

    public inline function new(line:Int, column:Int, offset:Int) {
        this.line = line;
        this.column = column;
        this.offset = offset;
    }

    public inline function clone():Point {
        return new Point(line, column, offset);
    }

    public function equals(other:Point):Bool {
        return other != null && line == other.line && column == other.column && offset == other.offset;
    }

    /** Same as Rust's `Debug` output: `1:1 (0)`. */
    public function toString():String {
        return line + ':' + column + ' (' + offset + ')';
    }

}
