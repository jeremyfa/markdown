// Ported from markdown 1.0.0: src/construct/gfm_label_start_footnote.rs
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
 * Label start (footnote) occurs in the text content type (`gfm_label_start_footnote.rs`).
 */
class GfmLabelStartFootnote {

    /** Start of label (footnote) start. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.gfmLabelStartFootnote && tokenizer.current == '['.code) {
            tokenizer.enter(Name.GfmFootnoteCallLabel);
            tokenizer.enter(Name.LabelMarker);
            tokenizer.consume();
            tokenizer.exit(Name.LabelMarker);
            return State.Next(StateName.GfmLabelStartFootnoteOpen);
        }
        else {
            return State.Nok;
        }
    }

    /** At `^`. */
    public static function open(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '^'.code:
                tokenizer.enter(Name.GfmFootnoteCallMarker);
                tokenizer.consume();
                tokenizer.exit(Name.GfmFootnoteCallMarker);
                tokenizer.exit(Name.GfmFootnoteCallLabel);
                tokenizer.tokenizeState.labelStarts.push(new LabelStart(LabelKind.GfmFootnote, tokenizer.events.length - 6, tokenizer.events.length - 1, false));
                tokenizer.registerResolverBefore(ResolveName.Label);
                return State.Ok;
            default:
                return State.Nok;
        }
    }

}
