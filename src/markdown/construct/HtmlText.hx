// Ported from markdown 1.0.0: src/construct/html_text.rs
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

/**
 * HTML (text) occurs in the text content type (`html_text.rs`).
 */
class HtmlText {

    static inline function isAlpha(c:Int):Bool {
        return (c >= 'A'.code && c <= 'Z'.code) || (c >= 'a'.code && c <= 'z'.code);
    }

    /** Start of HTML (text). */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.current == '<'.code && tokenizer.parseState.options.constructs.htmlText) {
            tokenizer.enter(Name.HtmlText);
            tokenizer.enter(Name.HtmlTextData);
            tokenizer.consume();
            return State.Next(StateName.HtmlTextOpen);
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
            return State.Next(StateName.HtmlTextDeclarationOpen);
        }
        else if (c == '/'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlTextTagCloseStart);
        }
        else if (c == '?'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlTextInstruction);
        }
        // ASCII alphabetical.
        else if (isAlpha(c)) {
            tokenizer.consume();
            return State.Next(StateName.HtmlTextTagOpen);
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
            return State.Next(StateName.HtmlTextCommentOpenInside);
        }
        // ASCII alphabetical.
        else if (isAlpha(c)) {
            tokenizer.consume();
            return State.Next(StateName.HtmlTextDeclaration);
        }
        else if (c == '['.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlTextCdataOpenInside);
        }
        else {
            return State.Nok;
        }
    }

    /** In a comment, after `<!-`, at another `-`. */
    public static function commentOpenInside(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '-'.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlTextCommentEnd);
            default:
                return State.Nok;
        }
    }

    /** In comment. */
    public static function comment(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1:
                return State.Nok;
            case '\n'.code:
                tokenizer.attempt(State.Next(StateName.HtmlTextComment), State.Nok);
                return State.Retry(StateName.HtmlTextLineEndingBefore);
            case '-'.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlTextCommentClose);
            default:
                tokenizer.consume();
                return State.Next(StateName.HtmlTextComment);
        }
    }

    /** In comment, after `-`. */
    public static function commentClose(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '-'.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlTextCommentEnd);
            default:
                return State.Retry(StateName.HtmlTextComment);
        }
    }

    /** In comment, after `--`. */
    public static function commentEnd(tokenizer:Tokenizer):State {
        return switch tokenizer.current {
            case '>'.code: State.Retry(StateName.HtmlTextEnd);
            case '-'.code: State.Retry(StateName.HtmlTextCommentClose);
            default: State.Retry(StateName.HtmlTextComment);
        }
    }

    /** After `<![`, in CDATA, expecting `CDATA[`. */
    public static function cdataOpenInside(tokenizer:Tokenizer):State {
        if (tokenizer.current == Constant.HTML_CDATA_PREFIX[tokenizer.tokenizeState.size]) {
            tokenizer.tokenizeState.size += 1;
            tokenizer.consume();

            if (tokenizer.tokenizeState.size == Constant.HTML_CDATA_PREFIX.length) {
                tokenizer.tokenizeState.size = 0;
                return State.Next(StateName.HtmlTextCdata);
            }
            else {
                return State.Next(StateName.HtmlTextCdataOpenInside);
            }
        }
        else {
            return State.Nok;
        }
    }

    /** In CDATA. */
    public static function cdata(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1:
                return State.Nok;
            case '\n'.code:
                tokenizer.attempt(State.Next(StateName.HtmlTextCdata), State.Nok);
                return State.Retry(StateName.HtmlTextLineEndingBefore);
            case ']'.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlTextCdataClose);
            default:
                tokenizer.consume();
                return State.Next(StateName.HtmlTextCdata);
        }
    }

    /** In CDATA, after `]`, at another `]`. */
    public static function cdataClose(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case ']'.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlTextCdataEnd);
            default:
                return State.Retry(StateName.HtmlTextCdata);
        }
    }

    /** In CDATA, after `]]`, at `>`. */
    public static function cdataEnd(tokenizer:Tokenizer):State {
        return switch tokenizer.current {
            case '>'.code: State.Retry(StateName.HtmlTextEnd);
            case ']'.code: State.Retry(StateName.HtmlTextCdataClose);
            default: State.Retry(StateName.HtmlTextCdata);
        }
    }

    /** In declaration. */
    public static function declaration(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '>'.code:
                return State.Retry(StateName.HtmlTextEnd);
            case '\n'.code:
                tokenizer.attempt(State.Next(StateName.HtmlTextDeclaration), State.Nok);
                return State.Retry(StateName.HtmlTextLineEndingBefore);
            default:
                tokenizer.consume();
                return State.Next(StateName.HtmlTextDeclaration);
        }
    }

    /** In instruction. */
    public static function instruction(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1:
                return State.Nok;
            case '\n'.code:
                tokenizer.attempt(State.Next(StateName.HtmlTextInstruction), State.Nok);
                return State.Retry(StateName.HtmlTextLineEndingBefore);
            case '?'.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlTextInstructionClose);
            default:
                tokenizer.consume();
                return State.Next(StateName.HtmlTextInstruction);
        }
    }

    /** In instruction, after `?`, at `>`. */
    public static function instructionClose(tokenizer:Tokenizer):State {
        return switch tokenizer.current {
            case '>'.code: State.Retry(StateName.HtmlTextEnd);
            default: State.Retry(StateName.HtmlTextInstruction);
        }
    }

    /** After `</`, in closing tag, at tag name. */
    public static function tagCloseStart(tokenizer:Tokenizer):State {
        // ASCII alphabetical.
        if (isAlpha(tokenizer.current)) {
            tokenizer.consume();
            return State.Next(StateName.HtmlTextTagClose);
        }
        return State.Nok;
    }

    /** After `</x`, in a tag name. */
    public static function tagClose(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // ASCII alphanumerical and `-`.
        if (c == '-'.code || CharUtil.isAsciiAlphanumeric(c)) {
            tokenizer.consume();
            return State.Next(StateName.HtmlTextTagClose);
        }
        return State.Retry(StateName.HtmlTextTagCloseBetween);
    }

    /** In closing tag, after tag name. */
    public static function tagCloseBetween(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\n'.code:
                tokenizer.attempt(State.Next(StateName.HtmlTextTagCloseBetween), State.Nok);
                return State.Retry(StateName.HtmlTextLineEndingBefore);
            case '\t'.code | ' '.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlTextTagCloseBetween);
            default:
                return State.Retry(StateName.HtmlTextEnd);
        }
    }

    /** After `<x`, in opening tag name. */
    public static function tagOpen(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // ASCII alphanumerical and `-`.
        if (c == '-'.code || CharUtil.isAsciiAlphanumeric(c)) {
            tokenizer.consume();
            return State.Next(StateName.HtmlTextTagOpen);
        }
        else if (c == '\t'.code || c == '\n'.code || c == ' '.code || c == '/'.code || c == '>'.code) {
            return State.Retry(StateName.HtmlTextTagOpenBetween);
        }
        return State.Nok;
    }

    /** In opening tag, after tag name. */
    public static function tagOpenBetween(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if (c == '\n'.code) {
            tokenizer.attempt(State.Next(StateName.HtmlTextTagOpenBetween), State.Nok);
            return State.Retry(StateName.HtmlTextLineEndingBefore);
        }
        else if (c == '\t'.code || c == ' '.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlTextTagOpenBetween);
        }
        else if (c == '/'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlTextEnd);
        }
        // ASCII alphabetical and `:` and `_`.
        else if (c == ':'.code || isAlpha(c) || c == '_'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlTextTagOpenAttributeName);
        }
        return State.Retry(StateName.HtmlTextEnd);
    }

    /** In attribute name. */
    public static function tagOpenAttributeName(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // ASCII alphabetical and `-`, `.`, `:`, and `_`.
        if (c == '-'.code || c == '.'.code || (c >= '0'.code && c <= '9'.code) || c == ':'.code || isAlpha(c) || c == '_'.code) {
            tokenizer.consume();
            return State.Next(StateName.HtmlTextTagOpenAttributeName);
        }
        return State.Retry(StateName.HtmlTextTagOpenAttributeNameAfter);
    }

    /** After attribute name, before initializer, the end of the tag, or whitespace. */
    public static function tagOpenAttributeNameAfter(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\n'.code:
                tokenizer.attempt(State.Next(StateName.HtmlTextTagOpenAttributeNameAfter), State.Nok);
                return State.Retry(StateName.HtmlTextLineEndingBefore);
            case '\t'.code | ' '.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlTextTagOpenAttributeNameAfter);
            case '='.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlTextTagOpenAttributeValueBefore);
            default:
                return State.Retry(StateName.HtmlTextTagOpenBetween);
        }
    }

    /** Before unquoted, double quoted, or single quoted attribute value, allowing whitespace. */
    public static function tagOpenAttributeValueBefore(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '<'.code | '='.code | '>'.code | '`'.code:
                return State.Nok;
            case '\n'.code:
                tokenizer.attempt(State.Next(StateName.HtmlTextTagOpenAttributeValueBefore), State.Nok);
                return State.Retry(StateName.HtmlTextLineEndingBefore);
            case '\t'.code | ' '.code:
                tokenizer.consume();
                return State.Next(StateName.HtmlTextTagOpenAttributeValueBefore);
            case '"'.code | "'".code:
                tokenizer.tokenizeState.marker = tokenizer.current;
                tokenizer.consume();
                return State.Next(StateName.HtmlTextTagOpenAttributeValueQuoted);
            default:
                tokenizer.consume();
                return State.Next(StateName.HtmlTextTagOpenAttributeValueUnquoted);
        }
    }

    /** In double or single quoted attribute value. */
    public static function tagOpenAttributeValueQuoted(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.marker) {
            tokenizer.tokenizeState.marker = 0;
            tokenizer.consume();
            return State.Next(StateName.HtmlTextTagOpenAttributeValueQuotedAfter);
        }
        else {
            switch tokenizer.current {
                case -1:
                    tokenizer.tokenizeState.marker = 0;
                    return State.Nok;
                case '\n'.code:
                    tokenizer.attempt(State.Next(StateName.HtmlTextTagOpenAttributeValueQuoted), State.Nok);
                    return State.Retry(StateName.HtmlTextLineEndingBefore);
                default:
                    tokenizer.consume();
                    return State.Next(StateName.HtmlTextTagOpenAttributeValueQuoted);
            }
        }
    }

    /** In unquoted attribute value. */
    public static function tagOpenAttributeValueUnquoted(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '"'.code | "'".code | '<'.code | '='.code | '`'.code:
                return State.Nok;
            case '\t'.code | '\n'.code | ' '.code | '/'.code | '>'.code:
                return State.Retry(StateName.HtmlTextTagOpenBetween);
            default:
                tokenizer.consume();
                return State.Next(StateName.HtmlTextTagOpenAttributeValueUnquoted);
        }
    }

    /** After double or single quoted attribute value, before whitespace or the end of the tag. */
    public static function tagOpenAttributeValueQuotedAfter(tokenizer:Tokenizer):State {
        return switch tokenizer.current {
            case '\t'.code | '\n'.code | ' '.code | '/'.code | '>'.code: State.Retry(StateName.HtmlTextTagOpenBetween);
            default: State.Nok;
        }
    }

    /** In certain circumstances of a tag where only an `>` is allowed. */
    public static function end(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '>'.code:
                tokenizer.consume();
                tokenizer.exit(Name.HtmlTextData);
                tokenizer.exit(Name.HtmlText);
                return State.Ok;
            default:
                return State.Nok;
        }
    }

    /** At eol. */
    public static function lineEndingBefore(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\n'.code:
                tokenizer.exit(Name.HtmlTextData);
                tokenizer.enter(Name.LineEnding);
                tokenizer.consume();
                tokenizer.exit(Name.LineEnding);
                return State.Next(StateName.HtmlTextLineEndingAfter);
            default:
                throw 'expected eol';
        }
    }

    /** After eol, at optional whitespace. */
    public static function lineEndingAfter(tokenizer:Tokenizer):State {
        if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            tokenizer.attempt(State.Next(StateName.HtmlTextLineEndingAfterPrefix), State.Nok);
            return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
        }
        else {
            return State.Retry(StateName.HtmlTextLineEndingAfterPrefix);
        }
    }

    /** After eol, after optional whitespace. */
    public static function lineEndingAfterPrefix(tokenizer:Tokenizer):State {
        tokenizer.enter(Name.HtmlTextData);
        return State.Ok;
    }

}
