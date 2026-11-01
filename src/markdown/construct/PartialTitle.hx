// Ported from markdown 1.0.0: src/construct/partial_title.rs
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

/**
 * Title occurs in definitions and label ends (`partial_title.rs`).
 */
class PartialTitle {

    /** Start of title. */
    public static function start(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '"'.code | "'".code | '('.code:
                var marker = tokenizer.current;
                tokenizer.tokenizeState.marker = marker == '('.code ? ')'.code : marker;
                tokenizer.enter(tokenizer.tokenizeState.token1);
                tokenizer.enter(tokenizer.tokenizeState.token2);
                tokenizer.consume();
                tokenizer.exit(tokenizer.tokenizeState.token2);
                return State.Next(StateName.TitleBegin);
            default:
                return State.Nok;
        }
    }

    /** After opening marker. */
    public static function begin(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.marker) {
            tokenizer.enter(tokenizer.tokenizeState.token2);
            tokenizer.consume();
            tokenizer.exit(tokenizer.tokenizeState.token2);
            tokenizer.exit(tokenizer.tokenizeState.token1);
            tokenizer.tokenizeState.marker = 0;
            tokenizer.tokenizeState.connect = false;
            return State.Ok;
        }
        else {
            tokenizer.enter(tokenizer.tokenizeState.token3);
            return State.Retry(StateName.TitleAtBreak);
        }
    }

    /** At something, before something else. */
    public static function atBreak(tokenizer:Tokenizer):State {
        var byte = tokenizer.current;
        if (byte != -1) {
            if (byte == tokenizer.tokenizeState.marker) {
                tokenizer.exit(tokenizer.tokenizeState.token3);
                return State.Retry(StateName.TitleBegin);
            }
            else if (byte == '\n'.code) {
                tokenizer.attempt(State.Next(StateName.TitleAfterEol), State.Next(StateName.TitleNok));
                return State.Retry(PartialSpaceOrTabEol.spaceOrTabEolWithOptions(tokenizer, Content.String, tokenizer.tokenizeState.connect));
            }
            else {
                tokenizer.enterLink(Name.Data, new Link(-1, -1, Content.String));

                if (tokenizer.tokenizeState.connect) {
                    var index = tokenizer.events.length - 1;
                    Subtokenize.link(tokenizer.events, index);
                }
                else {
                    tokenizer.tokenizeState.connect = true;
                }

                return State.Retry(StateName.TitleInside);
            }
        }
        else {
            return State.Retry(StateName.TitleNok);
        }
    }

    /** In title, after whitespace. */
    public static function afterEol(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.connect = true;
        return State.Retry(StateName.TitleAtBreak);
    }

    /** In title, at something that isn't allowed. */
    public static function nok(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.marker = 0;
        tokenizer.tokenizeState.connect = false;
        return State.Nok;
    }

    /** In text. */
    public static function inside(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.marker || tokenizer.current == -1 || tokenizer.current == '\n'.code) {
            tokenizer.exit(Name.Data);
            return State.Retry(StateName.TitleAtBreak);
        }
        else {
            var name = tokenizer.current == '\\'.code ? StateName.TitleEscape : StateName.TitleInside;
            tokenizer.consume();
            return State.Next(name);
        }
    }

    /** After `\`, at a special character. */
    public static function escape(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '"'.code | "'".code | ')'.code | '\\'.code:
                tokenizer.consume();
                return State.Next(StateName.TitleInside);
            default:
                return State.Retry(StateName.TitleInside);
        }
    }

}
