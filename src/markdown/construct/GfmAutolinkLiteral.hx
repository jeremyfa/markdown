// Ported from markdown 1.0.0: src/construct/gfm_autolink_literal.rs
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
import haxe.io.Bytes;
import markdown.util.CharUtil;
import markdown.util.Slice;

/**
 * GFM: autolink literal occurs in the text content type (`gfm_autolink_literal.rs`).
 */
class GfmAutolinkLiteral {

    static inline function isAlpha(c:Int):Bool {
        return (c >= 'A'.code && c <= 'Z'.code) || (c >= 'a'.code && c <= 'z'.code);
    }

    /** Start of protocol. */
    public static function protocolStart(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.gfmAutolinkLiteral
            && (tokenizer.current == 'H'.code || tokenizer.current == 'h'.code)
            // Source: <https://github.com/github/cmark-gfm/blob/ef1cfcb/extensions/autolink.c#L214>.
            && !isAlpha(tokenizer.previous)) {
            tokenizer.enter(Name.GfmAutolinkLiteralProtocol);
            tokenizer.attempt(State.Next(StateName.GfmAutolinkLiteralProtocolAfter), State.Nok);
            tokenizer.attempt(State.Next(StateName.GfmAutolinkLiteralDomainInside), State.Nok);
            tokenizer.tokenizeState.start = tokenizer.point.index;
            return State.Retry(StateName.GfmAutolinkLiteralProtocolPrefixInside);
        }
        else {
            return State.Nok;
        }
    }

    /** After a protocol autolink literal. */
    public static function protocolAfter(tokenizer:Tokenizer):State {
        tokenizer.exit(Name.GfmAutolinkLiteralProtocol);
        return State.Ok;
    }

    /** In protocol. */
    public static function protocolPrefixInside(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if (isAlpha(c) && tokenizer.point.index - tokenizer.tokenizeState.start < 5) {
            // N is `5` for `https`.
            tokenizer.consume();
            return State.Next(StateName.GfmAutolinkLiteralProtocolPrefixInside);
        }
        else if (c == ':'.code) {
            var slice = Slice.fromIndices(tokenizer.parseState.bytes, tokenizer.tokenizeState.start, tokenizer.point.index);
            var name = CharUtil.asciiLowercase(slice.asStr());

            tokenizer.tokenizeState.start = 0;

            if (name == 'http' || name == 'https') {
                tokenizer.consume();
                return State.Next(StateName.GfmAutolinkLiteralProtocolSlashesInside);
            }
            else {
                return State.Nok;
            }
        }
        else {
            tokenizer.tokenizeState.start = 0;
            return State.Nok;
        }
    }

    /** In protocol slashes. */
    public static function protocolSlashesInside(tokenizer:Tokenizer):State {
        if (tokenizer.current == '/'.code) {
            tokenizer.consume();
            if (tokenizer.tokenizeState.size == 0) {
                tokenizer.tokenizeState.size += 1;
                return State.Next(StateName.GfmAutolinkLiteralProtocolSlashesInside);
            }
            else {
                tokenizer.tokenizeState.size = 0;
                return State.Ok;
            }
        }
        else {
            tokenizer.tokenizeState.size = 0;
            return State.Nok;
        }
    }

    /** Start of www autolink literal. */
    public static function wwwStart(tokenizer:Tokenizer):State {
        var p = tokenizer.previous;
        if (tokenizer.parseState.options.constructs.gfmAutolinkLiteral
            && (tokenizer.current == 'W'.code || tokenizer.current == 'w'.code)
            // Source: <https://github.com/github/cmark-gfm/blob/ef1cfcb/extensions/autolink.c#L156>.
            && (p == -1 || p == '\t'.code || p == '\n'.code || p == ' '.code || p == '('.code || p == '*'.code
                || p == '_'.code || p == '['.code || p == ']'.code || p == '~'.code)) {
            tokenizer.enter(Name.GfmAutolinkLiteralWww);
            tokenizer.attempt(State.Next(StateName.GfmAutolinkLiteralWwwAfter), State.Nok);
            // Note: we *check*, so we can discard the `www.` we parsed.
            // If it worked, we consider it as a part of the domain.
            tokenizer.check(State.Next(StateName.GfmAutolinkLiteralDomainInside), State.Nok);
            return State.Retry(StateName.GfmAutolinkLiteralWwwPrefixInside);
        }
        else {
            return State.Nok;
        }
    }

    /** After a www autolink literal. */
    public static function wwwAfter(tokenizer:Tokenizer):State {
        tokenizer.exit(Name.GfmAutolinkLiteralWww);
        return State.Ok;
    }

    /** In www prefix. */
    public static function wwwPrefixInside(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if (c == '.'.code && tokenizer.tokenizeState.size == 3) {
            tokenizer.tokenizeState.size = 0;
            tokenizer.consume();
            return State.Next(StateName.GfmAutolinkLiteralWwwPrefixAfter);
        }
        else if ((c == 'W'.code || c == 'w'.code) && tokenizer.tokenizeState.size < 3) {
            tokenizer.tokenizeState.size += 1;
            tokenizer.consume();
            return State.Next(StateName.GfmAutolinkLiteralWwwPrefixInside);
        }
        else {
            tokenizer.tokenizeState.size = 0;
            return State.Nok;
        }
    }

    /** After www prefix. */
    public static function wwwPrefixAfter(tokenizer:Tokenizer):State {
        // If there is *anything*, we can link.
        return tokenizer.current == -1 ? State.Nok : State.Ok;
    }

    /** In domain. */
    public static function domainInside(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // Check whether this marker, which is a trailing punctuation marker, optionally followed by more trailing markers, and then followed by an end.
        if (c == '.'.code || c == '_'.code) {
            tokenizer.check(State.Next(StateName.GfmAutolinkLiteralDomainAfter), State.Next(StateName.GfmAutolinkLiteralDomainAtPunctuation));
            return State.Retry(StateName.GfmAutolinkLiteralTrail);
        }
        // Dashes and continuation bytes are fine.
        else if (c == '-'.code || (c >= 0x80 && c <= 0xBF)) {
            tokenizer.consume();
            return State.Next(StateName.GfmAutolinkLiteralDomainInside);
        }
        else {
            // Source: <https://github.com/github/cmark-gfm/blob/ef1cfcb/extensions/autolink.c#L12>.
            if (CharUtil.kindAfterIndex(tokenizer.parseState.bytes, tokenizer.point.index) == CharKind.Other) {
                tokenizer.tokenizeState.seen = true;
                tokenizer.consume();
                return State.Next(StateName.GfmAutolinkLiteralDomainInside);
            }
            else {
                return State.Retry(StateName.GfmAutolinkLiteralDomainAfter);
            }
        }
    }

    /** In domain, at potential trailing punctuation, that was not trailing. */
    public static function domainAtPunctuation(tokenizer:Tokenizer):State {
        // There is an underscore in the last segment of the domain.
        if (tokenizer.current == '_'.code) {
            tokenizer.tokenizeState.marker = '_'.code;
        }
        // Otherwise, it's a `.`: save the last segment underscore in the penultimate segment slot.
        else {
            tokenizer.tokenizeState.markerB = tokenizer.tokenizeState.marker;
            tokenizer.tokenizeState.marker = 0;
        }

        tokenizer.consume();
        return State.Next(StateName.GfmAutolinkLiteralDomainInside);
    }

    /** After domain. */
    public static function domainAfter(tokenizer:Tokenizer):State {
        // No underscores allowed in last two segments.
        var result = tokenizer.tokenizeState.markerB == '_'.code || tokenizer.tokenizeState.marker == '_'.code
            // At least one character must be seen.
            || !tokenizer.tokenizeState.seen
            ? State.Nok
            : State.Retry(StateName.GfmAutolinkLiteralPathInside);

        tokenizer.tokenizeState.seen = false;
        tokenizer.tokenizeState.marker = 0;
        tokenizer.tokenizeState.markerB = 0;
        return result;
    }

    /** In path. */
    public static function pathInside(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // Continuation bytes are fine, we've already checked the first one.
        if (c >= 0x80 && c <= 0xBF) {
            tokenizer.consume();
            return State.Next(StateName.GfmAutolinkLiteralPathInside);
        }
        // Count opening parens.
        else if (c == '('.code) {
            tokenizer.tokenizeState.size += 1;
            tokenizer.consume();
            return State.Next(StateName.GfmAutolinkLiteralPathInside);
        }
        // Check whether this trailing punctuation marker is optionally followed by more trailing markers, and then followed by an end.
        else if (c == '!'.code || c == '"'.code || c == '&'.code || c == "'".code || c == ')'.code || c == '*'.code || c == ','.code
            || c == '.'.code || c == ':'.code || c == ';'.code || c == '<'.code || c == '?'.code || c == ']'.code || c == '_'.code || c == '~'.code) {
            // Count closing parens.
            var next = c == ')'.code && tokenizer.tokenizeState.sizeB < tokenizer.tokenizeState.size
                ? StateName.GfmAutolinkLiteralPathAtPunctuation
                : StateName.GfmAutolinkLiteralPathAfter;
            tokenizer.check(State.Next(next), State.Next(StateName.GfmAutolinkLiteralPathAtPunctuation));
            return State.Retry(StateName.GfmAutolinkLiteralTrail);
        }
        else {
            // Source: <https://github.com/github/cmark-gfm/blob/ef1cfcb/extensions/autolink.c#L12>.
            if (c == -1 || CharUtil.kindAfterIndex(tokenizer.parseState.bytes, tokenizer.point.index) == CharKind.Whitespace) {
                return State.Retry(StateName.GfmAutolinkLiteralPathAfter);
            }
            else {
                tokenizer.consume();
                return State.Next(StateName.GfmAutolinkLiteralPathInside);
            }
        }
    }

    /** In path, at potential trailing punctuation, that was not trailing. */
    public static function pathAtPunctuation(tokenizer:Tokenizer):State {
        // Count closing parens.
        if (tokenizer.current == ')'.code) {
            tokenizer.tokenizeState.sizeB += 1;
        }

        tokenizer.consume();
        return State.Next(StateName.GfmAutolinkLiteralPathInside);
    }

    /** At end of path, reset parens. */
    public static function pathAfter(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.size = 0;
        tokenizer.tokenizeState.sizeB = 0;
        return State.Ok;
    }

    /** In trail of domain or path. */
    public static function trail(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // Regular trailing punctuation.
        if (c == '!'.code || c == '"'.code || c == "'".code || c == ')'.code || c == '*'.code || c == ','.code || c == '.'.code
            || c == ':'.code || c == ';'.code || c == '?'.code || c == '_'.code || c == '~'.code) {
            tokenizer.consume();
            return State.Next(StateName.GfmAutolinkLiteralTrail);
        }
        // `&` followed by one or more alphabeticals and then a `;`, is as a whole considered as trailing punctuation.
        else if (c == '&'.code) {
            tokenizer.consume();
            return State.Next(StateName.GfmAutolinkLiteralTrailCharRefStart);
        }
        // `<` is an end.
        else if (c == '<'.code) {
            return State.Ok;
        }
        // Needed because we allow literals after `[`, as we fix: <https://github.com/github/cmark-gfm/issues/278>.
        else if (c == ']'.code) {
            tokenizer.consume();
            return State.Next(StateName.GfmAutolinkLiteralTrailBracketAfter);
        }
        else {
            // Whitespace is the end of the URL, anything else is continuation.
            return CharUtil.kindAfterIndex(tokenizer.parseState.bytes, tokenizer.point.index) == CharKind.Whitespace ? State.Ok : State.Nok;
        }
    }

    /** In trail, after `]`. */
    public static function trailBracketAfter(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // Whitespace or something that could start a resource or reference is the end.
        if (c == -1 || c == '\t'.code || c == '\n'.code || c == ' '.code || c == '('.code || c == '['.code) {
            return State.Ok;
        }
        else {
            return State.Retry(StateName.GfmAutolinkLiteralTrail);
        }
    }

    /** In character-reference like trail, after `&`. */
    public static function trailCharRefStart(tokenizer:Tokenizer):State {
        return isAlpha(tokenizer.current) ? State.Retry(StateName.GfmAutolinkLiteralTrailCharRefInside) : State.Nok;
    }

    /** In character-reference like trail. */
    public static function trailCharRefInside(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if (isAlpha(c)) {
            tokenizer.consume();
            return State.Next(StateName.GfmAutolinkLiteralTrailCharRefInside);
        }
        // Switch back to trail if this is well-formed.
        else if (c == ';'.code) {
            tokenizer.consume();
            return State.Next(StateName.GfmAutolinkLiteralTrail);
        }
        else {
            return State.Nok;
        }
    }

    /** Resolve: postprocess text to find email autolink literals (`resolve` in `gfm_autolink_literal.rs`). */
    public static function resolveGfmAutolinkLiteral(tokenizer:Tokenizer):Void {
        tokenizer.map.consume(tokenizer.events);

        var index = 0;
        var links = 0;

        while (index < tokenizer.events.length) {
            var event = tokenizer.events[index];

            if (event.kind == Kind.Enter) {
                if (event.name == Name.Link) {
                    links += 1;
                }
            }
            else {
                if (event.name == Name.Data && links == 0) {
                    var slice = Slice.fromPosition(tokenizer.parseState.bytes, SlicePosition.fromExitEvent(tokenizer.events, index));
                    var bytes = slice.bytes;
                    var offset = slice.start;
                    var len = slice.end - slice.start;
                    var byteIndex = 0;
                    var replace:Array<Event> = [];
                    var point = tokenizer.events[index - 1].point.clone();
                    var startIndex = point.index;
                    var min = 0;

                    while (byteIndex < len) {
                        if (bytes.get(offset + byteIndex) == '@'.code) {
                            var range0 = 0;
                            var range1 = 0;
                            var range2 = Name.GfmAutolinkLiteralEmail;

                            var start = peekBytesAtext(bytes, offset, min, byteIndex);
                            if (start != -1) {
                                var protocol = peekProtocol(bytes, offset, min, start);
                                var kind = protocolKind;
                                var end = peekBytesEmailDomain(bytes, offset, len, byteIndex + 1, kind == Name.GfmAutolinkLiteralXmpp);
                                if (end != -1) {
                                    // Note: normally we'd truncate trailing punctuation from the link.
                                    // However, email autolink literals cannot contain any of those markers, except for `.`, but that can only occur if it isn't trailing.
                                    // So we can ignore truncating!
                                    range0 = protocol;
                                    range1 = end;
                                    range2 = kind;
                                }
                            }

                            if (range1 != 0) {
                                byteIndex = range1;

                                // If there is something between the last link (or `min`) and this link.
                                if (min != range0) {
                                    replace.push(new Event(Kind.Enter, Name.Data, point.clone(), null));
                                    point = point.shiftTo(tokenizer.parseState.bytes, startIndex + range0);
                                    replace.push(new Event(Kind.Exit, Name.Data, point.clone(), null));
                                }

                                // Add the link.
                                replace.push(new Event(Kind.Enter, range2, point.clone(), null));
                                point = point.shiftTo(tokenizer.parseState.bytes, startIndex + range1);
                                replace.push(new Event(Kind.Exit, range2, point.clone(), null));
                                min = range1;
                            }
                        }

                        byteIndex += 1;
                    }

                    // If there was a link, and we have more bytes left.
                    if (min != 0 && min < len) {
                        replace.push(new Event(Kind.Enter, Name.Data, point.clone(), null));
                        replace.push(new Event(Kind.Exit, Name.Data, event.point.clone(), null));
                    }

                    // If there were links.
                    if (replace.length > 0) {
                        tokenizer.map.add(index - 1, 2, replace);
                    }
                }

                if (event.name == Name.Link) {
                    links -= 1;
                }
            }

            index += 1;
        }
    }

    /** Move back past atext (`-1` for `None`). Indices are relative to `offset`. */
    static function peekBytesAtext(bytes:Bytes, offset:Int, min:Int, end:Int):Int {
        var index = end;

        // Take simplified atext.
        // See `email_atext` in `autolink.rs` for a similar algorithm.
        // Source: <https://github.com/github/cmark-gfm/blob/ef1cfcb/extensions/autolink.c#L301>.
        while (index > min) {
            var b = bytes.get(offset + index - 1);
            if (b == '+'.code || b == '-'.code || b == '.'.code || CharUtil.isAsciiAlphanumeric(b) || b == '_'.code)
                index -= 1;
            else
                break;
        }

        // Do not allow a slash "inside" atext.
        // The reference code is a bit weird, but that's what it results in.
        // Source: <https://github.com/github/cmark-gfm/blob/ef1cfcb/extensions/autolink.c#L307>.
        // Other than slash, every preceding character is allowed.
        if (index == end || (index > min && bytes.get(offset + index - 1) == '/'.code)) {
            return -1;
        }
        else {
            return index;
        }
    }

    /** Kind found by the last `peekProtocol` call. */
    static var protocolKind:Name = Name.GfmAutolinkLiteralEmail;

    /** Move back past a `mailto:` or `xmpp:` protocol (the kind is stored in `protocolKind`). */
    static function peekProtocol(bytes:Bytes, offset:Int, min:Int, end:Int):Int {
        var index = end;

        if (index > min && bytes.get(offset + index - 1) == ':'.code) {
            index -= 1;

            // Take alphanumerical.
            while (index > min && CharUtil.isAsciiAlphanumeric(bytes.get(offset + index - 1))) {
                index -= 1;
            }

            var slice = Slice.fromIndices(bytes, offset + index, offset + end - 1);
            var name = CharUtil.asciiLowercase(slice.asStr());

            if (name == 'xmpp') {
                protocolKind = Name.GfmAutolinkLiteralXmpp;
                return index;
            }
            else if (name == 'mailto') {
                protocolKind = Name.GfmAutolinkLiteralMailto;
                return index;
            }
        }

        protocolKind = Name.GfmAutolinkLiteralEmail;
        return end;
    }

    /** Move past email domain (`-1` for `None`). */
    static function peekBytesEmailDomain(bytes:Bytes, offset:Int, len:Int, start:Int, xmpp:Bool):Int {
        var index = start;
        var dot = false;

        // Move past "domain".
        // The reference code is a bit overly complex as it handles the `@`, of which there may be just one.
        // Source: <https://github.com/github/cmark-gfm/blob/ef1cfcb/extensions/autolink.c#L318>
        while (index < len) {
            var b = bytes.get(offset + index);
            if (b == '-'.code || CharUtil.isAsciiAlphanumeric(b) || b == '_'.code) {}
            else if (b == '/'.code && xmpp) {}
            else if (b == '.'.code && index + 1 < len && CharUtil.isAsciiAlphanumeric(bytes.get(offset + index + 1))) {
                dot = true;
            }
            else
                break;

            index += 1;
        }

        // Domain must not be empty, must include a dot, and must end in alphabetical or `.`.
        // Source: <https://github.com/github/cmark-gfm/blob/ef1cfcb/extensions/autolink.c#L332>.
        if (index > start && dot) {
            var b = bytes.get(offset + index - 1);
            if (b == '.'.code || (b >= 'A'.code && b <= 'Z'.code) || (b >= 'a'.code && b <= 'z'.code))
                return index;
        }
        return -1;
    }

}
