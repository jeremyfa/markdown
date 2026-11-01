// Ported from markdown 1.0.0: src/construct/partial_space_or_tab.rs
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
 * Space or tab occurs in tons of places (`partial_space_or_tab.rs`).
 */
class PartialSpaceOrTab {

    public static inline var MAX:Int = 0x7FFFFFFF;

    /** One or more `space_or_tab`. */
    public static inline function spaceOrTab(tokenizer:Tokenizer):StateName {
        return spaceOrTabMinMax(tokenizer, 1, MAX);
    }

    /** Between `x` and `y` `space_or_tab`. */
    public static inline function spaceOrTabMinMax(tokenizer:Tokenizer, min:Int, max:Int):StateName {
        return spaceOrTabWithOptions(tokenizer, Name.SpaceOrTab, min, max, null, false);
    }

    /** `space_or_tab`, with the given options (`Options`: kind, min, max, content, connect). */
    public static function spaceOrTabWithOptions(tokenizer:Tokenizer, kind:Name, min:Int, max:Int, content:Null<Content>, connect:Bool):StateName {
        tokenizer.tokenizeState.spaceOrTabConnect = connect;
        tokenizer.tokenizeState.spaceOrTabContent = content;
        tokenizer.tokenizeState.spaceOrTabMin = min;
        tokenizer.tokenizeState.spaceOrTabMax = max;
        tokenizer.tokenizeState.spaceOrTabToken = kind;
        return StateName.SpaceOrTabStart;
    }

    /** Start of `space_or_tab`. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.tokenizeState.spaceOrTabMax > 0 && (tokenizer.current == '\t'.code || tokenizer.current == ' '.code)) {
            if (tokenizer.tokenizeState.spaceOrTabContent != null) {
                tokenizer.enterLink(tokenizer.tokenizeState.spaceOrTabToken, new Link(-1, -1, tokenizer.tokenizeState.spaceOrTabContent));
            }
            else {
                tokenizer.enter(tokenizer.tokenizeState.spaceOrTabToken);
            }

            if (tokenizer.tokenizeState.spaceOrTabConnect) {
                var index = tokenizer.events.length - 1;
                Subtokenize.link(tokenizer.events, index);
            }
            else {
                tokenizer.tokenizeState.spaceOrTabConnect = true;
            }

            return State.Retry(StateName.SpaceOrTabInside);
        }
        else {
            return State.Retry(StateName.SpaceOrTabAfter);
        }
    }

    /** In `space_or_tab`. */
    public static function inside(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\t'.code | ' '.code if (tokenizer.tokenizeState.spaceOrTabSize < tokenizer.tokenizeState.spaceOrTabMax):
                tokenizer.consume();
                tokenizer.tokenizeState.spaceOrTabSize += 1;
                return State.Next(StateName.SpaceOrTabInside);
            default:
                tokenizer.exit(tokenizer.tokenizeState.spaceOrTabToken);
                return State.Retry(StateName.SpaceOrTabAfter);
        }
    }

    /** After `space_or_tab`. */
    public static function after(tokenizer:Tokenizer):State {
        var state = tokenizer.tokenizeState.spaceOrTabSize >= tokenizer.tokenizeState.spaceOrTabMin ? State.Ok : State.Nok;
        tokenizer.tokenizeState.spaceOrTabConnect = false;
        tokenizer.tokenizeState.spaceOrTabContent = null;
        tokenizer.tokenizeState.spaceOrTabSize = 0;
        tokenizer.tokenizeState.spaceOrTabMax = 0;
        tokenizer.tokenizeState.spaceOrTabMin = 0;
        tokenizer.tokenizeState.spaceOrTabToken = Name.SpaceOrTab;
        return state;
    }

}
