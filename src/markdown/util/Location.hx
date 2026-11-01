// Ported from markdown 1.0.0: src/util/location.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.util;

import haxe.io.Bytes;
import markdown.unist.Point;

/**
 * Info on where things are in a document (`Location` in `location.rs`).
 * Stops are pairs of relative and absolute offsets, flattened.
 */
class Location {

    /** List, where each index is a line number (0-indexed), and each value is the byte index where that line starts. */
    var indices:Array<Int> = [];

    /** Get an index for the given `bytes`. */
    public function new(bytes:Bytes) {
        var index = 0;
        var len = bytes.length;
        while (index < len) {
            if (bytes.get(index) == '\r'.code) {
                if (index + 1 < len && bytes.get(index + 1) == '\n'.code) {
                    indices.push(index + 2);
                    index += 1;
                }
                else {
                    indices.push(index + 1);
                }
            }
            else if (bytes.get(index) == '\n'.code) {
                indices.push(index + 1);
            }
            index += 1;
        }
        indices.push(index + 1);
    }

    /** Get the line and column-based `point` for `offset` in the bound indices (`null` when out of bounds). */
    public function toPoint(offset:Int):Null<Point> {
        var index = 0;
        if (indices.length > 0) {
            var end = indices[indices.length - 1];
            if (offset < end) {
                while (index < indices.length) {
                    if (indices[index] > offset) {
                        break;
                    }
                    index += 1;
                }
                var previous = index > 0 ? indices[index - 1] : 0;
                return new Point(index + 1, offset + 1 - previous, offset);
            }
        }
        return null;
    }

    /** Like `toPoint`, but takes a relative offset from a certain string instead of an absolute offset into the whole document. */
    public function relativeToPoint(stops:Array<Int>, relative:Int):Null<Point> {
        var absolute = relativeToAbsolute(stops, relative);
        return absolute == -1 ? null : toPoint(absolute);
    }

    /** Turn a relative offset into an absolute offset (`-1` for `None`). */
    public static function relativeToAbsolute(stops:Array<Int>, relative:Int):Int {
        var index = 0;
        var count = stops.length >> 1;
        while (index < count && stops[index * 2] <= relative) {
            index += 1;
        }
        // There are no points: that only occurs if there was an empty string.
        if (index == 0) {
            return -1;
        }
        else {
            var stopRelative = stops[(index - 1) * 2];
            var stopAbsolute = stops[(index - 1) * 2 + 1];
            return stopAbsolute + (relative - stopRelative);
        }
    }

}
