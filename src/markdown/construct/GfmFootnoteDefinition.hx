// Ported from markdown 1.0.0: src/construct/gfm_footnote_definition.rs
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
import markdown.util.NormalizeIdentifier;
import markdown.util.Skip;
import markdown.util.Slice;

/**
 * GFM: Footnote definition occurs in the document content type
 * (`gfm_footnote_definition.rs`).
 */
class GfmFootnoteDefinition {

    /** Start of GFM footnote definition. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.gfmFootnoteDefinition) {
            tokenizer.enter(Name.GfmFootnoteDefinition);

            if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
                tokenizer.attempt(State.Next(StateName.GfmFootnoteDefinitionLabelBefore), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 1,
                    tokenizer.parseState.options.constructs.codeIndented ? Constant.TAB_SIZE - 1 : PartialSpaceOrTab.MAX));
            }
            else {
                return State.Retry(StateName.GfmFootnoteDefinitionLabelBefore);
            }
        }
        else {
            return State.Nok;
        }
    }

    /** Before definition label (after optional whitespace). */
    public static function labelBefore(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '['.code:
                tokenizer.enter(Name.GfmFootnoteDefinitionPrefix);
                tokenizer.enter(Name.GfmFootnoteDefinitionLabel);
                tokenizer.enter(Name.GfmFootnoteDefinitionLabelMarker);
                tokenizer.consume();
                tokenizer.exit(Name.GfmFootnoteDefinitionLabelMarker);
                return State.Next(StateName.GfmFootnoteDefinitionLabelAtMarker);
            default:
                return State.Nok;
        }
    }

    /** In label, at caret. */
    public static function labelAtMarker(tokenizer:Tokenizer):State {
        if (tokenizer.current == '^'.code) {
            tokenizer.enter(Name.GfmFootnoteDefinitionMarker);
            tokenizer.consume();
            tokenizer.exit(Name.GfmFootnoteDefinitionMarker);
            tokenizer.enter(Name.GfmFootnoteDefinitionLabelString);
            tokenizer.enterLink(Name.Data, new Link(-1, -1, Content.String));
            return State.Next(StateName.GfmFootnoteDefinitionLabelInside);
        }
        else {
            return State.Nok;
        }
    }

    /** In label. */
    public static function labelInside(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        // Too long.
        if (tokenizer.tokenizeState.size > Constant.LINK_REFERENCE_SIZE_MAX
            // Space or tab is not supported by GFM for some reason (`\n` and `[` make sense).
            || c == -1 || c == '\t'.code || c == '\n'.code || c == ' '.code || c == '['.code
            // Closing brace with nothing.
            || (c == ']'.code && tokenizer.tokenizeState.size == 0)) {
            tokenizer.tokenizeState.size = 0;
            return State.Nok;
        }
        else if (c == ']'.code) {
            tokenizer.tokenizeState.size = 0;
            tokenizer.exit(Name.Data);
            tokenizer.exit(Name.GfmFootnoteDefinitionLabelString);
            tokenizer.enter(Name.GfmFootnoteDefinitionLabelMarker);
            tokenizer.consume();
            tokenizer.exit(Name.GfmFootnoteDefinitionLabelMarker);
            tokenizer.exit(Name.GfmFootnoteDefinitionLabel);
            return State.Next(StateName.GfmFootnoteDefinitionLabelAfter);
        }
        else {
            var next = c == '\\'.code ? StateName.GfmFootnoteDefinitionLabelEscape : StateName.GfmFootnoteDefinitionLabelInside;
            tokenizer.consume();
            tokenizer.tokenizeState.size += 1;
            return State.Next(next);
        }
    }

    /** After `\`, at a special character. */
    public static function labelEscape(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '['.code | '\\'.code | ']'.code:
                tokenizer.tokenizeState.size += 1;
                tokenizer.consume();
                return State.Next(StateName.GfmFootnoteDefinitionLabelInside);
            default:
                return State.Retry(StateName.GfmFootnoteDefinitionLabelInside);
        }
    }

    /** After definition label. */
    public static function labelAfter(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case ':'.code:
                var end = Skip.toBack(tokenizer.events, tokenizer.events.length - 1, [Name.GfmFootnoteDefinitionLabelString]);

                // Note: we don't care about virtual spaces, so `as_str` is fine.
                var id = NormalizeIdentifier.normalizeIdentifier(
                    Slice.fromPosition(tokenizer.parseState.bytes, SlicePosition.fromExitEvent(tokenizer.events, end)).asStr());

                // Note: we don't care about uniqueness.
                // It's likely that that doesn't happen very frequently.
                // It is more likely that it wastes precious time.
                tokenizer.tokenizeState.gfmFootnoteDefinitions.push(id);

                tokenizer.enter(Name.DefinitionMarker);
                tokenizer.consume();
                tokenizer.exit(Name.DefinitionMarker);
                tokenizer.attempt(State.Next(StateName.GfmFootnoteDefinitionWhitespaceAfter), State.Nok);
                // Any whitespace after the marker is eaten, forming indented code is not possible.
                // No space is also fine, just like a block quote marker.
                return State.Next(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 0, PartialSpaceOrTab.MAX));
            default:
                return State.Nok;
        }
    }

    /** After definition prefix. */
    public static function whitespaceAfter(tokenizer:Tokenizer):State {
        tokenizer.exit(Name.GfmFootnoteDefinitionPrefix);
        return State.Ok;
    }

    /** Start of footnote definition continuation. */
    public static function contStart(tokenizer:Tokenizer):State {
        tokenizer.check(State.Next(StateName.GfmFootnoteDefinitionContBlank), State.Next(StateName.GfmFootnoteDefinitionContFilled));
        return State.Retry(StateName.BlankLineStart);
    }

    /** Start of footnote definition continuation, at a blank line. */
    public static function contBlank(tokenizer:Tokenizer):State {
        if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 0, Constant.TAB_SIZE));
        }
        else {
            return State.Ok;
        }
    }

    /** Start of footnote definition continuation, at a filled line. */
    public static function contFilled(tokenizer:Tokenizer):State {
        if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            // Consume exactly `TAB_SIZE`.
            return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, Constant.TAB_SIZE, Constant.TAB_SIZE));
        }
        else {
            return State.Nok;
        }
    }

}
