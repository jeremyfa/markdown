// Ported from markdown 1.0.0: src/construct/partial_non_lazy_continuation.rs
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
 * Non-lazy continuation (`partial_non_lazy_continuation.rs`).
 */
class PartialNonLazyContinuation {

    /** At eol, before continuation. */
    public static function start(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\n'.code:
                tokenizer.enter(Name.LineEnding);
                tokenizer.consume();
                tokenizer.exit(Name.LineEnding);
                return State.Next(StateName.NonLazyContinuationAfter);
            default:
                return State.Nok;
        }
    }

    /** A continuation. */
    public static function after(tokenizer:Tokenizer):State {
        return tokenizer.lazy ? State.Nok : State.Ok;
    }

}
