// Ported from markdown 1.0.0: src/construct/hard_break_escape.rs
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
 * Hard break (escape) occurs in the text content type (`hard_break_escape.rs`).
 */
class HardBreakEscape {

    /** Start of hard break (escape). */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.hardBreakEscape && tokenizer.current == '\\'.code) {
            tokenizer.enter(Name.HardBreakEscape);
            tokenizer.consume();
            return State.Next(StateName.HardBreakEscapeAfter);
        }
        else {
            return State.Nok;
        }
    }

    /** After `\`, at eol. */
    public static function after(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\n'.code:
                tokenizer.exit(Name.HardBreakEscape);
                return State.Ok;
            default:
                return State.Nok;
        }
    }

}
