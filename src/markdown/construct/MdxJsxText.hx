// Ported from markdown 1.0.0: src/construct/mdx_jsx_text.rs
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
 * MDX JSX (text) occurs in the text content type (`mdx_jsx_text.rs`).
 */
class MdxJsxText {

    /** Start of MDX: JSX (text). */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.current == '<'.code && tokenizer.parseState.options.constructs.mdxJsxText) {
            tokenizer.tokenizeState.token1 = Name.MdxJsxTextTag;
            tokenizer.attempt(State.Next(StateName.MdxJsxTextAfter), State.Next(StateName.MdxJsxTextNok));
            return State.Retry(StateName.MdxJsxStart);
        }
        else {
            return State.Nok;
        }
    }

    /** After an MDX JSX (text) tag. */
    public static function after(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.token1 = Name.Data;
        return State.Ok;
    }

    /** At something that wasn't an MDX JSX (text) tag. */
    public static function nok(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.token1 = Name.Data;
        return State.Nok;
    }

}
