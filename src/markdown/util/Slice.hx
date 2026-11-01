// Ported from markdown 1.0.0: src/util/slice.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.util;

import haxe.io.Bytes;
import markdown.event.Event;
import markdown.event.Kind;
import markdown.event.Point;

/**
 * A range between two points (`Position` in `slice.rs`).
 */
class SlicePosition {
    public var start:Point;
    public var end:Point;

    public inline function new(start:Point, end:Point) {
        this.start = start;
        this.end = end;
    }

    /** Get a position from an exit event. */
    public static function fromExitEvent(events:Array<Event>, index:Int):SlicePosition {
        var end = events[index].point;
        var name = events[index].name;
        var index = index - 1;
        while (!(events[index].kind == Kind.Enter && events[index].name == name)) {
            index -= 1;
        }
        var start = events[index].point;
        return new SlicePosition(start, end);
    }
}

/**
 * Bytes belonging to a range (`Slice` in `slice.rs`): `bytes[start..end]`,
 * with extra virtual spaces `before` and `after`.
 */
class Slice {
    public var bytes:Bytes;
    public var start:Int;
    public var end:Int;
    public var before:Int;
    public var after:Int;

    public inline function new(bytes:Bytes, start:Int, end:Int, before:Int, after:Int) {
        this.bytes = bytes;
        this.start = start;
        this.end = end;
        this.before = before;
        this.after = after;
    }

    /** Get a slice for a position. */
    public static function fromPosition(bytes:Bytes, position:SlicePosition):Slice {
        var before = position.start.vs;
        var after = position.end.vs;
        var start = position.start.index;
        var end = position.end.index;

        // If we have virtual spaces before, it means we are past the actual
        // character at that index, and those virtual spaces.
        if (before > 0) {
            before = Constant.TAB_SIZE - before;
            start += 1;
        }

        // If we have virtual spaces after, it means that character is included,
        // and one less virtual space.
        if (after > 0) {
            after -= 1;
            end += 1;
        }

        return new Slice(bytes, start, end, before, after);
    }

    /** Get a slice for two points. */
    public static inline function fromPoints(bytes:Bytes, start:Point, end:Point):Slice {
        return fromPosition(bytes, new SlicePosition(start, end));
    }

    /** Get a slice for two indices. */
    public static inline function fromIndices(bytes:Bytes, start:Int, end:Int):Slice {
        return new Slice(bytes, start, end, 0, 0);
    }

    /** Get the size of this slice, including virtual spaces. */
    public inline function len():Int {
        return end - start + before + after;
    }

    /** Byte at `index` (relative to the slice start). */
    public inline function byteAt(index:Int):Int {
        return bytes.get(start + index);
    }

    /** Number of real bytes. */
    public inline function bytesLen():Int {
        return end - start;
    }

    /** Turn the slice into a string (without virtual spaces). */
    public inline function asStr():String {
        return Utf8.slice(bytes, start, end);
    }

    /** Turn the slice into a string, including virtual spaces. */
    public function serialize():String {
        var prefix = StringTools.rpad('', ' ', before);
        var suffix = StringTools.rpad('', ' ', after);
        return prefix + asStr() + suffix;
    }
}
