// Ported from markdown 1.0.0: src/parser.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown;

import haxe.io.Bytes;
import markdown.event.Event;
import markdown.event.Point;
import markdown.state.State;
import markdown.state.StateName;
import markdown.util.Location;

/**
 * Info needed, in all content types, when parsing markdown (`ParseState`).
 */
class ParseState {
    /** Configuration. */
    public var location:Null<Location>;
    public var options:ParseOptions;
    /** List of chars. */
    public var bytes:Bytes;
    /** Set of defined definition identifiers. */
    public var definitions:Array<String> = [];
    /** Set of defined GFM footnote definition identifiers. */
    public var gfmFootnoteDefinitions:Array<String> = [];

    public function new(options:ParseOptions, bytes:Bytes, location:Null<Location>) {
        this.options = options;
        this.bytes = bytes;
        this.location = location;
    }
}

/** Result of `Parser.parse`. */
class ParseResult {
    public var events:Array<Event>;
    public var parseState:ParseState;

    public inline function new(events:Array<Event>, parseState:ParseState) {
        this.events = events;
        this.parseState = parseState;
    }
}

class Parser {

    /** Turn a string of markdown into events. Throws a `Message` on error. */
    public static function parse(value:Bytes, options:ParseOptions):ParseResult {
        var bytes = value;
        var parseState = new ParseState(options, bytes,
            options.mdxEsmParse != null || options.mdxExpressionParse != null ? new Location(bytes) : null);

        var start = new Point(1, 1, 0, 0);
        var tokenizer = new Tokenizer(start, parseState);

        var state = tokenizer.push(0, 0, bytes.length, 0, State.Next(StateName.DocumentStart));
        var result = tokenizer.flush(state, true);
        var events = tokenizer.events;

        while (true) {
            for (d in result.gfmFootnoteDefinitions)
                parseState.gfmFootnoteDefinitions.push(d);
            for (d in result.definitions)
                parseState.definitions.push(d);

            if (result.done) {
                return new ParseResult(events, parseState);
            }

            result = Subtokenize.subtokenize(events, parseState, null);
        }
    }

}
