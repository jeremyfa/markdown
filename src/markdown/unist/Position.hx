// Ported from markdown 1.0.0: src/unist.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.unist;

/**
 * Location of a node in a source file (`Position` in `unist.rs`).
 */
class Position {

    public var start:Point;
    public var end:Point;

    public inline function new(start:Point, end:Point) {
        this.start = start;
        this.end = end;
    }

    /** `Position::new(start_line, start_column, start_offset, end_line, end_column, end_offset)`. */
    public static inline function of(startLine:Int, startColumn:Int, startOffset:Int, endLine:Int, endColumn:Int, endOffset:Int):Position {
        return new Position(new Point(startLine, startColumn, startOffset), new Point(endLine, endColumn, endOffset));
    }

    public inline function clone():Position {
        return new Position(start.clone(), end.clone());
    }

    public function equals(other:Position):Bool {
        return other != null && start.equals(other.start) && end.equals(other.end);
    }

    /** Same as Rust's `Debug` output: `1:1-1:4 (0-3)`. */
    public function toString():String {
        return start.line + ':' + start.column + '-' + end.line + ':' + end.column + ' (' + start.offset + '-' + end.offset + ')';
    }

}
