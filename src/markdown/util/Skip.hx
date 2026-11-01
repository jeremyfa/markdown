// Ported from markdown 1.0.0: src/util/skip.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.util;

import markdown.event.Event;
import markdown.event.Kind;
import markdown.event.Name;

/**
 * Move across lists of events (`skip.rs`).
 */
class Skip {

    /** Skip from `index`, optionally past `names`. */
    public static inline function opt(events:Array<Event>, index:Int, names:Array<Name>):Int {
        return skipOptImpl(events, index, names, true);
    }

    /** Skip from `index`, optionally past `names`, backwards. */
    public static inline function optBack(events:Array<Event>, index:Int, names:Array<Name>):Int {
        return skipOptImpl(events, index, names, false);
    }

    /** Skip from `index` forwards to `names`. */
    public static inline function to(events:Array<Event>, index:Int, names:Array<Name>):Int {
        return toImpl(events, index, names, true);
    }

    /** Skip from `index` backwards to `names`. */
    public static inline function toBack(events:Array<Event>, index:Int, names:Array<Name>):Int {
        return toImpl(events, index, names, false);
    }

    static function toImpl(events:Array<Event>, index:Int, names:Array<Name>, forward:Bool):Int {
        // Note: Rust's `usize` wraps below zero, which ends the loop.
        while (index >= 0 && index < events.length) {
            var current = events[index].name;
            if (names.indexOf(current) != -1) {
                break;
            }
            index = forward ? index + 1 : index - 1;
        }
        return index;
    }

    static function skipOptImpl(events:Array<Event>, index:Int, names:Array<Name>, forward:Bool):Int {
        var balance = 0;
        var open = forward ? Kind.Enter : Kind.Exit;

        while (index < events.length) {
            var current = events[index].name;

            if (names.indexOf(current) == -1 || events[index].kind != open) {
                break;
            }

            index = forward ? index + 1 : index - 1;
            balance += 1;

            while (true) {
                balance = events[index].kind == open ? balance + 1 : balance - 1;
                var next = forward ? index + 1 : (index > 0 ? index - 1 : index);

                if (events[index].name == current && balance == 0) {
                    index = next;
                    break;
                }

                index = next;
            }
        }

        return index;
    }

}
