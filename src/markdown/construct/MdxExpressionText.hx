// Ported from markdown 1.0.0: src/construct/mdx_expression_text.rs
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
 * MDX expression (text) occurs in the text content type (`mdx_expression_text.rs`).
 */
class MdxExpressionText {

    /** Start of an MDX expression (text). */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.current == '{'.code && tokenizer.parseState.options.constructs.mdxExpressionText) {
            tokenizer.tokenizeState.token1 = Name.MdxTextExpression;
            tokenizer.attempt(State.Next(StateName.MdxExpressionTextAfter), State.Nok);
            return State.Retry(StateName.MdxExpressionStart);
        }
        else {
            return State.Nok;
        }
    }

    /** After expression. */
    public static function after(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.token1 = Name.Data;
        return State.Ok;
    }

}
