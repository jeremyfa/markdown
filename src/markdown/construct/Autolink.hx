// Ported from markdown 1.0.0: src/construct/autolink.rs
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
 * Autolinks occur in the text content type (`autolink.rs`).
 */
class Autolink {

    static inline function isAlnum(c:Int):Bool {
        return (c >= '0'.code && c <= '9'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= 'a'.code && c <= 'z'.code);
    }

    static inline function isSchemeChar(c:Int):Bool {
        return c == '+'.code || c == '-'.code || c == '.'.code || isAlnum(c);
    }

    /** Start of an autolink. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.autolink && tokenizer.current == '<'.code) {
            tokenizer.enter(Name.Autolink);
            tokenizer.enter(Name.AutolinkMarker);
            tokenizer.consume();
            tokenizer.exit(Name.AutolinkMarker);
            tokenizer.enter(Name.AutolinkProtocol);
            return State.Next(StateName.AutolinkOpen);
        }
        else {
            return State.Nok;
        }
    }

    /** After `<`, at protocol or atext. */
    public static function open(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if ((c >= 'A'.code && c <= 'Z'.code) || (c >= 'a'.code && c <= 'z'.code)) {
            tokenizer.consume();
            return State.Next(StateName.AutolinkSchemeOrEmailAtext);
        }
        else if (c == '@'.code) {
            return State.Nok;
        }
        else {
            return State.Retry(StateName.AutolinkEmailAtext);
        }
    }

    /** At second byte of protocol or atext. */
    public static function schemeOrEmailAtext(tokenizer:Tokenizer):State {
        if (isSchemeChar(tokenizer.current)) {
            // Count the previous alphabetical from `open` too.
            tokenizer.tokenizeState.size = 1;
            return State.Retry(StateName.AutolinkSchemeInsideOrEmailAtext);
        }
        return State.Retry(StateName.AutolinkEmailAtext);
    }

    /** In ambiguous protocol or atext. */
    public static function schemeInsideOrEmailAtext(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if (c == ':'.code) {
            tokenizer.consume();
            tokenizer.tokenizeState.size = 0;
            return State.Next(StateName.AutolinkUrlInside);
        }
        // ASCII alphanumeric and `+`, `-`, and `.`.
        else if (isSchemeChar(c) && tokenizer.tokenizeState.size < Constant.AUTOLINK_SCHEME_SIZE_MAX) {
            tokenizer.consume();
            tokenizer.tokenizeState.size += 1;
            return State.Next(StateName.AutolinkSchemeInsideOrEmailAtext);
        }
        else {
            tokenizer.tokenizeState.size = 0;
            return State.Retry(StateName.AutolinkEmailAtext);
        }
    }

    /** After protocol, in URL. */
    public static function urlInside(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if (c == '>'.code) {
            tokenizer.exit(Name.AutolinkProtocol);
            tokenizer.enter(Name.AutolinkMarker);
            tokenizer.consume();
            tokenizer.exit(Name.AutolinkMarker);
            tokenizer.exit(Name.Autolink);
            return State.Ok;
        }
        // ASCII control, space, or `<`.
        else if (c == -1 || (c >= 0 && c <= 0x1F) || c == ' '.code || c == '<'.code || c == 0x7F) {
            return State.Nok;
        }
        else {
            tokenizer.consume();
            return State.Next(StateName.AutolinkUrlInside);
        }
    }

    /** In email atext. */
    public static function emailAtext(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if (c == '@'.code) {
            tokenizer.consume();
            return State.Next(StateName.AutolinkEmailAtSignOrDot);
        }
        // ASCII atext.
        else if ((c >= '#'.code && c <= "'".code) || c == '*'.code || c == '+'.code || (c >= '-'.code && c <= '9'.code)
            || c == '='.code || c == '?'.code || (c >= 'A'.code && c <= 'Z'.code) || (c >= '^'.code && c <= '~'.code)) {
            tokenizer.consume();
            return State.Next(StateName.AutolinkEmailAtext);
        }
        else {
            return State.Nok;
        }
    }

    /** In label, after at-sign or dot. */
    public static function emailAtSignOrDot(tokenizer:Tokenizer):State {
        return isAlnum(tokenizer.current) ? State.Retry(StateName.AutolinkEmailValue) : State.Nok;
    }

    /** In label, where `.` and `>` are allowed. */
    public static function emailLabel(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '.'.code:
                tokenizer.consume();
                tokenizer.tokenizeState.size = 0;
                return State.Next(StateName.AutolinkEmailAtSignOrDot);
            case '>'.code:
                var index = tokenizer.events.length;
                tokenizer.exit(Name.AutolinkProtocol);
                // Change the event name.
                tokenizer.events[index - 1].name = Name.AutolinkEmail;
                tokenizer.events[index].name = Name.AutolinkEmail;
                tokenizer.enter(Name.AutolinkMarker);
                tokenizer.consume();
                tokenizer.exit(Name.AutolinkMarker);
                tokenizer.exit(Name.Autolink);
                tokenizer.tokenizeState.size = 0;
                return State.Ok;
            default:
                return State.Retry(StateName.AutolinkEmailValue);
        }
    }

    /** In label, where `.` and `>` are *not* allowed. */
    public static function emailValue(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // ASCII alphanumeric or `-`.
        if ((c == '-'.code || isAlnum(c)) && tokenizer.tokenizeState.size < Constant.AUTOLINK_DOMAIN_SIZE_MAX) {
            var name = c == '-'.code ? StateName.AutolinkEmailValue : StateName.AutolinkEmailLabel;
            tokenizer.tokenizeState.size += 1;
            tokenizer.consume();
            return State.Next(name);
        }
        else {
            tokenizer.tokenizeState.size = 0;
            return State.Nok;
        }
    }

}
