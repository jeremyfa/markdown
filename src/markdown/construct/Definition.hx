// Ported from markdown 1.0.0: src/construct/definition.rs
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
import markdown.util.NormalizeIdentifier;
import markdown.util.Skip;
import markdown.util.Slice;

/**
 * Definition occurs in the content content type (`definition.rs`).
 */
class Definition {

    static function resetTokens(tokenizer:Tokenizer, count:Int):Void {
        tokenizer.tokenizeState.token1 = Name.Data;
        tokenizer.tokenizeState.token2 = Name.Data;
        tokenizer.tokenizeState.token3 = Name.Data;
        if (count > 3) {
            tokenizer.tokenizeState.token4 = Name.Data;
            tokenizer.tokenizeState.token5 = Name.Data;
        }
    }

    /** At start of a definition. */
    public static function start(tokenizer:Tokenizer):State {
        // Do not interrupt paragraphs (but do follow definitions).
        if (tokenizer.parseState.options.constructs.definition
            && (!tokenizer.interrupt
                || (tokenizer.events.length > 0
                    && tokenizer.events[Skip.optBack(tokenizer.events, tokenizer.events.length - 1, [Name.LineEnding, Name.SpaceOrTab])].name == Name.Definition))) {
            tokenizer.enter(Name.Definition);

            if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
                // Note: arbitrary whitespace allowed even if code (indented) is on.
                tokenizer.attempt(State.Next(StateName.DefinitionBefore), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
            }
            else {
                return State.Retry(StateName.DefinitionBefore);
            }
        }
        else {
            return State.Nok;
        }
    }

    /** After optional whitespace, at `[`. */
    public static function before(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '['.code:
                tokenizer.tokenizeState.token1 = Name.DefinitionLabel;
                tokenizer.tokenizeState.token2 = Name.DefinitionLabelMarker;
                tokenizer.tokenizeState.token3 = Name.DefinitionLabelString;
                tokenizer.attempt(State.Next(StateName.DefinitionLabelAfter), State.Next(StateName.DefinitionLabelNok));
                return State.Retry(StateName.LabelStart);
            default:
                return State.Nok;
        }
    }

    /** After label. */
    public static function labelAfter(tokenizer:Tokenizer):State {
        resetTokens(tokenizer, 3);

        switch tokenizer.current {
            case ':'.code:
                tokenizer.tokenizeState.end = Skip.toBack(tokenizer.events, tokenizer.events.length - 1, [Name.DefinitionLabelString]);

                tokenizer.enter(Name.DefinitionMarker);
                tokenizer.consume();
                tokenizer.exit(Name.DefinitionMarker);
                return State.Next(StateName.DefinitionMarkerAfter);
            default:
                return State.Nok;
        }
    }

    /** At a non-label. */
    public static function labelNok(tokenizer:Tokenizer):State {
        resetTokens(tokenizer, 3);
        return State.Nok;
    }

    /** After marker. */
    public static function markerAfter(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.DefinitionDestinationBefore), State.Next(StateName.DefinitionDestinationBefore));
        return State.Retry(PartialSpaceOrTabEol.spaceOrTabEol(tokenizer));
    }

    /** Before destination. */
    public static function destinationBefore(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.token1 = Name.DefinitionDestination;
        tokenizer.tokenizeState.token2 = Name.DefinitionDestinationLiteral;
        tokenizer.tokenizeState.token3 = Name.DefinitionDestinationLiteralMarker;
        tokenizer.tokenizeState.token4 = Name.DefinitionDestinationRaw;
        tokenizer.tokenizeState.token5 = Name.DefinitionDestinationString;
        tokenizer.tokenizeState.sizeB = PartialSpaceOrTab.MAX;
        tokenizer.attempt(State.Next(StateName.DefinitionDestinationAfter), State.Next(StateName.DefinitionDestinationMissing));
        return State.Retry(StateName.DestinationStart);
    }

    /** After destination. */
    public static function destinationAfter(tokenizer:Tokenizer):State {
        resetTokens(tokenizer, 5);
        tokenizer.tokenizeState.sizeB = 0;
        tokenizer.attempt(State.Next(StateName.DefinitionAfter), State.Next(StateName.DefinitionAfter));
        return State.Retry(StateName.DefinitionTitleBefore);
    }

    /** Without destination. */
    public static function destinationMissing(tokenizer:Tokenizer):State {
        resetTokens(tokenizer, 5);
        tokenizer.tokenizeState.sizeB = 0;
        tokenizer.tokenizeState.end = 0;
        return State.Nok;
    }

    /** After definition. */
    public static function after(tokenizer:Tokenizer):State {
        if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            tokenizer.attempt(State.Next(StateName.DefinitionAfterWhitespace), State.Nok);
            return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
        }
        else {
            return State.Retry(StateName.DefinitionAfterWhitespace);
        }
    }

    /** After definition, after optional whitespace. */
    public static function afterWhitespace(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                tokenizer.exit(Name.Definition);

                // Note: we don't care about uniqueness.
                // It's likely that that doesn't happen very frequently.
                // It is more likely that it wastes precious time.
                tokenizer.tokenizeState.definitions.push(NormalizeIdentifier.normalizeIdentifier(
                    Slice.fromPosition(tokenizer.parseState.bytes, SlicePosition.fromExitEvent(tokenizer.events, tokenizer.tokenizeState.end)).asStr()));

                tokenizer.tokenizeState.end = 0;

                // You'd be interrupting.
                tokenizer.interrupt = true;
                return State.Ok;
            default:
                tokenizer.tokenizeState.end = 0;
                return State.Nok;
        }
    }

    /** After destination, at whitespace. */
    public static function titleBefore(tokenizer:Tokenizer):State {
        if (tokenizer.current == '\t'.code || tokenizer.current == '\n'.code || tokenizer.current == ' '.code) {
            tokenizer.attempt(State.Next(StateName.DefinitionTitleBeforeMarker), State.Nok);
            return State.Retry(PartialSpaceOrTabEol.spaceOrTabEol(tokenizer));
        }
        else {
            return State.Nok;
        }
    }

    /** At title. */
    public static function titleBeforeMarker(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.token1 = Name.DefinitionTitle;
        tokenizer.tokenizeState.token2 = Name.DefinitionTitleMarker;
        tokenizer.tokenizeState.token3 = Name.DefinitionTitleString;
        tokenizer.attempt(State.Next(StateName.DefinitionTitleAfter), State.Nok);
        return State.Retry(StateName.TitleStart);
    }

    /** After title. */
    public static function titleAfter(tokenizer:Tokenizer):State {
        resetTokens(tokenizer, 3);
        if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            tokenizer.attempt(State.Next(StateName.DefinitionTitleAfterOptionalWhitespace), State.Nok);
            return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
        }
        else {
            return State.Retry(StateName.DefinitionTitleAfterOptionalWhitespace);
        }
    }

    /** After title, after optional whitespace. */
    public static function titleAfterOptionalWhitespace(tokenizer:Tokenizer):State {
        return switch tokenizer.current {
            case -1 | '\n'.code: State.Ok;
            default: State.Nok;
        }
    }

}
