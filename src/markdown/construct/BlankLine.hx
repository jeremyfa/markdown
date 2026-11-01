// Ported from markdown 1.0.0: src/construct/blank_line.rs
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
 * Blank lines occur in the flow content type (`blank_line.rs`).
 */
class BlankLine {

    /** Start of blank line. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            tokenizer.attempt(State.Next(StateName.BlankLineAfter), State.Nok);
            return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
        }
        else {
            return State.Retry(StateName.BlankLineAfter);
        }
    }

    /** At eof/eol, after optional whitespace. */
    public static function after(tokenizer:Tokenizer):State {
        return switch tokenizer.current {
            case -1 | '\n'.code: State.Ok;
            default: State.Nok;
        }
    }

}
