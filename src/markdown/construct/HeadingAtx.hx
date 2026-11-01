// Ported from markdown 1.0.0: src/construct/heading_atx.rs
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
 * Heading (atx) occurs in the flow content type (`heading_atx.rs`).
 */
class HeadingAtx {

    /** Start of a heading (atx). */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.headingAtx) {
            tokenizer.enter(Name.HeadingAtx);
            if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
                tokenizer.attempt(State.Next(StateName.HeadingAtxBefore), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 0,
                    tokenizer.parseState.options.constructs.codeIndented ? Constant.TAB_SIZE - 1 : PartialSpaceOrTab.MAX));
            }
            else {
                return State.Retry(StateName.HeadingAtxBefore);
            }
        }
        else {
            return State.Nok;
        }
    }

    /** After optional whitespace, at `#`. */
    public static function before(tokenizer:Tokenizer):State {
        if (tokenizer.current == '#'.code) {
            tokenizer.enter(Name.HeadingAtxSequence);
            return State.Retry(StateName.HeadingAtxSequenceOpen);
        }
        else {
            return State.Nok;
        }
    }

    /** In opening sequence. */
    public static function sequenceOpen(tokenizer:Tokenizer):State {
        if (tokenizer.current == '#'.code && tokenizer.tokenizeState.size < Constant.HEADING_ATX_OPENING_FENCE_SIZE_MAX) {
            tokenizer.tokenizeState.size += 1;
            tokenizer.consume();
            return State.Next(StateName.HeadingAtxSequenceOpen);
        }
        // Always at least one `#`.
        else if (tokenizer.current == -1 || tokenizer.current == '\t'.code || tokenizer.current == '\n'.code || tokenizer.current == ' '.code) {
            tokenizer.tokenizeState.size = 0;
            tokenizer.exit(Name.HeadingAtxSequence);
            return State.Retry(StateName.HeadingAtxAtBreak);
        }
        else {
            tokenizer.tokenizeState.size = 0;
            return State.Nok;
        }
    }

    /** After something, before something else. */
    public static function atBreak(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                tokenizer.exit(Name.HeadingAtx);
                tokenizer.registerResolver(ResolveName.HeadingAtx);
                // Feel free to interrupt.
                tokenizer.interrupt = false;
                return State.Ok;
            case '\t'.code | ' '.code:
                tokenizer.attempt(State.Next(StateName.HeadingAtxAtBreak), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
            case '#'.code:
                tokenizer.enter(Name.HeadingAtxSequence);
                return State.Retry(StateName.HeadingAtxSequenceFurther);
            default:
                tokenizer.enterLink(Name.Data, new Link(-1, -1, Content.Text));
                return State.Retry(StateName.HeadingAtxData);
        }
    }

    /** In further sequence (after whitespace). */
    public static function sequenceFurther(tokenizer:Tokenizer):State {
        if (tokenizer.current == '#'.code) {
            tokenizer.consume();
            return State.Next(StateName.HeadingAtxSequenceFurther);
        }
        else {
            tokenizer.exit(Name.HeadingAtxSequence);
            return State.Retry(StateName.HeadingAtxAtBreak);
        }
    }

    /** In text. */
    public static function data(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            // Note: `#` for closing sequence must be preceded by whitespace, otherwise it's just text.
            case -1 | '\t'.code | '\n'.code | ' '.code:
                tokenizer.exit(Name.Data);
                return State.Retry(StateName.HeadingAtxAtBreak);
            default:
                tokenizer.consume();
                return State.Next(StateName.HeadingAtxData);
        }
    }

    /** Resolve heading (atx). */
    public static function resolve(tokenizer:Tokenizer):Null<Subresult> {
        var index = 0;
        var headingInside = false;
        var dataStart = -1;
        var dataEnd = -1;

        while (index < tokenizer.events.length) {
            var event = tokenizer.events[index];

            if (event.name == Name.HeadingAtx) {
                if (event.kind == Kind.Enter) {
                    headingInside = true;
                }
                else {
                    if (dataStart != -1) {
                        var start = dataStart;
                        var end = dataEnd;
                        // If `start` is some, `end` is too.
                        tokenizer.map.add(start, 0, [new Event(Kind.Enter, Name.HeadingAtxText, tokenizer.events[start].point.clone(), null)]);

                        // Remove everything between the start and the end.
                        tokenizer.map.add(start + 1, end - start - 1, []);

                        tokenizer.map.add(end + 1, 0, [new Event(Kind.Exit, Name.HeadingAtxText, tokenizer.events[end].point.clone(), null)]);
                    }

                    headingInside = false;
                    dataStart = -1;
                    dataEnd = -1;
                }
            }
            else if (headingInside && event.name == Name.Data) {
                if (event.kind == Kind.Enter) {
                    if (dataStart == -1) {
                        dataStart = index;
                    }
                }
                else {
                    dataEnd = index;
                }
            }

            index += 1;
        }

        tokenizer.map.consume(tokenizer.events);
        return null;
    }

}
