// Ported from markdown 1.0.0: src/construct/partial_label.rs
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
import markdown.Subtokenize;
import markdown.util.Constant;

/**
 * Label occurs in definitions and label ends (`partial_label.rs`).
 */
class PartialLabel {

    /** Start of label. */
    public static function start(tokenizer:Tokenizer):State {
        tokenizer.enter(tokenizer.tokenizeState.token1);
        tokenizer.enter(tokenizer.tokenizeState.token2);
        tokenizer.consume();
        tokenizer.exit(tokenizer.tokenizeState.token2);
        tokenizer.enter(tokenizer.tokenizeState.token3);
        return State.Next(StateName.LabelAtBreak);
    }

    /** In label, at something, before something else. */
    public static function atBreak(tokenizer:Tokenizer):State {
        if (tokenizer.tokenizeState.size > Constant.LINK_REFERENCE_SIZE_MAX
            || tokenizer.current == -1 || tokenizer.current == '['.code
            || (tokenizer.current == ']'.code && !tokenizer.tokenizeState.seen)) {
            return State.Retry(StateName.LabelNok);
        }
        else {
            switch tokenizer.current {
                case '\n'.code:
                    tokenizer.attempt(State.Next(StateName.LabelEolAfter), State.Next(StateName.LabelNok));
                    return State.Retry(PartialSpaceOrTabEol.spaceOrTabEolWithOptions(tokenizer, Content.String, tokenizer.tokenizeState.connect));
                case ']'.code:
                    tokenizer.exit(tokenizer.tokenizeState.token3);
                    tokenizer.enter(tokenizer.tokenizeState.token2);
                    tokenizer.consume();
                    tokenizer.exit(tokenizer.tokenizeState.token2);
                    tokenizer.exit(tokenizer.tokenizeState.token1);
                    tokenizer.tokenizeState.connect = false;
                    tokenizer.tokenizeState.seen = false;
                    tokenizer.tokenizeState.size = 0;
                    return State.Ok;
                default:
                    tokenizer.enterLink(Name.Data, new Link(-1, -1, Content.String));

                    if (tokenizer.tokenizeState.connect) {
                        var index = tokenizer.events.length - 1;
                        Subtokenize.link(tokenizer.events, index);
                    }
                    else {
                        tokenizer.tokenizeState.connect = true;
                    }

                    return State.Retry(StateName.LabelInside);
            }
        }
    }

    /** In label, after whitespace. */
    public static function eolAfter(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.connect = true;
        return State.Retry(StateName.LabelAtBreak);
    }

    /** In label, on something disallowed. */
    public static function nok(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.connect = false;
        tokenizer.tokenizeState.seen = false;
        tokenizer.tokenizeState.size = 0;
        return State.Nok;
    }

    /** In label, in text. */
    public static function inside(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code | '['.code | ']'.code:
                tokenizer.exit(Name.Data);
                return State.Retry(StateName.LabelAtBreak);
            case byte:
                if (tokenizer.tokenizeState.size > Constant.LINK_REFERENCE_SIZE_MAX) {
                    tokenizer.exit(Name.Data);
                    return State.Retry(StateName.LabelAtBreak);
                }
                else {
                    tokenizer.consume();
                    tokenizer.tokenizeState.size += 1;
                    if (!tokenizer.tokenizeState.seen && byte != '\t'.code && byte != ' '.code) {
                        tokenizer.tokenizeState.seen = true;
                    }
                    return State.Next(byte == '\\'.code ? StateName.LabelEscape : StateName.LabelInside);
                }
        }
    }

    /** After `\`, at a special character. */
    public static function escape(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '['.code | '\\'.code | ']'.code:
                tokenizer.consume();
                tokenizer.tokenizeState.size += 1;
                return State.Next(StateName.LabelInside);
            default:
                return State.Retry(StateName.LabelInside);
        }
    }

}
