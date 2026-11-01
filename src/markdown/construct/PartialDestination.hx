// Ported from markdown 1.0.0: src/construct/partial_destination.rs
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
 * Destination occurs in definitions and label ends (`partial_destination.rs`).
 */
class PartialDestination {

    /** Start of destination. */
    public static function start(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if (c == '<'.code) {
            tokenizer.enter(tokenizer.tokenizeState.token1);
            tokenizer.enter(tokenizer.tokenizeState.token2);
            tokenizer.enter(tokenizer.tokenizeState.token3);
            tokenizer.consume();
            tokenizer.exit(tokenizer.tokenizeState.token3);
            return State.Next(StateName.DestinationEnclosedBefore);
        }
        // ASCII control, space, closing paren, but *not* `\0`.
        else if (c == -1 || (c >= 0x01 && c <= 0x1F) || c == ' '.code || c == ')'.code || c == 0x7F) {
            return State.Nok;
        }
        else {
            tokenizer.enter(tokenizer.tokenizeState.token1);
            tokenizer.enter(tokenizer.tokenizeState.token4);
            tokenizer.enter(tokenizer.tokenizeState.token5);
            tokenizer.enterLink(Name.Data, new Link(-1, -1, Content.String));
            return State.Retry(StateName.DestinationRaw);
        }
    }

    /** After `<`, at an enclosed destination. */
    public static function enclosedBefore(tokenizer:Tokenizer):State {
        if (tokenizer.current == '>'.code) {
            tokenizer.enter(tokenizer.tokenizeState.token3);
            tokenizer.consume();
            tokenizer.exit(tokenizer.tokenizeState.token3);
            tokenizer.exit(tokenizer.tokenizeState.token2);
            tokenizer.exit(tokenizer.tokenizeState.token1);
            return State.Ok;
        }
        else {
            tokenizer.enter(tokenizer.tokenizeState.token5);
            tokenizer.enterLink(Name.Data, new Link(-1, -1, Content.String));
            return State.Retry(StateName.DestinationEnclosed);
        }
    }

    /** In enclosed destination. */
    public static function enclosed(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code | '<'.code:
                return State.Nok;
            case '>'.code:
                tokenizer.exit(Name.Data);
                tokenizer.exit(tokenizer.tokenizeState.token5);
                return State.Retry(StateName.DestinationEnclosedBefore);
            case '\\'.code:
                tokenizer.consume();
                return State.Next(StateName.DestinationEnclosedEscape);
            default:
                tokenizer.consume();
                return State.Next(StateName.DestinationEnclosed);
        }
    }

    /** After `\`, at a special character. */
    public static function enclosedEscape(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '<'.code | '>'.code | '\\'.code:
                tokenizer.consume();
                return State.Next(StateName.DestinationEnclosed);
            default:
                return State.Retry(StateName.DestinationEnclosed);
        }
    }

    /** In raw destination. */
    public static function raw(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if (tokenizer.tokenizeState.size == 0 && (c == -1 || c == '\t'.code || c == '\n'.code || c == ' '.code || c == ')'.code)) {
            tokenizer.exit(Name.Data);
            tokenizer.exit(tokenizer.tokenizeState.token5);
            tokenizer.exit(tokenizer.tokenizeState.token4);
            tokenizer.exit(tokenizer.tokenizeState.token1);
            tokenizer.tokenizeState.size = 0;
            return State.Ok;
        }
        else if (tokenizer.tokenizeState.size < tokenizer.tokenizeState.sizeB && c == '('.code) {
            tokenizer.consume();
            tokenizer.tokenizeState.size += 1;
            return State.Next(StateName.DestinationRaw);
        }
        else if (c == ')'.code) {
            tokenizer.consume();
            tokenizer.tokenizeState.size -= 1;
            return State.Next(StateName.DestinationRaw);
        }
        // ASCII control (but *not* `\0`) and space and `(`.
        else if (c == -1 || (c >= 0x01 && c <= 0x1F) || c == ' '.code || c == '('.code || c == 0x7F) {
            tokenizer.tokenizeState.size = 0;
            return State.Nok;
        }
        else if (c == '\\'.code) {
            tokenizer.consume();
            return State.Next(StateName.DestinationRawEscape);
        }
        else {
            tokenizer.consume();
            return State.Next(StateName.DestinationRaw);
        }
    }

    /** After `\`, at special character. */
    public static function rawEscape(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '('.code | ')'.code | '\\'.code:
                tokenizer.consume();
                return State.Next(StateName.DestinationRaw);
            default:
                return State.Retry(StateName.DestinationRaw);
        }
    }

}
