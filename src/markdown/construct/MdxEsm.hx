// Ported from markdown 1.0.0: src/construct/mdx_esm.rs
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
import markdown.message.Message;
import markdown.message.Place;
import markdown.util.MdxCollect;
import markdown.util.Mdx;
import markdown.util.Slice;

/**
 * MDX ESM occurs in the flow content type (`mdx_esm.rs`).
 */
class MdxEsm {

    /** Start of MDX ESM. */
    public static function start(tokenizer:Tokenizer):State {
        // If it's turned on.
        if (tokenizer.parseState.options.constructs.mdxEsm
            // If there is a gnostic parser.
            && tokenizer.parseState.options.mdxEsmParse != null
            // When not interrupting.
            && !tokenizer.interrupt
            // Only at the start of a line, not at whitespace or in a container.
            && tokenizer.point.column == 1
            && (tokenizer.current == 'e'.code || tokenizer.current == 'i'.code)) {
            // Place where keyword starts.
            tokenizer.tokenizeState.start = tokenizer.point.index;
            tokenizer.enter(Name.MdxEsm);
            tokenizer.enter(Name.MdxEsmData);
            tokenizer.consume();
            return State.Next(StateName.MdxEsmWord);
        }
        else {
            return State.Nok;
        }
    }

    /** In keyword. */
    public static function word(tokenizer:Tokenizer):State {
        if (tokenizer.current >= 'a'.code && tokenizer.current <= 'z'.code) {
            tokenizer.consume();
            return State.Next(StateName.MdxEsmWord);
        }
        else {
            var slice = Slice.fromIndices(tokenizer.parseState.bytes, tokenizer.tokenizeState.start, tokenizer.point.index);
            var s = slice.asStr();

            if ((s == 'export' || s == 'import') && tokenizer.current == ' '.code) {
                tokenizer.concrete = true;
                tokenizer.tokenizeState.start = tokenizer.events.length - 1;
                tokenizer.consume();
                return State.Next(StateName.MdxEsmInside);
            }
            else {
                tokenizer.tokenizeState.start = 0;
                return State.Nok;
            }
        }
    }

    /** In data. */
    public static function inside(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                tokenizer.exit(Name.MdxEsmData);
                return State.Retry(StateName.MdxEsmLineStart);
            default:
                tokenizer.consume();
                return State.Next(StateName.MdxEsmInside);
        }
    }

    /** At start of line. */
    public static function lineStart(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1:
                return State.Retry(StateName.MdxEsmAtEnd);
            case '\n'.code:
                tokenizer.check(State.Next(StateName.MdxEsmAtEnd), State.Next(StateName.MdxEsmContinuationStart));
                return State.Retry(StateName.MdxEsmBlankLineBefore);
            default:
                tokenizer.enter(Name.MdxEsmData);
                tokenizer.consume();
                return State.Next(StateName.MdxEsmInside);
        }
    }

    /** At start of line that continues. */
    public static function continuationStart(tokenizer:Tokenizer):State {
        tokenizer.enter(Name.LineEnding);
        tokenizer.consume();
        tokenizer.exit(Name.LineEnding);
        return State.Next(StateName.MdxEsmLineStart);
    }

    /** At start of a potentially blank line. */
    public static function blankLineBefore(tokenizer:Tokenizer):State {
        tokenizer.enter(Name.LineEnding);
        tokenizer.consume();
        tokenizer.exit(Name.LineEnding);
        return State.Next(StateName.BlankLineStart);
    }

    /** At end of line (blank or eof). */
    public static function atEnd(tokenizer:Tokenizer):State {
        var result = parseEsm(tokenizer);

        // Done!
        if (result == State.Ok) {
            tokenizer.concrete = false;
            tokenizer.exit(Name.MdxEsm);
        }

        return result;
    }

    /** Parse ESM with a given function. */
    static function parseEsm(tokenizer:Tokenizer):State {
        // We can `unwrap` because we don't parse if this is `None`.
        var parse = tokenizer.parseState.options.mdxEsmParse;

        // Collect the body of the ESM and positional info for each run of it.
        var result = MdxCollect.collect(tokenizer.events, tokenizer.parseState.bytes, tokenizer.tokenizeState.start, [Name.MdxEsmData, Name.LineEnding], []);

        // Parse and handle what was signaled back.
        switch parse(result.value) {
            case Ok:
                return State.Ok;
            case Error(message, relative, source, ruleId):
                var point = tokenizer.parseState.location.relativeToPoint(result.stops, relative);
                if (point == null)
                    throw 'expected non-empty string';
                return State.error(new Message(Place.Point(point), message, ruleId, source));
            case Eof(message, source, ruleId):
                if (tokenizer.current == -1) {
                    return State.error(new Message(Place.Point(tokenizer.point.toUnist()), message, ruleId, source));
                }
                else {
                    tokenizer.tokenizeState.mdxLastParseError = [message, source, ruleId];
                    return State.Retry(StateName.MdxEsmContinuationStart);
                }
        }
    }

}
