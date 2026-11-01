// Ported from markdown 1.0.0: src/construct/raw_text.rs
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
 * Raw (text) occurs in the text content type: code (text) and math (text)
 * (`raw_text.rs`).
 */
class RawText {

    /** Start of raw (text). */
    public static function start(tokenizer:Tokenizer):State {
        // Code (text):
        if (((tokenizer.parseState.options.constructs.codeText && tokenizer.current == '`'.code)
            // Math (text):
            || (tokenizer.parseState.options.constructs.mathText && tokenizer.current == '$'.code))
            // Not the same marker (except when escaped).
            && (tokenizer.previous != tokenizer.current
                || (tokenizer.events.length > 0 && tokenizer.events[tokenizer.events.length - 1].name == Name.CharacterEscape))) {
            var marker = tokenizer.current;

            if (marker == '`'.code) {
                tokenizer.tokenizeState.token1 = Name.CodeText;
                tokenizer.tokenizeState.token2 = Name.CodeTextSequence;
                tokenizer.tokenizeState.token3 = Name.CodeTextData;
            }
            else {
                tokenizer.tokenizeState.token1 = Name.MathText;
                tokenizer.tokenizeState.token2 = Name.MathTextSequence;
                tokenizer.tokenizeState.token3 = Name.MathTextData;
            }

            tokenizer.tokenizeState.marker = marker;
            tokenizer.enter(tokenizer.tokenizeState.token1);
            tokenizer.enter(tokenizer.tokenizeState.token2);
            return State.Retry(StateName.RawTextSequenceOpen);
        }
        else {
            return State.Nok;
        }
    }

    /** In opening sequence. */
    public static function sequenceOpen(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.marker) {
            tokenizer.tokenizeState.size += 1;
            tokenizer.consume();
            return State.Next(StateName.RawTextSequenceOpen);
        }
        // Not enough markers in the sequence.
        else if (tokenizer.tokenizeState.marker == '$'.code && tokenizer.tokenizeState.size == 1 && !tokenizer.parseState.options.mathTextSingleDollar) {
            tokenizer.tokenizeState.marker = 0;
            tokenizer.tokenizeState.size = 0;
            tokenizer.tokenizeState.token1 = Name.Data;
            tokenizer.tokenizeState.token2 = Name.Data;
            tokenizer.tokenizeState.token3 = Name.Data;
            return State.Nok;
        }
        else {
            tokenizer.exit(tokenizer.tokenizeState.token2);
            return State.Retry(StateName.RawTextBetween);
        }
    }

    /** Between something and something else. */
    public static function between(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1:
                tokenizer.tokenizeState.marker = 0;
                tokenizer.tokenizeState.size = 0;
                tokenizer.tokenizeState.token1 = Name.Data;
                tokenizer.tokenizeState.token2 = Name.Data;
                tokenizer.tokenizeState.token3 = Name.Data;
                return State.Nok;
            case '\n'.code:
                tokenizer.enter(Name.LineEnding);
                tokenizer.consume();
                tokenizer.exit(Name.LineEnding);
                return State.Next(StateName.RawTextBetween);
            default:
                if (tokenizer.current == tokenizer.tokenizeState.marker) {
                    tokenizer.enter(tokenizer.tokenizeState.token2);
                    return State.Retry(StateName.RawTextSequenceClose);
                }
                else {
                    tokenizer.enter(tokenizer.tokenizeState.token3);
                    return State.Retry(StateName.RawTextData);
                }
        }
    }

    /** In data. */
    public static function data(tokenizer:Tokenizer):State {
        if (tokenizer.current == -1 || tokenizer.current == '\n'.code || tokenizer.current == tokenizer.tokenizeState.marker) {
            tokenizer.exit(tokenizer.tokenizeState.token3);
            return State.Retry(StateName.RawTextBetween);
        }
        else {
            tokenizer.consume();
            return State.Next(StateName.RawTextData);
        }
    }

    /** In closing sequence. */
    public static function sequenceClose(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.marker) {
            tokenizer.tokenizeState.sizeB += 1;
            tokenizer.consume();
            return State.Next(StateName.RawTextSequenceClose);
        }
        else {
            tokenizer.exit(tokenizer.tokenizeState.token2);
            if (tokenizer.tokenizeState.size == tokenizer.tokenizeState.sizeB) {
                tokenizer.exit(tokenizer.tokenizeState.token1);
                tokenizer.tokenizeState.marker = 0;
                tokenizer.tokenizeState.size = 0;
                tokenizer.tokenizeState.sizeB = 0;
                tokenizer.tokenizeState.token1 = Name.Data;
                tokenizer.tokenizeState.token2 = Name.Data;
                tokenizer.tokenizeState.token3 = Name.Data;
                return State.Ok;
            }
            else {
                // More or less accents: mark as data.
                var len = tokenizer.events.length;
                tokenizer.events[len - 2].name = tokenizer.tokenizeState.token3;
                tokenizer.events[len - 1].name = tokenizer.tokenizeState.token3;
                tokenizer.tokenizeState.sizeB = 0;
                return State.Retry(StateName.RawTextBetween);
            }
        }
    }

}
