// Ported from markdown 1.0.0: src/construct/partial_data.rs
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

/**
 * Data occurs in the string and text content types (`partial_data.rs`).
 */
class PartialData {

    /** At beginning of data. */
    public static function start(tokenizer:Tokenizer):State {
        // Make sure to eat the first `markers`.
        var byte = tokenizer.current;
        if (byte != -1 && tokenizer.tokenizeState.markers[byte]) {
            tokenizer.enter(Name.Data);
            tokenizer.consume();
            return State.Next(StateName.DataInside);
        }
        return State.Retry(StateName.DataAtBreak);
    }

    /** Before something. */
    public static function atBreak(tokenizer:Tokenizer):State {
        var byte = tokenizer.current;
        if (byte != -1 && !tokenizer.tokenizeState.markers[byte]) {
            if (byte == '\n'.code) {
                tokenizer.enter(Name.LineEnding);
                tokenizer.consume();
                tokenizer.exit(Name.LineEnding);
                return State.Next(StateName.DataAtBreak);
            }
            tokenizer.enter(Name.Data);
            return State.Retry(StateName.DataInside);
        }
        return State.Ok;
    }

    /** In data. */
    public static function inside(tokenizer:Tokenizer):State {
        var byte = tokenizer.current;
        if (byte != -1 && byte != '\n'.code && !tokenizer.tokenizeState.markers[byte]) {
            tokenizer.consume();
            return State.Next(StateName.DataInside);
        }
        tokenizer.exit(Name.Data);
        return State.Retry(StateName.DataAtBreak);
    }

    /** Merge adjacent data events. */
    public static function resolve(tokenizer:Tokenizer):Null<Subresult> {
        var index = 0;

        // Loop through events and merge adjacent data events.
        while (index < tokenizer.events.length) {
            var event = tokenizer.events[index];

            if (event.kind == Kind.Enter && event.name == Name.Data) {
                // Move to exit.
                index += 1;

                var exitIndex = index;

                // Find the farthest `data` event exit event.
                while (exitIndex + 1 < tokenizer.events.length && tokenizer.events[exitIndex + 1].name == Name.Data) {
                    exitIndex += 2;
                }

                if (exitIndex > index) {
                    tokenizer.map.add(index, exitIndex - index, []);
                    // Change positional info.
                    tokenizer.events[index].point = tokenizer.events[exitIndex].point.clone();
                    // Move to the end.
                    index = exitIndex;
                }
            }

            index += 1;
        }

        tokenizer.map.consume(tokenizer.events);
        return null;
    }

}
