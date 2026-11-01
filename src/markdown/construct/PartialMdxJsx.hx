// Ported from markdown 1.0.0: src/construct/partial_mdx_jsx.rs
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
import markdown.util.CharUtil;
import markdown.util.Identifier;

/**
 * MDX JSX occurs in MDX JSX (flow) and MDX JSX (text) (`partial_mdx_jsx.rs`).
 */
class PartialMdxJsx {

    static inline function isWhitespaceAfter(tokenizer:Tokenizer):Bool {
        return CharUtil.kindAfterIndex(tokenizer.parseState.bytes, tokenizer.point.index) == CharKind.Whitespace;
    }

    static inline function charAfter(tokenizer:Tokenizer):Int {
        return CharUtil.afterIndex(tokenizer.parseState.bytes, tokenizer.point.index);
    }

    /** Start of MDX: JSX. */
    public static function start(tokenizer:Tokenizer):State {
        tokenizer.enter(tokenizer.tokenizeState.token1);
        tokenizer.enter(Name.MdxJsxTagMarker);
        tokenizer.consume();
        tokenizer.exit(Name.MdxJsxTagMarker);
        return State.Next(StateName.MdxJsxStartAfter);
    }

    /** After `<`. */
    public static function startAfter(tokenizer:Tokenizer):State {
        // Deviate from JSX, which allows arbitrary whitespace.
        // See: <https://github.com/micromark/micromark-extension-mdx-jsx/issues/7>.
        if (tokenizer.current == '\t'.code || tokenizer.current == '\n'.code || tokenizer.current == ' '.code) {
            return State.Nok;
        }
        else {
            tokenizer.attempt(State.Next(StateName.MdxJsxNameBefore), State.Nok);
            return State.Retry(StateName.MdxJsxEsWhitespaceStart);
        }
    }

    /** Before name, self slash, or end of tag for fragments. */
    public static function nameBefore(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            // Closing tag.
            case '/'.code:
                tokenizer.enter(Name.MdxJsxTagClosingMarker);
                tokenizer.consume();
                tokenizer.exit(Name.MdxJsxTagClosingMarker);
                tokenizer.attempt(State.Next(StateName.MdxJsxClosingTagNameBefore), State.Nok);
                return State.Next(StateName.MdxJsxEsWhitespaceStart);
            // Fragment opening tag.
            case '>'.code:
                return State.Retry(StateName.MdxJsxTagEnd);
            default:
                if (idStartOpt(charAfter(tokenizer))) {
                    tokenizer.enter(Name.MdxJsxTagName);
                    tokenizer.enter(Name.MdxJsxTagNamePrimary);
                    tokenizer.consume();
                    return State.Next(StateName.MdxJsxPrimaryName);
                }
                else {
                    return crash(tokenizer, 'before name',
                        'a character that can start a name, such as a letter, `$`, or `_`' + (tokenizer.current == '!'.code ? ' (note: to create a comment in MDX, use `{/* text */}`)' : ''));
                }
        }
    }

    /** Before name of closing tag or end of closing fragment tag. */
    public static function closingTagNameBefore(tokenizer:Tokenizer):State {
        // Fragment closing tag.
        if (tokenizer.current == '>'.code) {
            return State.Retry(StateName.MdxJsxTagEnd);
        }
        // Start of a closing tag name.
        else if (idStartOpt(charAfter(tokenizer))) {
            tokenizer.enter(Name.MdxJsxTagName);
            tokenizer.enter(Name.MdxJsxTagNamePrimary);
            tokenizer.consume();
            return State.Next(StateName.MdxJsxPrimaryName);
        }
        else {
            // Note: upstream writes `tokenizer.current == Some(b'*' | b'/')`, where `|`
            // is a bitwise or of the two bytes (so it only matches `/`): kept as is.
            return crash(tokenizer, 'before name',
                'a character that can start a name, such as a letter, `$`, or `_`'
                + (tokenizer.current == ('*'.code | '/'.code) ? ' (note: JS comments in JSX tags are not supported in MDX)' : ''));
        }
    }

    /** In primary name. */
    public static function primaryName(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // End of name.
        if (isWhitespaceAfter(tokenizer) || c == '.'.code || c == '/'.code || c == ':'.code || c == '>'.code || c == '{'.code) {
            tokenizer.exit(Name.MdxJsxTagNamePrimary);
            tokenizer.attempt(State.Next(StateName.MdxJsxPrimaryNameAfter), State.Nok);
            return State.Retry(StateName.MdxJsxEsWhitespaceStart);
        }
        // Continuation of name: remain.
        // Allow continuation bytes.
        else if ((c >= 0x80 && c <= 0xBF) || idContOpt(charAfter(tokenizer))) {
            tokenizer.consume();
            return State.Next(StateName.MdxJsxPrimaryName);
        }
        else {
            return crash(tokenizer, 'in name',
                'a name character such as letters, digits, `$`, or `_`; whitespace before attributes; or the end of the tag'
                + (c == '@'.code ? ' (note: to create a link in MDX, use `[text](url)`)' : ''));
        }
    }

    /** After primary name. */
    public static function primaryNameAfter(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        switch c {
            // Start of a member name.
            case '.'.code:
                tokenizer.enter(Name.MdxJsxTagNameMemberMarker);
                tokenizer.consume();
                tokenizer.exit(Name.MdxJsxTagNameMemberMarker);
                tokenizer.attempt(State.Next(StateName.MdxJsxMemberNameBefore), State.Nok);
                return State.Next(StateName.MdxJsxEsWhitespaceStart);
            // Start of a local name.
            case ':'.code:
                tokenizer.enter(Name.MdxJsxTagNamePrefixMarker);
                tokenizer.consume();
                tokenizer.exit(Name.MdxJsxTagNamePrefixMarker);
                tokenizer.attempt(State.Next(StateName.MdxJsxLocalNameBefore), State.Nok);
                return State.Next(StateName.MdxJsxEsWhitespaceStart);
            // End of name.
            default:
                if (c == '/'.code || c == '>'.code || c == '{'.code || idStartOpt(charAfter(tokenizer))) {
                    tokenizer.exit(Name.MdxJsxTagName);
                    return State.Retry(StateName.MdxJsxAttributeBefore);
                }
                else {
                    return crash(tokenizer, 'after name',
                        'a character that can start an attribute name, such as a letter, `$`, or `_`; whitespace before attributes; or the end of the tag');
                }
        }
    }

    /** Before member name. */
    public static function memberNameBefore(tokenizer:Tokenizer):State {
        // Start of a member name.
        if (idStartOpt(charAfter(tokenizer))) {
            tokenizer.enter(Name.MdxJsxTagNameMember);
            tokenizer.consume();
            return State.Next(StateName.MdxJsxMemberName);
        }
        else {
            return crash(tokenizer, 'before member name',
                'a character that can start an attribute name, such as a letter, `$`, or `_`; whitespace before attributes; or the end of the tag');
        }
    }

    /** In member name. */
    public static function memberName(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // End of name.
        // Note: no `:` allowed here.
        if (isWhitespaceAfter(tokenizer) || c == '.'.code || c == '/'.code || c == '>'.code || c == '{'.code) {
            tokenizer.exit(Name.MdxJsxTagNameMember);
            tokenizer.attempt(State.Next(StateName.MdxJsxMemberNameAfter), State.Nok);
            return State.Retry(StateName.MdxJsxEsWhitespaceStart);
        }
        // Continuation of name: remain.
        // Allow continuation bytes.
        else if ((c >= 0x80 && c <= 0xBF) || idContOpt(charAfter(tokenizer))) {
            tokenizer.consume();
            return State.Next(StateName.MdxJsxMemberName);
        }
        else {
            return crash(tokenizer, 'in member name',
                'a name character such as letters, digits, `$`, or `_`; whitespace before attributes; or the end of the tag'
                + (c == '@'.code ? ' (note: to create a link in MDX, use `[text](url)`)' : ''));
        }
    }

    /** After member name. */
    public static function memberNameAfter(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // Start of another member name.
        if (c == '.'.code) {
            tokenizer.enter(Name.MdxJsxTagNameMemberMarker);
            tokenizer.consume();
            tokenizer.exit(Name.MdxJsxTagNameMemberMarker);
            tokenizer.attempt(State.Next(StateName.MdxJsxMemberNameBefore), State.Nok);
            return State.Next(StateName.MdxJsxEsWhitespaceStart);
        }
        // End of name.
        else if (c == '/'.code || c == '>'.code || c == '{'.code || idStartOpt(charAfter(tokenizer))) {
            tokenizer.exit(Name.MdxJsxTagName);
            return State.Retry(StateName.MdxJsxAttributeBefore);
        }
        else {
            return crash(tokenizer, 'after member name',
                'a character that can start an attribute name, such as a letter, `$`, or `_`; whitespace before attributes; or the end of the tag');
        }
    }

    /** Local member name. */
    public static function localNameBefore(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // Start of a local name.
        if (idStartOpt(charAfter(tokenizer))) {
            tokenizer.enter(Name.MdxJsxTagNameLocal);
            tokenizer.consume();
            return State.Next(StateName.MdxJsxLocalName);
        }
        else {
            return crash(tokenizer, 'before local name',
                'a character that can start a name, such as a letter, `$`, or `_`'
                + (c == '+'.code || (c >= '/'.code && c <= '9'.code) ? ' (note: to create a link in MDX, use `[text](url)`)' : ''));
        }
    }

    /** In local name. */
    public static function localName(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // End of local name (note that we don't expect another colon, or a member).
        if (isWhitespaceAfter(tokenizer) || c == '/'.code || c == '>'.code || c == '{'.code) {
            tokenizer.exit(Name.MdxJsxTagNameLocal);
            tokenizer.attempt(State.Next(StateName.MdxJsxLocalNameAfter), State.Nok);
            return State.Retry(StateName.MdxJsxEsWhitespaceStart);
        }
        // Continuation of name: remain.
        // Allow continuation bytes.
        else if ((c >= 0x80 && c <= 0xBF) || idContOpt(charAfter(tokenizer))) {
            tokenizer.consume();
            return State.Next(StateName.MdxJsxLocalName);
        }
        else {
            return crash(tokenizer, 'in local name',
                'a name character such as letters, digits, `$`, or `_`; whitespace before attributes; or the end of the tag');
        }
    }

    /** After local name. */
    public static function localNameAfter(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // End of name.
        if (c == '/'.code || c == '>'.code || c == '{'.code || idStartOpt(charAfter(tokenizer))) {
            tokenizer.exit(Name.MdxJsxTagName);
            return State.Retry(StateName.MdxJsxAttributeBefore);
        }
        else {
            return crash(tokenizer, 'after local name',
                'a character that can start an attribute name, such as a letter, `$`, or `_`; whitespace before attributes; or the end of the tag');
        }
    }

    /** Before attribute. */
    public static function attributeBefore(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            // Self-closing.
            case '/'.code:
                tokenizer.enter(Name.MdxJsxTagSelfClosingMarker);
                tokenizer.consume();
                tokenizer.exit(Name.MdxJsxTagSelfClosingMarker);
                tokenizer.attempt(State.Next(StateName.MdxJsxSelfClosing), State.Nok);
                return State.Next(StateName.MdxJsxEsWhitespaceStart);
            // End of tag.
            case '>'.code:
                return State.Retry(StateName.MdxJsxTagEnd);
            // Attribute expression.
            case '{'.code:
                tokenizer.tokenizeState.token2 = tokenizer.tokenizeState.token1;
                tokenizer.tokenizeState.token1 = Name.MdxJsxTagAttributeExpression;
                tokenizer.attempt(State.Next(StateName.MdxJsxAttributeExpressionAfter), State.Nok);
                return State.Retry(StateName.MdxExpressionStart);
            default:
                // Start of an attribute name.
                if (idStartOpt(charAfter(tokenizer))) {
                    tokenizer.enter(Name.MdxJsxTagAttribute);
                    tokenizer.enter(Name.MdxJsxTagAttributeName);
                    tokenizer.enter(Name.MdxJsxTagAttributePrimaryName);
                    tokenizer.consume();
                    return State.Next(StateName.MdxJsxAttributePrimaryName);
                }
                else {
                    return crash(tokenizer, 'before attribute name',
                        'a character that can start an attribute name, such as a letter, `$`, or `_`; whitespace before attributes; or the end of the tag');
                }
        }
    }

    /** After attribute expression. */
    public static function attributeExpressionAfter(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.token1 = tokenizer.tokenizeState.token2;
        tokenizer.tokenizeState.token2 = Name.Data;
        tokenizer.attempt(State.Next(StateName.MdxJsxAttributeBefore), State.Nok);
        return State.Retry(StateName.MdxJsxEsWhitespaceStart);
    }

    /** In primary attribute name. */
    public static function attributePrimaryName(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // End of attribute name or tag.
        if (isWhitespaceAfter(tokenizer) || c == '/'.code || c == ':'.code || c == '='.code || c == '>'.code || c == '{'.code) {
            tokenizer.exit(Name.MdxJsxTagAttributePrimaryName);
            tokenizer.attempt(State.Next(StateName.MdxJsxAttributePrimaryNameAfter), State.Nok);
            return State.Retry(StateName.MdxJsxEsWhitespaceStart);
        }
        // Continuation of name: remain.
        // Allow continuation bytes.
        else if ((c >= 0x80 && c <= 0xBF) || idContOpt(charAfter(tokenizer))) {
            tokenizer.consume();
            return State.Next(StateName.MdxJsxAttributePrimaryName);
        }
        else {
            return crash(tokenizer, 'in attribute name',
                'an attribute name character such as letters, digits, `$`, or `_`; `=` to initialize a value; whitespace before attributes; or the end of the tag');
        }
    }

    /** After primary attribute name. */
    public static function attributePrimaryNameAfter(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        switch c {
            // Start of a local name.
            case ':'.code:
                tokenizer.enter(Name.MdxJsxTagAttributeNamePrefixMarker);
                tokenizer.consume();
                tokenizer.exit(Name.MdxJsxTagAttributeNamePrefixMarker);
                tokenizer.attempt(State.Next(StateName.MdxJsxAttributeLocalNameBefore), State.Nok);
                return State.Next(StateName.MdxJsxEsWhitespaceStart);
            // Initializer: start of an attribute value.
            case '='.code:
                tokenizer.exit(Name.MdxJsxTagAttributeName);
                tokenizer.enter(Name.MdxJsxTagAttributeInitializerMarker);
                tokenizer.consume();
                tokenizer.exit(Name.MdxJsxTagAttributeInitializerMarker);
                tokenizer.attempt(State.Next(StateName.MdxJsxAttributeValueBefore), State.Nok);
                return State.Retry(StateName.MdxJsxEsWhitespaceStart);
            default:
                // End of tag / new attribute.
                if (isWhitespaceAfter(tokenizer) || c == '/'.code || c == '>'.code || c == '{'.code || idStartOpt(charAfter(tokenizer))) {
                    tokenizer.exit(Name.MdxJsxTagAttributeName);
                    tokenizer.exit(Name.MdxJsxTagAttribute);
                    tokenizer.attempt(State.Next(StateName.MdxJsxAttributeBefore), State.Nok);
                    return State.Retry(StateName.MdxJsxEsWhitespaceStart);
                }
                else {
                    return crash(tokenizer, 'after attribute name',
                        'a character that can start an attribute name, such as a letter, `$`, or `_`; `=` to initialize a value; or the end of the tag');
                }
        }
    }

    /** Before local attribute name. */
    public static function attributeLocalNameBefore(tokenizer:Tokenizer):State {
        // Start of a local name.
        if (idStartOpt(charAfter(tokenizer))) {
            tokenizer.enter(Name.MdxJsxTagAttributeNameLocal);
            tokenizer.consume();
            return State.Next(StateName.MdxJsxAttributeLocalName);
        }
        else {
            return crash(tokenizer, 'before local attribute name',
                'a character that can start an attribute name, such as a letter, `$`, or `_`; `=` to initialize a value; or the end of the tag');
        }
    }

    /** In local attribute name. */
    public static function attributeLocalName(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // End of local name (note that we don't expect another colon).
        if (isWhitespaceAfter(tokenizer) || c == '/'.code || c == '='.code || c == '>'.code || c == '{'.code) {
            tokenizer.exit(Name.MdxJsxTagAttributeNameLocal);
            tokenizer.exit(Name.MdxJsxTagAttributeName);
            tokenizer.attempt(State.Next(StateName.MdxJsxAttributeLocalNameAfter), State.Nok);
            return State.Retry(StateName.MdxJsxEsWhitespaceStart);
        }
        // Continuation of name: remain.
        // Allow continuation bytes.
        else if ((c >= 0x80 && c <= 0xBF) || idContOpt(charAfter(tokenizer))) {
            tokenizer.consume();
            return State.Next(StateName.MdxJsxAttributeLocalName);
        }
        else {
            return crash(tokenizer, 'in local attribute name',
                'an attribute name character such as letters, digits, `$`, or `_`; `=` to initialize a value; whitespace before attributes; or the end of the tag');
        }
    }

    /** After local attribute name. */
    public static function attributeLocalNameAfter(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // Start of an attribute value.
        if (c == '='.code) {
            tokenizer.enter(Name.MdxJsxTagAttributeInitializerMarker);
            tokenizer.consume();
            tokenizer.exit(Name.MdxJsxTagAttributeInitializerMarker);
            tokenizer.attempt(State.Next(StateName.MdxJsxAttributeValueBefore), State.Nok);
            return State.Next(StateName.MdxJsxEsWhitespaceStart);
        }
        // End of name.
        else if (c == '/'.code || c == '>'.code || c == '{'.code || idStartOpt(charAfter(tokenizer))) {
            tokenizer.exit(Name.MdxJsxTagAttribute);
            return State.Retry(StateName.MdxJsxAttributeBefore);
        }
        else {
            return crash(tokenizer, 'after local attribute name',
                'a character that can start an attribute name, such as a letter, `$`, or `_`; `=` to initialize a value; or the end of the tag');
        }
    }

    /** After `=`, before value. */
    public static function attributeValueBefore(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            // Start of double- or single quoted value.
            case '"'.code | "'".code:
                tokenizer.tokenizeState.marker = tokenizer.current;
                tokenizer.enter(Name.MdxJsxTagAttributeValueLiteral);
                tokenizer.enter(Name.MdxJsxTagAttributeValueLiteralMarker);
                tokenizer.consume();
                tokenizer.exit(Name.MdxJsxTagAttributeValueLiteralMarker);
                return State.Next(StateName.MdxJsxAttributeValueQuotedStart);
            // Attribute value expression.
            case '{'.code:
                tokenizer.tokenizeState.token2 = tokenizer.tokenizeState.token1;
                tokenizer.tokenizeState.token1 = Name.MdxJsxTagAttributeValueExpression;
                tokenizer.attempt(State.Next(StateName.MdxJsxAttributeValueExpressionAfter), State.Nok);
                return State.Retry(StateName.MdxExpressionStart);
            default:
                return crash(tokenizer, 'before attribute value',
                    "a character that can start an attribute value, such as `\"`, `'`, or `{`"
                    + (tokenizer.current == '<'.code ? ' (note: to use an element or fragment as a prop value in MDX, use `{<element />}`)' : ''));
        }
    }

    /** After attribute value expression. */
    public static function attributeValueExpressionAfter(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.token1 = tokenizer.tokenizeState.token2;
        tokenizer.tokenizeState.token2 = Name.Data;
        tokenizer.exit(Name.MdxJsxTagAttribute);
        tokenizer.attempt(State.Next(StateName.MdxJsxAttributeBefore), State.Nok);
        return State.Retry(StateName.MdxJsxEsWhitespaceStart);
    }

    /** Before quoted literal attribute value. */
    public static function attributeValueQuotedStart(tokenizer:Tokenizer):State {
        var byte = tokenizer.current;
        if (byte != -1) {
            if (byte == tokenizer.tokenizeState.marker) {
                tokenizer.tokenizeState.marker = 0;
                tokenizer.enter(Name.MdxJsxTagAttributeValueLiteralMarker);
                tokenizer.consume();
                tokenizer.exit(Name.MdxJsxTagAttributeValueLiteralMarker);
                tokenizer.exit(Name.MdxJsxTagAttributeValueLiteral);
                tokenizer.exit(Name.MdxJsxTagAttribute);
                tokenizer.attempt(State.Next(StateName.MdxJsxAttributeBefore), State.Nok);
                return State.Next(StateName.MdxJsxEsWhitespaceStart);
            }
            else if (byte == '\n'.code) {
                tokenizer.attempt(State.Next(StateName.MdxJsxAttributeValueQuotedStart), State.Nok);
                return State.Retry(StateName.MdxJsxEsWhitespaceStart);
            }
            else {
                tokenizer.enter(Name.MdxJsxTagAttributeValueLiteralValue);
                return State.Retry(StateName.MdxJsxAttributeValueQuoted);
            }
        }
        else {
            return crash(tokenizer, 'in attribute value', 'a corresponding closing quote ' + CharUtil.formatByte(tokenizer.tokenizeState.marker));
        }
    }

    /** In quoted literal attribute value. */
    public static function attributeValueQuoted(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.marker || tokenizer.current == -1 || tokenizer.current == '\n'.code) {
            tokenizer.exit(Name.MdxJsxTagAttributeValueLiteralValue);
            return State.Retry(StateName.MdxJsxAttributeValueQuotedStart);
        }
        else {
            tokenizer.consume();
            return State.Next(StateName.MdxJsxAttributeValueQuoted);
        }
    }

    /** After self-closing slash. */
    public static function selfClosing(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '>'.code:
                return State.Retry(StateName.MdxJsxTagEnd);
            // Note: upstream compares with `Some(b'*' | b'/')`, a bitwise or (`/`), kept as is.
            default:
                // Note: upstream writes `tokenizer.current == Some(b'*' | b'/')`, where `|`
                // is a bitwise or of the two bytes (so it only matches `/`): kept as is.
                return crash(tokenizer, 'after self-closing slash',
                    '`>` to end the tag' + (tokenizer.current == ('*'.code | '/'.code) ? ' (note: JS comments in JSX tags are not supported in MDX)' : ''));
        }
    }

    /** At final `>`. */
    public static function tagEnd(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '>'.code:
                tokenizer.enter(Name.MdxJsxTagMarker);
                tokenizer.consume();
                tokenizer.exit(Name.MdxJsxTagMarker);
                tokenizer.exit(tokenizer.tokenizeState.token1);
                return State.Ok;
            default:
                throw 'expected `>`';
        }
    }

    /** Before optional ECMAScript whitespace. */
    public static function esWhitespaceStart(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\n'.code:
                tokenizer.enter(Name.LineEnding);
                tokenizer.consume();
                tokenizer.exit(Name.LineEnding);
                return State.Next(StateName.MdxJsxEsWhitespaceEolAfter);
            default:
                if (isWhitespaceAfter(tokenizer)) {
                    tokenizer.enter(Name.MdxJsxEsWhitespace);
                    return State.Retry(StateName.MdxJsxEsWhitespaceInside);
                }
                else {
                    return State.Ok;
                }
        }
    }

    /** In ECMAScript whitespace. */
    public static function esWhitespaceInside(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if (c == '\n'.code) {
            tokenizer.exit(Name.MdxJsxEsWhitespace);
            return State.Retry(StateName.MdxJsxEsWhitespaceStart);
        }
        // Allow continuation bytes.
        else if (c >= 0x80 && c <= 0xBF) {
            tokenizer.consume();
            return State.Next(StateName.MdxJsxEsWhitespaceInside);
        }
        else if (c != -1 && isWhitespaceAfter(tokenizer)) {
            tokenizer.consume();
            return State.Next(StateName.MdxJsxEsWhitespaceInside);
        }
        else if (c != -1) {
            tokenizer.exit(Name.MdxJsxEsWhitespace);
            return State.Ok;
        }
        // Handle EOF.
        else {
            return State.Nok;
        }
    }

    /** After eol in whitespace. */
    public static function esWhitespaceEolAfter(tokenizer:Tokenizer):State {
        // Lazy continuation in a flow tag is a syntax error.
        if (tokenizer.tokenizeState.token1 == Name.MdxJsxFlowTag && tokenizer.lazy) {
            return State.error(new Message(Place.Point(tokenizer.point.toUnist()),
                'Unexpected lazy line in jsx in container, expected line to be prefixed with `>` when in a block quote, whitespace when in a list, etc',
                'unexpected-lazy', 'markdown-rs'));
        }
        else {
            return State.Retry(StateName.MdxJsxEsWhitespaceStart);
        }
    }

    /** Check if a character can start a JSX identifier. */
    static inline function idStartOpt(code:Int):Bool {
        return code != -1 && Identifier.idStart(code);
    }

    /** Check if a character can continue a JSX identifier. */
    static inline function idContOpt(code:Int):Bool {
        return code != -1 && Identifier.idCont(code, true);
    }

    /** Crash because something happened `at`, with info on what was `expect`ed instead. */
    static function crash(tokenizer:Tokenizer, at:String, expect:String):State {
        return State.error(new Message(
            Place.Point(tokenizer.point.toUnist()),
            'Unexpected ' + CharUtil.formatOpt(tokenizer.current == -1 ? -1 : charAfter(tokenizer)) + ' ' + at + ', expected ' + expect,
            'unexpected-' + (tokenizer.current == -1 ? 'eof' : 'character'),
            'markdown-rs'
        ));
    }

}
