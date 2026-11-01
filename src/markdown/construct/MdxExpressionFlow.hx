// Ported from markdown 1.0.0: src/construct/mdx_expression_flow.rs
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
import markdown.util.Constant;

/**
 * MDX expression (flow) occurs in the flow content type (`mdx_expression_flow.rs`).
 */
class MdxExpressionFlow {

    /** Start of an MDX expression (flow). */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.mdxExpressionFlow) {
            tokenizer.tokenizeState.token1 = Name.MdxFlowExpression;
            if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
                tokenizer.attempt(State.Next(StateName.MdxExpressionFlowBefore), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 0,
                    tokenizer.parseState.options.constructs.codeIndented ? Constant.TAB_SIZE - 1 : PartialSpaceOrTab.MAX));
            }
            else {
                return State.Retry(StateName.MdxExpressionFlowBefore);
            }
        }
        else {
            return State.Nok;
        }
    }

    /** After optional whitespace, before expression. */
    public static function before(tokenizer:Tokenizer):State {
        if (tokenizer.current == '{'.code) {
            tokenizer.concrete = true;
            tokenizer.attempt(State.Next(StateName.MdxExpressionFlowAfter), State.Nok);
            return State.Retry(StateName.MdxExpressionStart);
        }
        else {
            return State.Nok;
        }
    }

    /** After expression. */
    public static function after(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\t'.code | ' '.code:
                tokenizer.attempt(State.Next(StateName.MdxExpressionFlowEnd), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
            default:
                return State.Retry(StateName.MdxExpressionFlowEnd);
        }
    }

    /** After expression, after optional whitespace. */
    public static function end(tokenizer:Tokenizer):State {
        // We want to allow tags directly after expressions.
        //
        // This case is useful:
        //
        // ```mdx
        // <a>{b}</a>
        // ```
        //
        // This case is not (very?) useful:
        //
        // ```mdx
        // {a}<b/>
        // ```
        //
        // …but it would be tougher than needed to disallow.
        //
        // To allow that, here we call the MDX JSX flow construct, and there we call this one.
        //
        // It would introduce a cyclical interdependency if we test JSX and expressions here.
        // Because the JSX extension already uses parts of this monorepo, we instead test it there.
        switch tokenizer.current {
            case -1 | '\n'.code:
                reset(tokenizer);
                return State.Ok;
            case '<'.code if (tokenizer.parseState.options.constructs.mdxJsxFlow):
                // Note: `mdx_jsx_flow` is the one that resets `token_1`.
                tokenizer.tokenizeState.token1 = Name.MdxJsxFlowTag;
                tokenizer.attempt(State.Next(StateName.MdxJsxFlowAfter), State.Next(StateName.MdxJsxFlowNok));
                return State.Retry(StateName.MdxJsxStart);
            default:
                reset(tokenizer);
                return State.Nok;
        }
    }

    /** Reset state. */
    static function reset(tokenizer:Tokenizer):Void {
        tokenizer.concrete = false;
        tokenizer.tokenizeState.token1 = Name.Data;
    }

}
