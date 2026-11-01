// Ported from markdown 1.0.0: src/construct/paragraph.rs
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
 * Paragraph occurs in the content content type (`paragraph.rs`).
 */
class Paragraph {

    /** Paragraph start. */
    public static function start(tokenizer:Tokenizer):State {
        tokenizer.enter(Name.Paragraph);
        return State.Retry(StateName.ParagraphLineStart);
    }

    /** Start of a line in a paragraph. */
    public static function lineStart(tokenizer:Tokenizer):State {
        tokenizer.enterLink(Name.Data, new Link(-1, -1, Content.Text));

        if (tokenizer.tokenizeState.connect) {
            var index = tokenizer.events.length - 1;
            Subtokenize.link(tokenizer.events, index);
        }
        else {
            tokenizer.tokenizeState.connect = true;
        }

        return State.Retry(StateName.ParagraphInside);
    }

    /** In paragraph. */
    public static function inside(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1:
                tokenizer.tokenizeState.connect = false;
                tokenizer.exit(Name.Data);
                tokenizer.exit(Name.Paragraph);
                return State.Ok;
            case '\n'.code:
                tokenizer.consume();
                tokenizer.exit(Name.Data);
                return State.Next(StateName.ParagraphLineStart);
            default:
                tokenizer.consume();
                return State.Next(StateName.ParagraphInside);
        }
    }

}
