// Ported from markdown 1.0.0: src/construct/text.rs
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
 * The text content type (`text.rs`).
 */
class Text {

    /** Characters that can start something in text. */
    static final MARKERS:Array<Bool> = TokenizeState.markerTable([
        '!'.code, // `label_start_image`
        '$'.code, // `raw_text` (math (text))
        '&'.code, // `character_reference`
        '*'.code, // `attention` (emphasis, strong)
        '<'.code, // `autolink`, `html_text`, `mdx_jsx_text`
        'H'.code, // `gfm_autolink_literal` (`protocol` kind)
        'W'.code, // `gfm_autolink_literal` (`www.` kind)
        '['.code, // `label_start_link`
        '\\'.code, // `character_escape`, `hard_break_escape`
        ']'.code, // `label_end`, `gfm_label_start_footnote`
        '_'.code, // `attention` (emphasis, strong)
        '`'.code, // `raw_text` (code (text))
        'h'.code, // `gfm_autolink_literal` (`protocol` kind)
        'w'.code, // `gfm_autolink_literal` (`www.` kind)
        '{'.code, // `mdx_expression_text`
        '~'.code, // `attention` (gfm strikethrough)
    ]);

    /** Start of text. */
    public static function start(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.markers = MARKERS;
        tokenizer.attempt(State.Next(StateName.TextBefore), State.Next(StateName.TextBefore));
        return State.Retry(StateName.GfmTaskListItemCheckStart);
    }

    /** Before text. */
    public static function before(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1:
                tokenizer.registerResolver(ResolveName.Data);
                tokenizer.registerResolver(ResolveName.Text);
                return State.Ok;
            case '!'.code:
                tokenizer.attempt(State.Next(StateName.TextBefore), State.Next(StateName.TextBeforeData));
                return State.Retry(StateName.LabelStartImageStart);
            case '$'.code | '`'.code:
                tokenizer.attempt(State.Next(StateName.TextBefore), State.Next(StateName.TextBeforeData));
                return State.Retry(StateName.RawTextStart);
            case '&'.code:
                tokenizer.attempt(State.Next(StateName.TextBefore), State.Next(StateName.TextBeforeData));
                return State.Retry(StateName.CharacterReferenceStart);
            case '*'.code | '_'.code | '~'.code:
                tokenizer.attempt(State.Next(StateName.TextBefore), State.Next(StateName.TextBeforeData));
                return State.Retry(StateName.AttentionStart);
            // `autolink`, `html_text` (order does not matter), `mdx_jsx_text` (order matters).
            case '<'.code:
                tokenizer.attempt(State.Next(StateName.TextBefore), State.Next(StateName.TextBeforeHtml));
                return State.Retry(StateName.AutolinkStart);
            case 'H'.code | 'h'.code:
                tokenizer.attempt(State.Next(StateName.TextBefore), State.Next(StateName.TextBeforeData));
                return State.Retry(StateName.GfmAutolinkLiteralProtocolStart);
            case 'W'.code | 'w'.code:
                tokenizer.attempt(State.Next(StateName.TextBefore), State.Next(StateName.TextBeforeData));
                return State.Retry(StateName.GfmAutolinkLiteralWwwStart);
            case '['.code:
                tokenizer.attempt(State.Next(StateName.TextBefore), State.Next(StateName.TextBeforeLabelStartLink));
                return State.Retry(StateName.GfmLabelStartFootnoteStart);
            case '\\'.code:
                tokenizer.attempt(State.Next(StateName.TextBefore), State.Next(StateName.TextBeforeHardBreakEscape));
                return State.Retry(StateName.CharacterEscapeStart);
            case ']'.code:
                tokenizer.attempt(State.Next(StateName.TextBefore), State.Next(StateName.TextBeforeData));
                return State.Retry(StateName.LabelEndStart);
            case '{'.code:
                tokenizer.attempt(State.Next(StateName.TextBefore), State.Next(StateName.TextBeforeData));
                return State.Retry(StateName.MdxExpressionTextStart);
            default:
                return State.Retry(StateName.TextBeforeData);
        }
    }

    /** Before html (html (text) or mdx jsx (text)). */
    public static function beforeHtml(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.TextBefore), State.Next(StateName.TextBeforeMdxJsx));
        return State.Retry(StateName.HtmlTextStart);
    }

    /** Before mdx jsx (text). */
    public static function beforeMdxJsx(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.TextBefore), State.Next(StateName.TextBeforeData));
        return State.Retry(StateName.MdxJsxTextStart);
    }

    /** Before hard break escape. */
    public static function beforeHardBreakEscape(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.TextBefore), State.Next(StateName.TextBeforeData));
        return State.Retry(StateName.HardBreakEscapeStart);
    }

    /** Before label start (link). */
    public static function beforeLabelStartLink(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.TextBefore), State.Next(StateName.TextBeforeData));
        return State.Retry(StateName.LabelStartLinkStart);
    }

    /** Before data. */
    public static function beforeData(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.TextBefore), State.Nok);
        return State.Retry(StateName.DataStart);
    }

    /** Resolve whitespace. */
    public static function resolve(tokenizer:Tokenizer):Null<Subresult> {
        PartialWhitespace.resolveWhitespace(tokenizer, tokenizer.parseState.options.constructs.hardBreakTrailing, true);

        if (tokenizer.parseState.options.constructs.gfmAutolinkLiteral) {
            GfmAutolinkLiteral.resolveGfmAutolinkLiteral(tokenizer);
        }

        tokenizer.map.consume(tokenizer.events);
        return null;
    }

}
