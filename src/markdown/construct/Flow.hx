// Ported from markdown 1.0.0: src/construct/flow.rs
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
 * Flow is the content type of a document (`flow.rs`).
 */
class Flow {

    /** Start of flow. */
    public static function start(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '#'.code:
                tokenizer.attempt(State.Next(StateName.FlowAfter), State.Next(StateName.FlowBeforeContent));
                return State.Retry(StateName.HeadingAtxStart);
            case '$'.code | '`'.code | '~'.code:
                tokenizer.attempt(State.Next(StateName.FlowAfter), State.Next(StateName.FlowBeforeContent));
                return State.Retry(StateName.RawFlowStart);
            // Note: `-` is also used in setext heading underline so it's not included here.
            case '*'.code | '_'.code:
                tokenizer.attempt(State.Next(StateName.FlowAfter), State.Next(StateName.FlowBeforeContent));
                return State.Retry(StateName.ThematicBreakStart);
            case '<'.code:
                tokenizer.attempt(State.Next(StateName.FlowAfter), State.Next(StateName.FlowBeforeMdxJsx));
                return State.Retry(StateName.HtmlFlowStart);
            case 'e'.code | 'i'.code:
                tokenizer.attempt(State.Next(StateName.FlowAfter), State.Next(StateName.FlowBeforeContent));
                return State.Retry(StateName.MdxEsmStart);
            case '{'.code:
                tokenizer.attempt(State.Next(StateName.FlowAfter), State.Next(StateName.FlowBeforeContent));
                return State.Retry(StateName.MdxExpressionFlowStart);
            // Actual parsing: blank line? Indented code? Indented anything?
            // Tables, setext heading underlines, definitions, and content.
            default:
                return State.Retry(StateName.FlowBlankLineBefore);
        }
    }

    public static function blankLineBefore(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.FlowBlankLineAfter), State.Next(StateName.FlowBeforeCodeIndented));
        return State.Retry(StateName.BlankLineStart);
    }

    public static function beforeCodeIndented(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.FlowAfter), State.Next(StateName.FlowBeforeRaw));
        return State.Retry(StateName.CodeIndentedStart);
    }

    public static function beforeRaw(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.FlowAfter), State.Next(StateName.FlowBeforeHtml));
        return State.Retry(StateName.RawFlowStart);
    }

    public static function beforeHtml(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.FlowAfter), State.Next(StateName.FlowBeforeMdxJsx));
        return State.Retry(StateName.HtmlFlowStart);
    }

    public static function beforeMdxJsx(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.FlowAfter), State.Next(StateName.FlowBeforeHeadingAtx));
        return State.Retry(StateName.MdxJsxFlowStart);
    }

    public static function beforeHeadingAtx(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.FlowAfter), State.Next(StateName.FlowBeforeHeadingSetext));
        return State.Retry(StateName.HeadingAtxStart);
    }

    public static function beforeHeadingSetext(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.FlowAfter), State.Next(StateName.FlowBeforeThematicBreak));
        return State.Retry(StateName.HeadingSetextStart);
    }

    public static function beforeThematicBreak(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.FlowAfter), State.Next(StateName.FlowBeforeMdxExpression));
        return State.Retry(StateName.ThematicBreakStart);
    }

    public static function beforeMdxExpression(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.FlowAfter), State.Next(StateName.FlowBeforeGfmTable));
        return State.Retry(StateName.MdxExpressionFlowStart);
    }

    public static function beforeGfmTable(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.FlowAfter), State.Next(StateName.FlowBeforeContent));
        return State.Retry(StateName.GfmTableStart);
    }

    /** At content. */
    public static function beforeContent(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.FlowAfter), State.Nok);
        return State.Retry(StateName.ContentChunkStart);
    }

    /** After blank line. */
    public static function blankLineAfter(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1:
                return State.Ok;
            case '\n'.code:
                tokenizer.enter(Name.BlankLineEnding);
                tokenizer.consume();
                tokenizer.exit(Name.BlankLineEnding);
                // Feel free to interrupt.
                tokenizer.interrupt = false;
                return State.Next(StateName.FlowStart);
            default:
                throw 'expected eol/eof';
        }
    }

    /** After flow. */
    public static function after(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1:
                return State.Ok;
            case '\n'.code:
                tokenizer.enter(Name.LineEnding);
                tokenizer.consume();
                tokenizer.exit(Name.LineEnding);
                return State.Next(StateName.FlowStart);
            default:
                throw 'expected eol/eof';
        }
    }

}
