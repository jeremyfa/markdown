// Ported from markdown 1.0.0: src/util/edit_map.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.util;

import markdown.event.Event;

/**
 * Deal with several changes in events, batching them together
 * (`EditMap` in `edit_map.rs`).
 */
class EditMap {

    /** Record of changes: index, remove count, events to add. */
    var mapAt:Array<Int> = [];
    var mapRemove:Array<Int> = [];
    var mapAdd:Array<Array<Event>> = [];
    /** Index of each `at` in the arrays above (upstream scans the list, same result). */
    var mapIndex:haxe.ds.IntMap<Int> = new haxe.ds.IntMap();

    public function new() {}

    /** Create an edit: a remove and/or add at a certain place. */
    public inline function add(index:Int, remove:Int, add:Array<Event>):Void {
        addImpl(index, remove, add, false);
    }

    /** Create an edit: but insert `add` before existing additions. */
    public inline function addBefore(index:Int, remove:Int, add:Array<Event>):Void {
        addImpl(index, remove, add, true);
    }

    /** Done, change the events. */
    public function consume(events:Array<Event>):Void {
        if (mapAt.length == 0) {
            return;
        }

        // Sort by index (indices are unique).
        var order = [for (i in 0...mapAt.length) i];
        order.sort((a, b) -> mapAt[a] - mapAt[b]);
        var at = [for (i in order) mapAt[i]];
        var remove = [for (i in order) mapRemove[i]];
        var adds = [for (i in order) mapAdd[i]];

        // Calculate jumps: where items in the current list move to.
        var jumps:Array<Int> = [];
        var index = 0;
        var addAcc = 0;
        var removeAcc = 0;
        while (index < at.length) {
            removeAcc += remove[index];
            addAcc += adds[index].length;
            jumps.push(at[index]);
            jumps.push(removeAcc);
            jumps.push(addAcc);
            index += 1;
        }

        shiftLinks(events, jumps);

        var result:Array<Event> = [];
        var start = 0;
        index = 0;
        while (index < at.length) {
            var i = start;
            var end = at[index];
            while (i < end) {
                result.push(events[i]);
                i++;
            }
            for (e in adds[index])
                result.push(e);
            start = at[index] + remove[index];
            index += 1;
        }
        var i = start;
        while (i < events.length) {
            result.push(events[i]);
            i++;
        }

        // Replace the content of `events` in place.
        var len = result.length;
        if (events.length > len)
            events.resize(len);
        for (j in 0...len)
            events[j] = result[j];

        mapAt = [];
        mapRemove = [];
        mapAdd = [];
        mapIndex = new haxe.ds.IntMap();
    }

    /** Create an edit. */
    function addImpl(at:Int, remove:Int, add:Array<Event>, before:Bool):Void {
        if (remove == 0 && add.length == 0) {
            return;
        }

        var index = mapIndex.get(at);
        if (index != null) {
            mapRemove[index] += remove;
            if (before) {
                mapAdd[index] = add.concat(mapAdd[index]);
            }
            else {
                var list = mapAdd[index];
                for (e in add)
                    list.push(e);
            }
            return;
        }

        mapIndex.set(at, mapAt.length);
        mapAt.push(at);
        mapRemove.push(remove);
        mapAdd.push(add);
    }

    /** Shift `previous` and `next` links according to `jumps` (triples of index, remove, add). */
    static function shiftLinks(events:Array<Event>, jumps:Array<Int>):Void {
        var jumpIndex = 0;
        var index = 0;
        var add = 0;
        var rm = 0;
        var jumpsLen = Std.int(jumps.length / 3);

        while (index < events.length) {
            var rmCurr = rm;

            while (jumpIndex < jumpsLen && jumps[jumpIndex * 3] <= index) {
                add = jumps[jumpIndex * 3 + 2];
                rm = jumps[jumpIndex * 3 + 1];
                jumpIndex += 1;
            }

            // Ignore items that will be removed.
            if (rm > rmCurr) {
                index += rm - rmCurr;
            }
            else {
                var link = events[index].link;
                if (link != null) {
                    var next = link.next;
                    if (next != -1) {
                        events[next].link.previous = index + add - rm;

                        while (jumpIndex < jumpsLen && jumps[jumpIndex * 3] <= next) {
                            add = jumps[jumpIndex * 3 + 2];
                            rm = jumps[jumpIndex * 3 + 1];
                            jumpIndex += 1;
                        }

                        link.next = next + add - rm;
                        index = next;
                        continue;
                    }
                }

                index += 1;
            }
        }
    }

}
