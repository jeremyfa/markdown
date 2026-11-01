// Ported from markdown 1.0.0: src/construct/thematic_break.rs
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
 * Thematic break occurs in the flow content type (`thematic_break.rs`).
 */
class ThematicBreak {

    /** Start of thematic break. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.thematicBreak) {
            tokenizer.enter(Name.ThematicBreak);

            if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
                tokenizer.attempt(State.Next(StateName.ThematicBreakBefore), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 0,
                    tokenizer.parseState.options.constructs.codeIndented ? Constant.TAB_SIZE - 1 : PartialSpaceOrTab.MAX));
            }
            else {
                return State.Retry(StateName.ThematicBreakBefore);
            }
        }
        else {
            return State.Nok;
        }
    }

    /** After optional whitespace, at marker. */
    public static function before(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '*'.code | '-'.code | '_'.code:
                tokenizer.tokenizeState.marker = tokenizer.current;
                return State.Retry(StateName.ThematicBreakAtBreak);
            default:
                return State.Nok;
        }
    }

    /** After something, before something else. */
    public static function atBreak(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.marker) {
            tokenizer.enter(Name.ThematicBreakSequence);
            return State.Retry(StateName.ThematicBreakSequence);
        }
        else if (tokenizer.tokenizeState.size >= Constant.THEMATIC_BREAK_MARKER_COUNT_MIN && (tokenizer.current == -1 || tokenizer.current == '\n'.code)) {
            tokenizer.tokenizeState.marker = 0;
            tokenizer.tokenizeState.size = 0;
            tokenizer.exit(Name.ThematicBreak);
            // Feel free to interrupt.
            tokenizer.interrupt = false;
            return State.Ok;
        }
        else {
            tokenizer.tokenizeState.marker = 0;
            tokenizer.tokenizeState.size = 0;
            return State.Nok;
        }
    }

    /** In sequence. */
    public static function sequence(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.marker) {
            tokenizer.consume();
            tokenizer.tokenizeState.size += 1;
            return State.Next(StateName.ThematicBreakSequence);
        }
        else if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            tokenizer.exit(Name.ThematicBreakSequence);
            tokenizer.attempt(State.Next(StateName.ThematicBreakAtBreak), State.Nok);
            return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
        }
        else {
            tokenizer.exit(Name.ThematicBreakSequence);
            return State.Retry(StateName.ThematicBreakAtBreak);
        }
    }

}
