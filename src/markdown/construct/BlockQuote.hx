// Ported from markdown 1.0.0: src/construct/block_quote.rs
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
 * Block quotes occur in the document content type (`block_quote.rs`).
 */
class BlockQuote {

    /** Start of block quote. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.blockQuote) {
            tokenizer.enter(Name.BlockQuote);
            return State.Retry(StateName.BlockQuoteContStart);
        }
        else {
            return State.Nok;
        }
    }

    /** Start of block quote continuation. */
    public static function contStart(tokenizer:Tokenizer):State {
        if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            tokenizer.attempt(State.Next(StateName.BlockQuoteContBefore), State.Nok);
            return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 1,
                tokenizer.parseState.options.constructs.codeIndented ? Constant.TAB_SIZE - 1 : PartialSpaceOrTab.MAX));
        }
        else {
            return State.Retry(StateName.BlockQuoteContBefore);
        }
    }

    /** At `>`, after optional whitespace. */
    public static function contBefore(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '>'.code:
                tokenizer.enter(Name.BlockQuotePrefix);
                tokenizer.enter(Name.BlockQuoteMarker);
                tokenizer.consume();
                tokenizer.exit(Name.BlockQuoteMarker);
                return State.Next(StateName.BlockQuoteContAfter);
            default:
                return State.Nok;
        }
    }

    /** After `>`, before optional whitespace. */
    public static function contAfter(tokenizer:Tokenizer):State {
        if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            tokenizer.enter(Name.SpaceOrTab);
            tokenizer.consume();
            tokenizer.exit(Name.SpaceOrTab);
        }

        tokenizer.exit(Name.BlockQuotePrefix);
        return State.Ok;
    }

}
