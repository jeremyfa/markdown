// Ported from markdown 1.0.0: src/construct/code_indented.rs
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
 * Code (indented) occurs in the flow content type (`code_indented.rs`).
 */
class CodeIndented {

    /** Start of code (indented). */
    public static function start(tokenizer:Tokenizer):State {
        // Do not interrupt paragraphs.
        if (!tokenizer.interrupt && tokenizer.parseState.options.constructs.codeIndented && (tokenizer.current == '\t'.code || tokenizer.current == ' '.code)) {
            tokenizer.enter(Name.CodeIndented);
            tokenizer.attempt(State.Next(StateName.CodeIndentedAtBreak), State.Nok);
            return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, Constant.TAB_SIZE, Constant.TAB_SIZE));
        }
        else {
            return State.Nok;
        }
    }

    /** At a break. */
    public static function atBreak(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1:
                return State.Retry(StateName.CodeIndentedAfter);
            case '\n'.code:
                tokenizer.attempt(State.Next(StateName.CodeIndentedAtBreak), State.Next(StateName.CodeIndentedAfter));
                return State.Retry(StateName.CodeIndentedFurtherStart);
            default:
                tokenizer.enter(Name.CodeFlowChunk);
                return State.Retry(StateName.CodeIndentedInside);
        }
    }

    /** In code content. */
    public static function inside(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                tokenizer.exit(Name.CodeFlowChunk);
                return State.Retry(StateName.CodeIndentedAtBreak);
            default:
                tokenizer.consume();
                return State.Next(StateName.CodeIndentedInside);
        }
    }

    /** After indented code. */
    public static function after(tokenizer:Tokenizer):State {
        tokenizer.exit(Name.CodeIndented);
        // Feel free to interrupt.
        tokenizer.interrupt = false;
        return State.Ok;
    }

    /** At eol, trying to parse another indent. */
    public static function furtherStart(tokenizer:Tokenizer):State {
        if (tokenizer.lazy || tokenizer.pierce) {
            return State.Nok;
        }

        if (tokenizer.current == '\n'.code) {
            tokenizer.enter(Name.LineEnding);
            tokenizer.consume();
            tokenizer.exit(Name.LineEnding);
            return State.Next(StateName.CodeIndentedFurtherStart);
        }
        else {
            tokenizer.attempt(State.Ok, State.Next(StateName.CodeIndentedFurtherBegin));
            return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, Constant.TAB_SIZE, Constant.TAB_SIZE));
        }
    }

    /** At the beginning of a line that is not indented enough. */
    public static function furtherBegin(tokenizer:Tokenizer):State {
        if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            tokenizer.attempt(State.Next(StateName.CodeIndentedFurtherAfter), State.Nok);
            return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
        }
        else {
            return State.Nok;
        }
    }

    /** After whitespace, not indented enough. */
    public static function furtherAfter(tokenizer:Tokenizer):State {
        return switch tokenizer.current {
            case '\n'.code: State.Retry(StateName.CodeIndentedFurtherStart);
            default: State.Nok;
        }
    }

}
