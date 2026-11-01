// Ported from markdown 1.0.0: src/construct/raw_flow.rs
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
import markdown.util.Slice;

/**
 * Raw (flow) occurs in the flow content type: code (fenced) and math (flow)
 * (`raw_flow.rs`).
 */
class RawFlow {

    /** Start of raw. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.codeFenced || tokenizer.parseState.options.constructs.mathFlow) {
            if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
                tokenizer.attempt(State.Next(StateName.RawFlowBeforeSequenceOpen), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 0,
                    tokenizer.parseState.options.constructs.codeIndented ? Constant.TAB_SIZE - 1 : PartialSpaceOrTab.MAX));
            }

            if (tokenizer.current == '$'.code || tokenizer.current == '`'.code || tokenizer.current == '~'.code) {
                return State.Retry(StateName.RawFlowBeforeSequenceOpen);
            }
        }

        return State.Nok;
    }

    /** In opening fence, after prefix, at sequence. */
    public static function beforeSequenceOpen(tokenizer:Tokenizer):State {
        var prefix = 0;

        if (tokenizer.events.length > 0) {
            var event = tokenizer.events[tokenizer.events.length - 1];
            if (event.name == Name.SpaceOrTab) {
                prefix = Slice.fromPosition(tokenizer.parseState.bytes, SlicePosition.fromExitEvent(tokenizer.events, tokenizer.events.length - 1)).len();
            }
        }

        // Code (fenced).
        if ((tokenizer.parseState.options.constructs.codeFenced && (tokenizer.current == '`'.code || tokenizer.current == '~'.code))
            // Math (flow).
            || (tokenizer.parseState.options.constructs.mathFlow && tokenizer.current == '$'.code)) {
            tokenizer.tokenizeState.marker = tokenizer.current;
            tokenizer.tokenizeState.sizeC = prefix;
            if (tokenizer.tokenizeState.marker == '$'.code) {
                tokenizer.tokenizeState.token1 = Name.MathFlow;
                tokenizer.tokenizeState.token2 = Name.MathFlowFence;
                tokenizer.tokenizeState.token3 = Name.MathFlowFenceSequence;
                // Math (flow) does not support an `info` part: everything after the opening sequence is the `meta` part.
                tokenizer.tokenizeState.token5 = Name.MathFlowFenceMeta;
                tokenizer.tokenizeState.token6 = Name.MathFlowChunk;
            }
            else {
                tokenizer.tokenizeState.token1 = Name.CodeFenced;
                tokenizer.tokenizeState.token2 = Name.CodeFencedFence;
                tokenizer.tokenizeState.token3 = Name.CodeFencedFenceSequence;
                tokenizer.tokenizeState.token4 = Name.CodeFencedFenceInfo;
                tokenizer.tokenizeState.token5 = Name.CodeFencedFenceMeta;
                tokenizer.tokenizeState.token6 = Name.CodeFlowChunk;
            }

            tokenizer.enter(tokenizer.tokenizeState.token1);
            tokenizer.enter(tokenizer.tokenizeState.token2);
            tokenizer.enter(tokenizer.tokenizeState.token3);
            return State.Retry(StateName.RawFlowSequenceOpen);
        }
        else {
            return State.Nok;
        }
    }

    static function reset(tokenizer:Tokenizer):Void {
        tokenizer.tokenizeState.marker = 0;
        tokenizer.tokenizeState.sizeC = 0;
        tokenizer.tokenizeState.size = 0;
        tokenizer.tokenizeState.token1 = Name.Data;
        tokenizer.tokenizeState.token2 = Name.Data;
        tokenizer.tokenizeState.token3 = Name.Data;
        tokenizer.tokenizeState.token4 = Name.Data;
        tokenizer.tokenizeState.token5 = Name.Data;
        tokenizer.tokenizeState.token6 = Name.Data;
    }

    /** In opening fence sequence. */
    public static function sequenceOpen(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.marker) {
            tokenizer.tokenizeState.size += 1;
            tokenizer.consume();
            return State.Next(StateName.RawFlowSequenceOpen);
        }
        // To do: constant.
        else if (tokenizer.tokenizeState.size < (tokenizer.tokenizeState.marker == '$'.code ? Constant.MATH_FLOW_SEQUENCE_SIZE_MIN : Constant.CODE_FENCED_SEQUENCE_SIZE_MIN)) {
            reset(tokenizer);
            return State.Nok;
        }
        else {
            // Math (flow) does not support an `info` part: everything after the opening sequence is the `meta` part.
            var next = tokenizer.tokenizeState.marker == '$'.code ? StateName.RawFlowMetaBefore : StateName.RawFlowInfoBefore;

            if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
                tokenizer.exit(tokenizer.tokenizeState.token3);
                tokenizer.attempt(State.Next(next), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
            }
            else {
                tokenizer.exit(tokenizer.tokenizeState.token3);
                return State.Retry(next);
            }
        }
    }

    /** In opening fence, after the sequence (and optional whitespace), before info. */
    public static function infoBefore(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                tokenizer.exit(tokenizer.tokenizeState.token2);
                // Do not form containers.
                tokenizer.concrete = true;
                tokenizer.check(State.Next(StateName.RawFlowAtNonLazyBreak), State.Next(StateName.RawFlowAfter));
                return State.Retry(StateName.NonLazyContinuationStart);
            default:
                tokenizer.enter(tokenizer.tokenizeState.token4);
                tokenizer.enterLink(Name.Data, new Link(-1, -1, Content.String));
                return State.Retry(StateName.RawFlowInfo);
        }
    }

    /** In info. */
    public static function info(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                tokenizer.exit(Name.Data);
                tokenizer.exit(tokenizer.tokenizeState.token4);
                return State.Retry(StateName.RawFlowInfoBefore);
            case '\t'.code | ' '.code:
                tokenizer.exit(Name.Data);
                tokenizer.exit(tokenizer.tokenizeState.token4);
                tokenizer.attempt(State.Next(StateName.RawFlowMetaBefore), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
            case byte:
                // This looks like code (text) / math (text).
                // Note: no reason to check for `~`, because 3 of them can't be used as strikethrough in text.
                if (tokenizer.tokenizeState.marker == byte && (byte == '$'.code || byte == '`'.code)) {
                    tokenizer.concrete = false;
                    reset(tokenizer);
                    return State.Nok;
                }
                else {
                    tokenizer.consume();
                    return State.Next(StateName.RawFlowInfo);
                }
        }
    }

    /** In opening fence, after info and whitespace, before meta. */
    public static function metaBefore(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                return State.Retry(StateName.RawFlowInfoBefore);
            default:
                tokenizer.enter(tokenizer.tokenizeState.token5);
                tokenizer.enterLink(Name.Data, new Link(-1, -1, Content.String));
                return State.Retry(StateName.RawFlowMeta);
        }
    }

    /** In meta. */
    public static function meta(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                tokenizer.exit(Name.Data);
                tokenizer.exit(tokenizer.tokenizeState.token5);
                return State.Retry(StateName.RawFlowInfoBefore);
            case byte:
                // This looks like code (text) / math (text).
                if (tokenizer.tokenizeState.marker == byte && (byte == '$'.code || byte == '`'.code)) {
                    tokenizer.concrete = false;
                    reset(tokenizer);
                    return State.Nok;
                }
                else {
                    tokenizer.consume();
                    return State.Next(StateName.RawFlowMeta);
                }
        }
    }

    /** At eol/eof in raw, before a non-lazy closing fence or content. */
    public static function atNonLazyBreak(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.RawFlowAfter), State.Next(StateName.RawFlowContentBefore));
        tokenizer.enter(Name.LineEnding);
        tokenizer.consume();
        tokenizer.exit(Name.LineEnding);
        return State.Next(StateName.RawFlowCloseStart);
    }

    /** Before closing fence, at optional whitespace. */
    public static function closeStart(tokenizer:Tokenizer):State {
        tokenizer.enter(tokenizer.tokenizeState.token2);

        if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            tokenizer.attempt(State.Next(StateName.RawFlowBeforeSequenceClose), State.Nok);
            return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 0,
                tokenizer.parseState.options.constructs.codeIndented ? Constant.TAB_SIZE - 1 : PartialSpaceOrTab.MAX));
        }
        else {
            return State.Retry(StateName.RawFlowBeforeSequenceClose);
        }
    }

    /** In closing fence, after optional whitespace, at sequence. */
    public static function beforeSequenceClose(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.marker) {
            tokenizer.enter(tokenizer.tokenizeState.token3);
            return State.Retry(StateName.RawFlowSequenceClose);
        }
        else {
            return State.Nok;
        }
    }

    /** In closing fence sequence. */
    public static function sequenceClose(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.marker) {
            tokenizer.tokenizeState.sizeB += 1;
            tokenizer.consume();
            return State.Next(StateName.RawFlowSequenceClose);
        }
        else if (tokenizer.tokenizeState.sizeB >= tokenizer.tokenizeState.size) {
            tokenizer.tokenizeState.sizeB = 0;
            tokenizer.exit(tokenizer.tokenizeState.token3);

            if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
                tokenizer.attempt(State.Next(StateName.RawFlowAfterSequenceClose), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
            }
            else {
                return State.Retry(StateName.RawFlowAfterSequenceClose);
            }
        }
        else {
            tokenizer.tokenizeState.sizeB = 0;
            return State.Nok;
        }
    }

    /** After closing fence sequence, after optional whitespace. */
    public static function sequenceCloseAfter(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                tokenizer.exit(tokenizer.tokenizeState.token2);
                return State.Ok;
            default:
                return State.Nok;
        }
    }

    /** Before raw content, not a closing fence, at eol. */
    public static function contentBefore(tokenizer:Tokenizer):State {
        tokenizer.enter(Name.LineEnding);
        tokenizer.consume();
        tokenizer.exit(Name.LineEnding);
        return State.Next(StateName.RawFlowContentStart);
    }

    /** Before raw content, not a closing fence. */
    public static function contentStart(tokenizer:Tokenizer):State {
        if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            tokenizer.attempt(State.Next(StateName.RawFlowBeforeContentChunk), State.Nok);
            return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 0, tokenizer.tokenizeState.sizeC));
        }
        else {
            return State.Retry(StateName.RawFlowBeforeContentChunk);
        }
    }

    /** Before raw content, after optional prefix. */
    public static function beforeContentChunk(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                tokenizer.check(State.Next(StateName.RawFlowAtNonLazyBreak), State.Next(StateName.RawFlowAfter));
                return State.Retry(StateName.NonLazyContinuationStart);
            default:
                tokenizer.enter(tokenizer.tokenizeState.token6);
                return State.Retry(StateName.RawFlowContentChunk);
        }
    }

    /** In raw content. */
    public static function contentChunk(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                tokenizer.exit(tokenizer.tokenizeState.token6);
                return State.Retry(StateName.RawFlowBeforeContentChunk);
            default:
                tokenizer.consume();
                return State.Next(StateName.RawFlowContentChunk);
        }
    }

    /** After raw. */
    public static function after(tokenizer:Tokenizer):State {
        tokenizer.exit(tokenizer.tokenizeState.token1);
        reset(tokenizer);
        // Feel free to interrupt.
        tokenizer.interrupt = false;
        // No longer concrete.
        tokenizer.concrete = false;
        return State.Ok;
    }

}
