// Ported from markdown 1.0.0: src/construct/gfm_task_list_item_check.rs
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
 * GFM: task list item check occurs in the text content type (`gfm_task_list_item_check.rs`).
 */
class GfmTaskListItemCheck {

    /** At start of task list item check. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.gfmTaskListItem
            && tokenizer.tokenizeState.documentAtFirstParagraphOfListItem
            && tokenizer.current == '['.code
            && tokenizer.previous == -1) {
            tokenizer.enter(Name.GfmTaskListItemCheck);
            tokenizer.enter(Name.GfmTaskListItemMarker);
            tokenizer.consume();
            tokenizer.exit(Name.GfmTaskListItemMarker);
            return State.Next(StateName.GfmTaskListItemCheckInside);
        }
        else {
            return State.Nok;
        }
    }

    /** In task list item check. */
    public static function inside(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\t'.code | '\n'.code | ' '.code:
                tokenizer.enter(Name.GfmTaskListItemValueUnchecked);
                tokenizer.consume();
                tokenizer.exit(Name.GfmTaskListItemValueUnchecked);
                return State.Next(StateName.GfmTaskListItemCheckClose);
            case 'X'.code | 'x'.code:
                tokenizer.enter(Name.GfmTaskListItemValueChecked);
                tokenizer.consume();
                tokenizer.exit(Name.GfmTaskListItemValueChecked);
                return State.Next(StateName.GfmTaskListItemCheckClose);
            default:
                return State.Nok;
        }
    }

    /** At close of task list item check. */
    public static function close(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case ']'.code:
                tokenizer.enter(Name.GfmTaskListItemMarker);
                tokenizer.consume();
                tokenizer.exit(Name.GfmTaskListItemMarker);
                tokenizer.exit(Name.GfmTaskListItemCheck);
                return State.Next(StateName.GfmTaskListItemCheckAfter);
            default:
                return State.Nok;
        }
    }

    /** After task list item check. */
    public static function after(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            // EOL in paragraph means there must be something else after it.
            case '\n'.code:
                return State.Ok;
            // Space or tab?
            // Check what comes after.
            case '\t'.code | ' '.code:
                tokenizer.check(State.Ok, State.Nok);
                tokenizer.attempt(State.Next(StateName.GfmTaskListItemCheckAfterSpaceOrTab), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
            // EOF, or non-whitespace, both wrong.
            default:
                return State.Nok;
        }
    }

    /** After whitespace, after task list item check. */
    public static function afterSpaceOrTab(tokenizer:Tokenizer):State {
        // End of paragraph, after whitespace, after check, is not okay.
        return tokenizer.current == -1 ? State.Nok : State.Ok;
    }

}
