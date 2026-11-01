// Ported from markdown 1.0.0: src/construct/label_start_link.rs
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
 * Label start (link) occurs in the text content type (`label_start_link.rs`).
 */
class LabelStartLink {

    /** Start of label (link) start. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.labelStartLink && tokenizer.current == '['.code) {
            var start = tokenizer.events.length;
            tokenizer.enter(Name.LabelLink);
            tokenizer.enter(Name.LabelMarker);
            tokenizer.consume();
            tokenizer.exit(Name.LabelMarker);
            tokenizer.exit(Name.LabelLink);
            tokenizer.tokenizeState.labelStarts.push(new LabelStart(LabelKind.Link, start, tokenizer.events.length - 1, false));
            tokenizer.registerResolverBefore(ResolveName.Label);
            return State.Ok;
        }
        else {
            return State.Nok;
        }
    }

}
