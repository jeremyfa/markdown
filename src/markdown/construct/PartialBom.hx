// Ported from markdown 1.0.0: src/construct/partial_bom.rs
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
 * Byte order mark occurs at the start of the document (`partial_bom.rs`).
 */
class PartialBom {

    static final BOM:Array<Int> = [0xEF, 0xBB, 0xBF];

    /** Before BOM. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.current == BOM[0]) {
            tokenizer.enter(Name.ByteOrderMark);
            return State.Retry(StateName.BomInside);
        }
        else {
            return State.Nok;
        }
    }

    /** In BOM. */
    public static function inside(tokenizer:Tokenizer):State {
        if (tokenizer.current == BOM[tokenizer.tokenizeState.size]) {
            tokenizer.tokenizeState.size += 1;
            tokenizer.consume();
            if (tokenizer.tokenizeState.size == BOM.length) {
                tokenizer.exit(Name.ByteOrderMark);
                tokenizer.tokenizeState.size = 0;
                return State.Ok;
            }
            else {
                return State.Next(StateName.BomInside);
            }
        }
        else {
            tokenizer.tokenizeState.size = 0;
            return State.Nok;
        }
    }

}
