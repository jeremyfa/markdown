// Ported from markdown 1.0.0: src/construct/partial_whitespace.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.construct;

import markdown.Resolve;
import markdown.Subresult;
import markdown.Tokenizer;
import markdown.Parser;
import markdown.event.Event;
import markdown.event.Kind;
import markdown.event.Link;
import markdown.event.Name;
import markdown.state.State;
import markdown.state.StateName;
import markdown.event.Content;
import markdown.util.Constant;
import markdown.util.Slice;

/**
 * Trailing whitespace occurs in string and text (`partial_whitespace.rs`).
 */
class PartialWhitespace {

    /** Resolve whitespace. */
    public static function resolveWhitespace(tokenizer:Tokenizer, hardBreak:Bool, trimWhole:Bool):Void {
        var index = 0;

        while (index < tokenizer.events.length) {
            var event = tokenizer.events[index];

            if (event.kind == Kind.Exit && event.name == Name.Data) {
                var trimStart = (trimWhole && index == 1) || (index > 1 && tokenizer.events[index - 2].name == Name.LineEnding);
                var trimEnd = (trimWhole && index == tokenizer.events.length - 1)
                    || (index + 1 < tokenizer.events.length && tokenizer.events[index + 1].name == Name.LineEnding);

                trimData(tokenizer, index, trimStart, trimEnd, hardBreak);
            }

            index += 1;
        }

        tokenizer.map.consume(tokenizer.events);
    }

    /** Trim a `Data` event. */
    static function trimData(tokenizer:Tokenizer, exitIndex:Int, trimStart:Bool, trimEnd:Bool, hardBreak:Bool):Void {
        var slice = Slice.fromPosition(tokenizer.parseState.bytes, SlicePosition.fromExitEvent(tokenizer.events, exitIndex));
        var bytes = slice.bytes;

        if (trimEnd) {
            var index = slice.end - slice.start;
            var spacesOnly = slice.after == 0;
            while (index > 0) {
                var b = bytes.get(slice.start + index - 1);
                if (b == ' '.code) {}
                else if (b == '\t'.code) spacesOnly = false;
                else break;
                index -= 1;
            }

            var diff = slice.end - slice.start - index;
            var name = hardBreak && spacesOnly && diff >= Constant.HARD_BREAK_PREFIX_SIZE_MIN && exitIndex + 1 < tokenizer.events.length
                ? Name.HardBreakTrailing : Name.SpaceOrTab;

            // The whole data is whitespace.
            if (index == 0) {
                tokenizer.events[exitIndex - 1].name = name;
                tokenizer.events[exitIndex].name = name;
                return;
            }

            if (diff > 0 || slice.after > 0) {
                var exitPoint = tokenizer.events[exitIndex].point.clone();
                var enterPoint = exitPoint.clone();
                enterPoint.index -= diff;
                enterPoint.column -= diff;
                enterPoint.vs = 0;

                tokenizer.map.add(exitIndex + 1, 0, [
                    new Event(Kind.Enter, name, enterPoint.clone(), null),
                    new Event(Kind.Exit, name, exitPoint, null),
                ]);

                tokenizer.events[exitIndex].point = enterPoint;
                slice.end = slice.start + index;
            }
        }

        if (trimStart) {
            var index = 0;
            var len = slice.end - slice.start;
            while (index < len) {
                var b = bytes.get(slice.start + index);
                if (b == ' '.code || b == '\t'.code)
                    index += 1;
                else
                    break;
            }

            // The whole data is whitespace.
            if (index == len) {
                tokenizer.events[exitIndex - 1].name = Name.SpaceOrTab;
                tokenizer.events[exitIndex].name = Name.SpaceOrTab;
                return;
            }

            if (index > 0 || slice.before > 0) {
                var enterPoint = tokenizer.events[exitIndex - 1].point.clone();
                var exitPoint = enterPoint.clone();
                exitPoint.index += index;
                exitPoint.column += index;
                exitPoint.vs = 0;

                tokenizer.map.add(exitIndex - 1, 0, [
                    new Event(Kind.Enter, Name.SpaceOrTab, enterPoint, null),
                    new Event(Kind.Exit, Name.SpaceOrTab, exitPoint.clone(), null),
                ]);

                tokenizer.events[exitIndex - 1].point = exitPoint;
            }
        }
    }

}
