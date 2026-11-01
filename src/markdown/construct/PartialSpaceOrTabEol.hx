// Ported from markdown 1.0.0: src/construct/partial_space_or_tab_eol.rs
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
 * Space or tab (eol) occurs in places where whitespace, optionally with a
 * single eol, is allowed (`partial_space_or_tab_eol.rs`).
 */
class PartialSpaceOrTabEol {

    /** `space_or_tab_eol`. */
    public static inline function spaceOrTabEol(tokenizer:Tokenizer):StateName {
        return spaceOrTabEolWithOptions(tokenizer, null, false);
    }

    /** `space_or_tab_eol`, with options (content, connect). */
    public static function spaceOrTabEolWithOptions(tokenizer:Tokenizer, content:Null<Content>, connect:Bool):StateName {
        tokenizer.tokenizeState.spaceOrTabEolContent = content;
        tokenizer.tokenizeState.spaceOrTabEolConnect = connect;
        return StateName.SpaceOrTabEolStart;
    }

    /** Start of whitespace with at most one eol. */
    public static function start(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\t'.code | ' '.code:
                tokenizer.attempt(State.Next(StateName.SpaceOrTabEolAfterFirst), State.Next(StateName.SpaceOrTabEolAtEol));
                return State.Retry(PartialSpaceOrTab.spaceOrTabWithOptions(tokenizer, Name.SpaceOrTab, 1, PartialSpaceOrTab.MAX,
                    tokenizer.tokenizeState.spaceOrTabEolContent, tokenizer.tokenizeState.spaceOrTabEolConnect));
            default:
                return State.Retry(StateName.SpaceOrTabEolAtEol);
        }
    }

    /** After initial whitespace, at optional eol. */
    public static function afterFirst(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.spaceOrTabEolOk = true;
        return State.Retry(StateName.SpaceOrTabEolAtEol);
    }

    /** After optional whitespace, at eol. */
    public static function atEol(tokenizer:Tokenizer):State {
        if (tokenizer.current == '\n'.code) {
            if (tokenizer.tokenizeState.spaceOrTabEolContent != null) {
                tokenizer.enterLink(Name.LineEnding, new Link(-1, -1, tokenizer.tokenizeState.spaceOrTabEolContent));
            }
            else {
                tokenizer.enter(Name.LineEnding);
            }

            if (tokenizer.tokenizeState.spaceOrTabEolConnect) {
                var index = tokenizer.events.length - 1;
                Subtokenize.link(tokenizer.events, index);
            }
            else if (tokenizer.tokenizeState.spaceOrTabEolContent != null) {
                tokenizer.tokenizeState.spaceOrTabEolConnect = true;
            }

            tokenizer.consume();
            tokenizer.exit(Name.LineEnding);
            return State.Next(StateName.SpaceOrTabEolAfterEol);
        }
        else {
            var ok = tokenizer.tokenizeState.spaceOrTabEolOk;
            tokenizer.tokenizeState.spaceOrTabEolContent = null;
            tokenizer.tokenizeState.spaceOrTabEolConnect = false;
            tokenizer.tokenizeState.spaceOrTabEolOk = false;
            return ok ? State.Ok : State.Nok;
        }
    }

    /** After eol. */
    public static function afterEol(tokenizer:Tokenizer):State {
        if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            tokenizer.attempt(State.Next(StateName.SpaceOrTabEolAfterMore), State.Nok);
            return State.Retry(PartialSpaceOrTab.spaceOrTabWithOptions(tokenizer, Name.SpaceOrTab, 1, PartialSpaceOrTab.MAX,
                tokenizer.tokenizeState.spaceOrTabEolContent, tokenizer.tokenizeState.spaceOrTabEolConnect));
        }
        else {
            return State.Retry(StateName.SpaceOrTabEolAfterMore);
        }
    }

    /** After optional final whitespace. */
    public static function afterMore(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.spaceOrTabEolContent = null;
        tokenizer.tokenizeState.spaceOrTabEolConnect = false;
        tokenizer.tokenizeState.spaceOrTabEolOk = false;
        return State.Ok;
    }

}
