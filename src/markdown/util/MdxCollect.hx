// Ported from markdown 1.0.0: src/util/mdx_collect.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.util;

import haxe.io.Bytes;
import markdown.event.Event;
import markdown.event.Kind;
import markdown.event.Name;

/** Result of `MdxCollect.collect`: the value and its stops (pairs of relative and absolute offsets, flattened). */
class MdxCollectResult {
    public var value:String;
    public var stops:Array<Int>;

    public inline function new(value:String, stops:Array<Int>) {
        this.value = value;
        this.stops = stops;
    }
}

/**
 * Collect info for MDX (`mdx_collect.rs`). Relative offsets in `stops` are
 * UTF-8 byte offsets in `value`, like upstream.
 */
class MdxCollect {

    public static function collect(events:Array<Event>, bytes:Bytes, from:Int, names:Array<Name>, stop:Array<Name>):MdxCollectResult {
        var value = new StringBuf();
        var valueLen = 0;
        var stops:Array<Int> = [];
        var index = from;

        while (index < events.length) {
            if (events[index].kind == Kind.Enter) {
                if (names.indexOf(events[index].name) != -1) {
                    // Include virtual spaces, and assume void.
                    var slice = Slice.fromPoints(bytes, events[index].point, events[index + 1].point);
                    stops.push(valueLen);
                    stops.push(events[index].point.index);
                    value.add(slice.serialize());
                    valueLen += slice.len();
                }
            }
            else if (stop.indexOf(events[index].name) != -1) {
                break;
            }

            index += 1;
        }

        return new MdxCollectResult(value.toString(), stops);
    }

}
