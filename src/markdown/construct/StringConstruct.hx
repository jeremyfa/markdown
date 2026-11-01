// Ported from markdown 1.0.0: src/construct/string.rs
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
 * The string content type (`string.rs`).
 */
class StringConstruct {

    /** Characters that can start something in string. */
    static final MARKERS:Array<Bool> = TokenizeState.markerTable(['&'.code, '\\'.code]);

    /** Start of string. */
    public static function start(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.markers = MARKERS;
        return State.Retry(StateName.StringBefore);
    }

    /** Before string. */
    public static function before(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1:
                tokenizer.registerResolver(ResolveName.Data);
                tokenizer.registerResolver(ResolveName.String);
                return State.Ok;
            case '&'.code:
                tokenizer.attempt(State.Next(StateName.StringBefore), State.Next(StateName.StringBeforeData));
                return State.Retry(StateName.CharacterReferenceStart);
            case '\\'.code:
                tokenizer.attempt(State.Next(StateName.StringBefore), State.Next(StateName.StringBeforeData));
                return State.Retry(StateName.CharacterEscapeStart);
            default:
                return State.Retry(StateName.StringBeforeData);
        }
    }

    /** At data. */
    public static function beforeData(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.StringBefore), State.Nok);
        return State.Retry(StateName.DataStart);
    }

    /** Resolve whitespace in string. */
    public static function resolve(tokenizer:Tokenizer):Null<Subresult> {
        PartialWhitespace.resolveWhitespace(tokenizer, false, false);
        return null;
    }

}
