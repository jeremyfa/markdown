// Ported from markdown 1.0.0: src/construct/html_flow.rs
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
import markdown.util.CharUtil;
import markdown.util.Constant;
import markdown.util.Slice;

/**
 * HTML (flow) occurs in the flow content type (`html_flow.rs`).
 */
class HtmlFlow {

    /** Symbol for `<script>` (condition 1). */
    static inline var RAW:Int = 1;
    /** Symbol for `<!---->` (condition 2). */
    static inline var COMMENT:Int = 2;
    /** Symbol for `<?php?>` (condition 3). */
    static inline var INSTRUCTION:Int = 3;
    /** Symbol for `<!doctype>` (condition 4). */
    static inline var DECLARATION:Int = 4;
    /** Symbol for `<![CDATA[]]>` (condition 5). */
    static inline var CDATA:Int = 5;
    /** Symbol for `<div` (condition 6). */
    static inline var BASIC:Int = 6;
    /** Symbol for `<x>` (condition 7). */
    static inline var COMPLETE:Int = 7;

    static inline function isAlpha(c:Int):Bool {
        return (c >= 'A'.code && c <= 'Z'.code) || (c >= 'a'.code && c <= 'z'.code);
    }

    /** Start of HTML (flow). */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.htmlFlow) {
            tokenizer.enter(Name.HtmlFlow);

            if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
                tokenizer.attempt(State.Next(StateName.HtmlFlowBefore), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTabWithOptions(tokenizer, Name.HtmlFlowData, 0,
                    tokenizer.parseState.options.constructs.codeIndented ? Constant.TAB_SIZE - 1 : PartialSpaceOrTab.MAX, null, false));
            }
            else {
                return State.Retry(StateName.HtmlFlowBefore);
            }
        }
        else {
            return State.Nok;
        }
    }

    /** At `<`, after optional whitespace. */
    public static function before(tokenizer:Tokenizer):State {
        if (tokenizer.current == '<'.code) {
            tokenizer.enter(Name.HtmlFlowData);
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowOpen);
        }
        else {
            return State.Nok;
        }
    }

    /** After `<`, at tag name or other stuff. */
    public static function open(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if (c == '!'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowDeclarationOpen);
        }
        else if (c == '/'.code) {
            tokenizer.consume();
            tokenizer.tokenizeState.seen = true;
            tokenizer.tokenizeState.start = tokenizer.point.index;
            return State.Next(StateName.HtmlFlowTagCloseStart);
        }
        else if (c == '?'.code) {
            tokenizer.consume();
            tokenizer.tokenizeState.marker = INSTRUCTION;
            // Do not form containers.
            tokenizer.concrete = true;
            // While we're in an instruction instead of a declaration, we're on a `?` right now, so we do need to search for `>`, similar to declarations.
            return State.Next(StateName.HtmlFlowContinuationDeclarationInside);
        }
        // ASCII alphabetical.
        else if (isAlpha(c)) {
            tokenizer.tokenizeState.start = tokenizer.point.index;
            return State.Retry(StateName.HtmlFlowTagName);
        }
        else {
            return State.Nok;
        }
    }

    /** After `<!`, at declaration, comment, or CDATA. */
    public static function declarationOpen(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if (c == '-'.code) {
            tokenizer.consume();
            tokenizer.tokenizeState.marker = COMMENT;
            return State.Next(StateName.HtmlFlowCommentOpenInside);
        }
        else if (isAlpha(c)) {
            tokenizer.consume();
            tokenizer.tokenizeState.marker = DECLARATION;
            // Do not form containers.
            tokenizer.concrete = true;
            return State.Next(StateName.HtmlFlowContinuationDeclarationInside);
        }
        else if (c == '['.code) {
            tokenizer.consume();
            tokenizer.tokenizeState.marker = CDATA;
            return State.Next(StateName.HtmlFlowCdataOpenInside);
        }
        else {
            return State.Nok;
        }
    }

    /** After `<!-`, inside a comment, at another `-`. */
    public static function commentOpenInside(tokenizer:Tokenizer):State {
        if (tokenizer.current == '-'.code) {
            tokenizer.consume();
            // Do not form containers.
            tokenizer.concrete = true;
            return State.Next(StateName.HtmlFlowContinuationDeclarationInside);
        }
        else {
            tokenizer.tokenizeState.marker = 0;
            return State.Nok;
        }
    }

    /** After `<![`, inside CDATA, expecting `CDATA[`. */
    public static function cdataOpenInside(tokenizer:Tokenizer):State {
        if (tokenizer.current == Constant.HTML_CDATA_PREFIX[tokenizer.tokenizeState.size]) {
            tokenizer.consume();
            tokenizer.tokenizeState.size += 1;

            if (tokenizer.tokenizeState.size == Constant.HTML_CDATA_PREFIX.length) {
                tokenizer.tokenizeState.size = 0;
                // Do not form containers.
                tokenizer.concrete = true;
                return State.Next(StateName.HtmlFlowContinuation);
            }
            else {
                return State.Next(StateName.HtmlFlowCdataOpenInside);
            }
        }
        else {
            tokenizer.tokenizeState.marker = 0;
            tokenizer.tokenizeState.size = 0;
            return State.Nok;
        }
    }

    /** After `</`, in closing tag, at tag name. */
    public static function tagCloseStart(tokenizer:Tokenizer):State {
        if (isAlpha(tokenizer.current)) {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowTagName);
        }
        else {
            tokenizer.tokenizeState.seen = false;
            tokenizer.tokenizeState.start = 0;
            return State.Nok;
        }
    }

    /** In tag name. */
    public static function tagName(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if (c == -1 || c == '\t'.code || c == '\n'.code || c == ' '.code || c == '/'.code || c == '>'.code) {
            var closingTag = tokenizer.tokenizeState.seen;
            var slash = c == '/'.code;
            // Guaranteed to be valid ASCII bytes.
            var slice = Slice.fromIndices(tokenizer.parseState.bytes, tokenizer.tokenizeState.start, tokenizer.point.index);
            var name = CharUtil.asciiLowercase(StringTools.trim(slice.asStr()));
            tokenizer.tokenizeState.seen = false;
            tokenizer.tokenizeState.start = 0;

            if (!slash && !closingTag && Constant.HTML_RAW_NAMES.indexOf(name) != -1) {
                tokenizer.tokenizeState.marker = RAW;
                // Do not form containers.
                tokenizer.concrete = true;
                return State.Retry(StateName.HtmlFlowContinuation);
            }
            else if (Constant.HTML_BLOCK_NAMES.indexOf(name) != -1) {
                tokenizer.tokenizeState.marker = BASIC;

                if (slash) {
                    tokenizer.consume();
                    return State.Next(StateName.HtmlFlowBasicSelfClosing);
                }
                else {
                    // Do not form containers.
                    tokenizer.concrete = true;
                    return State.Retry(StateName.HtmlFlowContinuation);
                }
            }
            else {
                tokenizer.tokenizeState.marker = COMPLETE;

                // Do not support complete HTML when interrupting.
                if (tokenizer.interrupt && !tokenizer.lazy) {
                    tokenizer.tokenizeState.marker = 0;
                    return State.Nok;
                }
                else if (closingTag) {
                    return State.Retry(StateName.HtmlFlowCompleteClosingTagAfter);
                }
                else {
                    return State.Retry(StateName.HtmlFlowCompleteAttributeNameBefore);
                }
            }
        }
        // ASCII alphanumerical and `-`.
        else if (c == '-'.code || CharUtil.isAsciiAlphanumeric(c)) {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowTagName);
        }
        else {
            tokenizer.tokenizeState.seen = false;
            return State.Nok;
        }
    }

    /** After closing slash of a basic tag name. */
    public static function basicSelfClosing(tokenizer:Tokenizer):State {
        if (tokenizer.current == '>'.code) {
            tokenizer.consume();
            // Do not form containers.
            tokenizer.concrete = true;
            return State.Next(StateName.HtmlFlowContinuation);
        }
        else {
            tokenizer.tokenizeState.marker = 0;
            return State.Nok;
        }
    }

    /** After closing slash of a complete tag name. */
    public static function completeClosingTagAfter(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\t'.code | ' '.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlFlowCompleteClosingTagAfter);
            default:
                return State.Retry(StateName.HtmlFlowCompleteEnd);
        }
    }

    /** At an attribute name. */
    public static function completeAttributeNameBefore(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if (c == '\t'.code || c == ' '.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowCompleteAttributeNameBefore);
        }
        else if (c == '/'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowCompleteEnd);
        }
        // ASCII alphanumerical and `:` and `_`.
        else if ((c >= '0'.code && c <= '9'.code) || c == ':'.code || isAlpha(c) || c == '_'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowCompleteAttributeName);
        }
        else {
            return State.Retry(StateName.HtmlFlowCompleteEnd);
        }
    }

    /** In attribute name. */
    public static function completeAttributeName(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // ASCII alphanumerical and `-`, `.`, `:`, and `_`.
        if (c == '-'.code || c == '.'.code || (c >= '0'.code && c <= '9'.code) || c == ':'.code || isAlpha(c) || c == '_'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowCompleteAttributeName);
        }
        else {
            return State.Retry(StateName.HtmlFlowCompleteAttributeNameAfter);
        }
    }

    /** After attribute name, at an optional initializer, the end of the tag, or whitespace. */
    public static function completeAttributeNameAfter(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\t'.code | ' '.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlFlowCompleteAttributeNameAfter);
            case '='.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlFlowCompleteAttributeValueBefore);
            default:
                return State.Retry(StateName.HtmlFlowCompleteAttributeNameBefore);
        }
    }

    /** Before unquoted, double quoted, or single quoted attribute value, allowing whitespace. */
    public static function completeAttributeValueBefore(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '<'.code | '='.code | '>'.code | '`'.code:
                tokenizer.tokenizeState.marker = 0;
                return State.Nok;
            case '\t'.code | ' '.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlFlowCompleteAttributeValueBefore);
            case '"'.code | "'".code:
                tokenizer.tokenizeState.markerB = tokenizer.current;
                tokenizer.consume();
                return State.Next(StateName.HtmlFlowCompleteAttributeValueQuoted);
            default:
                return State.Retry(StateName.HtmlFlowCompleteAttributeValueUnquoted);
        }
    }

    /** In double or single quoted attribute value. */
    public static function completeAttributeValueQuoted(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.markerB) {
            tokenizer.consume();
            tokenizer.tokenizeState.markerB = 0;
            return State.Next(StateName.HtmlFlowCompleteAttributeValueQuotedAfter);
        }
        else if (tokenizer.current == -1 || tokenizer.current == '\n'.code) {
            tokenizer.tokenizeState.marker = 0;
            tokenizer.tokenizeState.markerB = 0;
            return State.Nok;
        }
        else {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowCompleteAttributeValueQuoted);
        }
    }

    /** In unquoted attribute value. */
    public static function completeAttributeValueUnquoted(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\t'.code | '\n'.code | ' '.code | '"'.code | "'".code | '/'.code | '<'.code | '='.code | '>'.code | '`'.code:
                return State.Retry(StateName.HtmlFlowCompleteAttributeNameAfter);
            default:
                tokenizer.consume();
                return State.Next(StateName.HtmlFlowCompleteAttributeValueUnquoted);
        }
    }

    /** After double or single quoted attribute value, before whitespace or the end of the tag. */
    public static function completeAttributeValueQuotedAfter(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\t'.code | ' '.code | '/'.code | '>'.code:
                return State.Retry(StateName.HtmlFlowCompleteAttributeNameBefore);
            default:
                tokenizer.tokenizeState.marker = 0;
                return State.Nok;
        }
    }

    /** In certain circumstances of a complete tag where only an `>` is allowed. */
    public static function completeEnd(tokenizer:Tokenizer):State {
        if (tokenizer.current == '>'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowCompleteAfter);
        }
        else {
            tokenizer.tokenizeState.marker = 0;
            return State.Nok;
        }
    }

    /** After `>` in a complete tag. */
    public static function completeAfter(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                // Do not form containers.
                tokenizer.concrete = true;
                return State.Retry(StateName.HtmlFlowContinuation);
            case '\t'.code | ' '.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlFlowCompleteAfter);
            default:
                tokenizer.tokenizeState.marker = 0;
                return State.Nok;
        }
    }

    /** In continuation of any HTML kind. */
    public static function continuation(tokenizer:Tokenizer):State {
        var marker = tokenizer.tokenizeState.marker;
        var c = tokenizer.current;
        if (marker == COMMENT && c == '-'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowContinuationCommentInside);
        }
        else if (marker == RAW && c == '<'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowContinuationRawTagOpen);
        }
        else if (marker == DECLARATION && c == '>'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowContinuationClose);
        }
        else if (marker == INSTRUCTION && c == '?'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowContinuationDeclarationInside);
        }
        else if (marker == CDATA && c == ']'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowContinuationCdataInside);
        }
        else if ((marker == BASIC || marker == COMPLETE) && c == '\n'.code) {
            tokenizer.exit(Name.HtmlFlowData);
            tokenizer.check(State.Next(StateName.HtmlFlowContinuationAfter), State.Next(StateName.HtmlFlowContinuationStart));
            return State.Retry(StateName.HtmlFlowBlankLineBefore);
        }
        else if (c == -1 || c == '\n'.code) {
            tokenizer.exit(Name.HtmlFlowData);
            return State.Retry(StateName.HtmlFlowContinuationStart);
        }
        else {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowContinuation);
        }
    }

    /** In continuation, at eol. */
    public static function continuationStart(tokenizer:Tokenizer):State {
        tokenizer.check(State.Next(StateName.HtmlFlowContinuationStartNonLazy), State.Next(StateName.HtmlFlowContinuationAfter));
        return State.Retry(StateName.NonLazyContinuationStart);
    }

    /** In continuation, at eol, before non-lazy content. */
    public static function continuationStartNonLazy(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\n'.code:
                tokenizer.enter(Name.LineEnding);
                tokenizer.consume();
                tokenizer.exit(Name.LineEnding);
                return State.Next(StateName.HtmlFlowContinuationBefore);
            default:
                throw 'expected eol';
        }
    }

    /** In continuation, before non-lazy content. */
    public static function continuationBefore(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                return State.Retry(StateName.HtmlFlowContinuationStart);
            default:
                tokenizer.enter(Name.HtmlFlowData);
                return State.Retry(StateName.HtmlFlowContinuation);
        }
    }

    /** In comment continuation, after one `-`, expecting another. */
    public static function continuationCommentInside(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '-'.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlFlowContinuationDeclarationInside);
            default:
                return State.Retry(StateName.HtmlFlowContinuation);
        }
    }

    /** In raw continuation, after `<`, at `/`. */
    public static function continuationRawTagOpen(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '/'.code:
                tokenizer.consume();
                tokenizer.tokenizeState.start = tokenizer.point.index;
                return State.Next(StateName.HtmlFlowContinuationRawEndTag);
            default:
                return State.Retry(StateName.HtmlFlowContinuation);
        }
    }

    /** In raw continuation, after `</`, in a raw tag name. */
    public static function continuationRawEndTag(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if (c == '>'.code) {
            // Guaranteed to be valid ASCII bytes.
            var slice = Slice.fromIndices(tokenizer.parseState.bytes, tokenizer.tokenizeState.start, tokenizer.point.index);
            var name = CharUtil.asciiLowercase(slice.asStr());

            tokenizer.tokenizeState.start = 0;

            if (Constant.HTML_RAW_NAMES.indexOf(name) != -1) {
                tokenizer.consume();
                return State.Next(StateName.HtmlFlowContinuationClose);
            }
            else {
                return State.Retry(StateName.HtmlFlowContinuation);
            }
        }
        else if (isAlpha(c) && tokenizer.point.index - tokenizer.tokenizeState.start < Constant.HTML_RAW_SIZE_MAX) {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowContinuationRawEndTag);
        }
        else {
            tokenizer.tokenizeState.start = 0;
            return State.Retry(StateName.HtmlFlowContinuation);
        }
    }

    /** In cdata continuation, after `]`, expecting `]>`. */
    public static function continuationCdataInside(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case ']'.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlFlowContinuationDeclarationInside);
            default:
                return State.Retry(StateName.HtmlFlowContinuation);
        }
    }

    /** In declaration or instruction continuation, at `>`. */
    public static function continuationDeclarationInside(tokenizer:Tokenizer):State {
        if (tokenizer.tokenizeState.marker == COMMENT && tokenizer.current == '-'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowContinuationDeclarationInside);
        }
        else if (tokenizer.current == '>'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlFlowContinuationClose);
        }
        else {
            return State.Retry(StateName.HtmlFlowContinuation);
        }
    }

    /** In closed continuation: everything we get until the eol/eof is part of it. */
    public static function continuationClose(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                tokenizer.exit(Name.HtmlFlowData);
                return State.Retry(StateName.HtmlFlowContinuationAfter);
            default:
                tokenizer.consume();
                return State.Next(StateName.HtmlFlowContinuationClose);
        }
    }

    /** Done. */
    public static function continuationAfter(tokenizer:Tokenizer):State {
        tokenizer.exit(Name.HtmlFlow);
        tokenizer.tokenizeState.marker = 0;
        // Feel free to interrupt.
        tokenizer.interrupt = false;
        // No longer concrete.
        tokenizer.concrete = false;
        return State.Ok;
    }

    /** Before eol, expecting blank line. */
    public static function blankLineBefore(tokenizer:Tokenizer):State {
        tokenizer.enter(Name.LineEnding);
        tokenizer.consume();
        tokenizer.exit(Name.LineEnding);
        return State.Next(StateName.BlankLineStart);
    }

}
