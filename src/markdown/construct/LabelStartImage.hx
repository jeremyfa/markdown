// Ported from markdown 1.0.0: src/construct/label_start_image.rs
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
 * Label start (image) occurs in the text content type (`label_start_image.rs`).
 */
class LabelStartImage {

    /** Start of label (image) start. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.labelStartImage && tokenizer.current == '!'.code) {
            tokenizer.enter(Name.LabelImage);
            tokenizer.enter(Name.LabelImageMarker);
            tokenizer.consume();
            tokenizer.exit(Name.LabelImageMarker);
            return State.Next(StateName.LabelStartImageOpen);
        }
        else {
            return State.Nok;
        }
    }

    /** After `!`, at `[`. */
    public static function open(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '['.code:
                tokenizer.enter(Name.LabelMarker);
                tokenizer.consume();
                tokenizer.exit(Name.LabelMarker);
                tokenizer.exit(Name.LabelImage);
                return State.Next(StateName.LabelStartImageAfter);
            default:
                return State.Nok;
        }
    }

    /** After `![`. */
    public static function after(tokenizer:Tokenizer):State {
        // To do: use a new tokenizer function to check if the next byte is a footnote marker.
        if (tokenizer.parseState.options.constructs.gfmLabelStartFootnote && tokenizer.current == '^'.code) {
            return State.Nok;
        }
        else {
            tokenizer.tokenizeState.labelStarts.push(new LabelStart(LabelKind.Image, tokenizer.events.length - 6, tokenizer.events.length - 1, false));
            tokenizer.registerResolverBefore(ResolveName.Label);
            return State.Ok;
        }
    }

}
