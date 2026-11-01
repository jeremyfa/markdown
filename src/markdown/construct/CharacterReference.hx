// Ported from markdown 1.0.0: src/construct/character_reference.rs
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
import markdown.util.CharacterReference as CharacterReferenceUtil;
import markdown.util.Slice;

/**
 * Character references occur in the string and text content types (`character_reference.rs`).
 */
class CharacterReference {

    /** Start of character reference. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.characterReference && tokenizer.current == '&'.code) {
            tokenizer.enter(Name.CharacterReference);
            tokenizer.enter(Name.CharacterReferenceMarker);
            tokenizer.consume();
            tokenizer.exit(Name.CharacterReferenceMarker);
            return State.Next(StateName.CharacterReferenceOpen);
        }
        else {
            return State.Nok;
        }
    }

    /** After `&`, at `#` for numeric references or alphanumeric for named references. */
    public static function open(tokenizer:Tokenizer):State {
        if (tokenizer.current == '#'.code) {
            tokenizer.enter(Name.CharacterReferenceMarkerNumeric);
            tokenizer.consume();
            tokenizer.exit(Name.CharacterReferenceMarkerNumeric);
            return State.Next(StateName.CharacterReferenceNumeric);
        }
        else {
            tokenizer.tokenizeState.marker = '&'.code;
            tokenizer.enter(Name.CharacterReferenceValue);
            return State.Retry(StateName.CharacterReferenceValue);
        }
    }

    /** After `#`, at `x` for hexadecimals or digit for decimals. */
    public static function numeric(tokenizer:Tokenizer):State {
        if (tokenizer.current == 'x'.code || tokenizer.current == 'X'.code) {
            tokenizer.enter(Name.CharacterReferenceMarkerHexadecimal);
            tokenizer.consume();
            tokenizer.exit(Name.CharacterReferenceMarkerHexadecimal);
            tokenizer.enter(Name.CharacterReferenceValue);
            tokenizer.tokenizeState.marker = 'x'.code;
            return State.Next(StateName.CharacterReferenceValue);
        }
        else {
            tokenizer.enter(Name.CharacterReferenceValue);
            tokenizer.tokenizeState.marker = '#'.code;
            return State.Retry(StateName.CharacterReferenceValue);
        }
    }

    /** After markers, in value. */
    public static function value(tokenizer:Tokenizer):State {
        if (tokenizer.current == ';'.code && tokenizer.tokenizeState.size > 0) {
            // Named.
            if (tokenizer.tokenizeState.marker == '&'.code) {
                // Guaranteed to be valid ASCII bytes.
                var slice = Slice.fromIndices(tokenizer.parseState.bytes, tokenizer.point.index - tokenizer.tokenizeState.size, tokenizer.point.index);

                if (CharacterReferenceUtil.decodeNamed(slice.asStr(), true) == null) {
                    tokenizer.tokenizeState.marker = 0;
                    tokenizer.tokenizeState.size = 0;
                    return State.Nok;
                }
            }

            tokenizer.exit(Name.CharacterReferenceValue);
            tokenizer.enter(Name.CharacterReferenceMarkerSemi);
            tokenizer.consume();
            tokenizer.exit(Name.CharacterReferenceMarkerSemi);
            tokenizer.exit(Name.CharacterReference);
            tokenizer.tokenizeState.marker = 0;
            tokenizer.tokenizeState.size = 0;
            return State.Ok;
        }

        var byte = tokenizer.current;
        if (byte != -1) {
            if (tokenizer.tokenizeState.size < CharacterReferenceUtil.valueMax(tokenizer.tokenizeState.marker)
                && CharacterReferenceUtil.valueTest(tokenizer.tokenizeState.marker, byte)) {
                tokenizer.tokenizeState.size += 1;
                tokenizer.consume();
                return State.Next(StateName.CharacterReferenceValue);
            }
        }

        tokenizer.tokenizeState.marker = 0;
        tokenizer.tokenizeState.size = 0;
        return State.Nok;
    }

}
