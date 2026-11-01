// Ported from markdown 1.0.0: src/construct/mdx_jsx_flow.rs
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
 * MDX JSX (flow) occurs in the flow content type (`mdx_jsx_flow.rs`).
 */
class MdxJsxFlow {

    /** Start of MDX: JSX (flow). */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.mdxJsxFlow) {
            tokenizer.tokenizeState.token1 = Name.MdxJsxFlowTag;
            tokenizer.concrete = true;
            if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
                tokenizer.attempt(State.Next(StateName.MdxJsxFlowBefore), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 0,
                    tokenizer.parseState.options.constructs.codeIndented ? Constant.TAB_SIZE - 1 : PartialSpaceOrTab.MAX));
            }
            else {
                return State.Retry(StateName.MdxJsxFlowBefore);
            }
        }
        else {
            return State.Nok;
        }
    }

    /** After optional whitespace, before of MDX JSX (flow). */
    public static function before(tokenizer:Tokenizer):State {
        if (tokenizer.current == '<'.code) {
            tokenizer.attempt(State.Next(StateName.MdxJsxFlowAfter), State.Next(StateName.MdxJsxFlowNok));
            return State.Retry(StateName.MdxJsxStart);
        }
        else {
            return State.Retry(StateName.MdxJsxFlowNok);
        }
    }

    /** After an MDX JSX (flow) tag. */
    public static function after(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\t'.code | ' '.code:
                tokenizer.attempt(State.Next(StateName.MdxJsxFlowEnd), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
            default:
                return State.Retry(StateName.MdxJsxFlowEnd);
        }
    }

    /** After an MDX JSX (flow) tag, after optional whitespace. */
    public static function end(tokenizer:Tokenizer):State {
        // We want to allow expressions directly after tags.
        // See <https://github.com/micromark/micromark-extension-mdx-expression/blob/d5d92b9/packages/micromark-extension-mdx-expression/dev/lib/syntax.js#L183>
        // for more info.
        //
        // Note: in the JS version of micromark, arbitrary extensions could be
        // loaded.
        // Here we know that only our own construct `mdx_expression_flow` can be
        // enabled.
        switch tokenizer.current {
            case -1 | '\n'.code:
                reset(tokenizer);
                return State.Ok;
            // We want to allow tags directly after tags.
            case '<'.code:
                tokenizer.attempt(State.Next(StateName.MdxJsxFlowAfter), State.Next(StateName.MdxJsxFlowNok));
                return State.Retry(StateName.MdxJsxStart);
            case '{'.code if (tokenizer.parseState.options.constructs.mdxExpressionFlow):
                tokenizer.attempt(State.Next(StateName.MdxJsxFlowAfter), State.Next(StateName.MdxJsxFlowNok));
                return State.Retry(StateName.MdxExpressionFlowStart);
            default:
                reset(tokenizer);
                return State.Nok;
        }
    }

    /** At something that wasn't an MDX JSX (flow) tag. */
    public static function nok(tokenizer:Tokenizer):State {
        reset(tokenizer);
        return State.Nok;
    }

    /** Reset state. */
    static function reset(tokenizer:Tokenizer):Void {
        tokenizer.concrete = false;
        tokenizer.tokenizeState.token1 = Name.Data;
    }

}
