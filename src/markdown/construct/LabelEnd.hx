// Ported from markdown 1.0.0: src/construct/label_end.rs
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
 * Label end occurs in the text content type (`label_end.rs`).
 */
class LabelEnd {

    static function resetTokens(tokenizer:Tokenizer, count:Int):Void {
        tokenizer.tokenizeState.token1 = Name.Data;
        tokenizer.tokenizeState.token2 = Name.Data;
        tokenizer.tokenizeState.token3 = Name.Data;
        if (count > 3) {
            tokenizer.tokenizeState.token4 = Name.Data;
            tokenizer.tokenizeState.token5 = Name.Data;
        }
    }

    /** Start of label end. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.current == ']'.code && tokenizer.parseState.options.constructs.labelEnd) {
            // If there is an okay opening:
            if (tokenizer.tokenizeState.labelStarts.length > 0) {
                var labelStart = tokenizer.tokenizeState.labelStarts[tokenizer.tokenizeState.labelStarts.length - 1];

                tokenizer.tokenizeState.end = tokenizer.events.length;

                // If the corresponding label (link) start is marked as inactive, it means we'd be wrapping a link, like this:
                // `[a [b](c) d](e)`. We can't have that, so it's just balanced brackets.
                if (labelStart.inactive) {
                    return State.Retry(StateName.LabelEndNok);
                }

                tokenizer.enter(Name.LabelEnd);
                tokenizer.enter(Name.LabelMarker);
                tokenizer.consume();
                tokenizer.exit(Name.LabelMarker);
                tokenizer.exit(Name.LabelEnd);
                return State.Next(StateName.LabelEndAfter);
            }
        }

        return State.Nok;
    }

    /** After `]`. */
    public static function after(tokenizer:Tokenizer):State {
        var startIndex = tokenizer.tokenizeState.labelStarts.length - 1;
        var start = tokenizer.tokenizeState.labelStarts[startIndex];

        var id = NormalizeIdentifier.normalizeIdentifier(
            Slice.fromIndices(tokenizer.parseState.bytes, tokenizer.events[start.start1].point.index, tokenizer.events[tokenizer.tokenizeState.end].point.index).asStr());

        // See if this matches a footnote definition.
        if (start.kind == LabelKind.GfmFootnote) {
            if (tokenizer.parseState.gfmFootnoteDefinitions.indexOf(id) != -1) {
                return State.Retry(StateName.LabelEndOk);
            }

            // Nope, this might be a normal link?
            tokenizer.tokenizeState.labelStarts[startIndex].kind = LabelKind.GfmUndefinedFootnote;
            id = '^' + id;
        }

        var defined = tokenizer.parseState.definitions.indexOf(id) != -1;

        switch tokenizer.current {
            // Resource (`[asd](fgh)`)?
            case '('.code:
                tokenizer.attempt(State.Next(StateName.LabelEndOk), State.Next(defined ? StateName.LabelEndOk : StateName.LabelEndNok));
                return State.Retry(StateName.LabelEndResourceStart);
            // Full (`[asd][fgh]`) or collapsed (`[asd][]`) reference?
            case '['.code:
                tokenizer.attempt(State.Next(StateName.LabelEndOk), State.Next(defined ? StateName.LabelEndReferenceNotFull : StateName.LabelEndNok));
                return State.Retry(StateName.LabelEndReferenceFull);
            // Shortcut (`[asd]`) reference?
            default:
                return State.Retry(defined ? StateName.LabelEndOk : StateName.LabelEndNok);
        }
    }

    /** After `]`, at `[`, but not at a full reference. */
    public static function referenceNotFull(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.LabelEndOk), State.Next(StateName.LabelEndNok));
        return State.Retry(StateName.LabelEndReferenceCollapsed);
    }

    /** Done, we found something. */
    public static function ok(tokenizer:Tokenizer):State {
        // Remove the start.
        var labelStart = tokenizer.tokenizeState.labelStarts.pop();

        // If this is a link or footnote, we need to mark earlier link starts as no longer viable for use (as they would otherwise contain a link).
        // These link starts are still looking for balanced closing brackets, so we can't remove them, but we can mark them.
        if (labelStart.kind != LabelKind.Image) {
            var index = 0;
            while (index < tokenizer.tokenizeState.labelStarts.length) {
                var labelStart = tokenizer.tokenizeState.labelStarts[index];
                if (labelStart.kind != LabelKind.Image) {
                    labelStart.inactive = true;
                }
                index += 1;
            }
        }

        tokenizer.tokenizeState.labels.push(new Label(labelStart.kind, labelStart.start0, labelStart.start1, tokenizer.tokenizeState.end, tokenizer.events.length - 1));
        tokenizer.tokenizeState.end = 0;
        tokenizer.registerResolverBefore(ResolveName.Label);
        return State.Ok;
    }

    /** Done, it's nothing. */
    public static function nok(tokenizer:Tokenizer):State {
        var start = tokenizer.tokenizeState.labelStarts.pop();
        tokenizer.tokenizeState.labelStartsLoose.push(start);
        tokenizer.tokenizeState.end = 0;
        return State.Nok;
    }

    /** At a resource. */
    public static function resourceStart(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '('.code:
                tokenizer.enter(Name.Resource);
                tokenizer.enter(Name.ResourceMarker);
                tokenizer.consume();
                tokenizer.exit(Name.ResourceMarker);
                return State.Next(StateName.LabelEndResourceBefore);
            default:
                throw 'expected `(`';
        }
    }

    /** In resource, after `(`, at optional whitespace. */
    public static function resourceBefore(tokenizer:Tokenizer):State {
        if (tokenizer.current == '\t'.code || tokenizer.current == '\n'.code || tokenizer.current == ' '.code) {
            tokenizer.attempt(State.Next(StateName.LabelEndResourceOpen), State.Next(StateName.LabelEndResourceOpen));
            return State.Retry(PartialSpaceOrTabEol.spaceOrTabEol(tokenizer));
        }
        else {
            return State.Retry(StateName.LabelEndResourceOpen);
        }
    }

    /** In resource, after optional whitespace, at `)` or a destination. */
    public static function resourceOpen(tokenizer:Tokenizer):State {
        if (tokenizer.current == ')'.code) {
            return State.Retry(StateName.LabelEndResourceEnd);
        }
        else {
            tokenizer.tokenizeState.token1 = Name.ResourceDestination;
            tokenizer.tokenizeState.token2 = Name.ResourceDestinationLiteral;
            tokenizer.tokenizeState.token3 = Name.ResourceDestinationLiteralMarker;
            tokenizer.tokenizeState.token4 = Name.ResourceDestinationRaw;
            tokenizer.tokenizeState.token5 = Name.ResourceDestinationString;
            tokenizer.tokenizeState.sizeB = Constant.RESOURCE_DESTINATION_BALANCE_MAX;

            tokenizer.attempt(State.Next(StateName.LabelEndResourceDestinationAfter), State.Next(StateName.LabelEndResourceDestinationMissing));
            return State.Retry(StateName.DestinationStart);
        }
    }

    /** In resource, after destination, at optional whitespace. */
    public static function resourceDestinationAfter(tokenizer:Tokenizer):State {
        resetTokens(tokenizer, 5);
        tokenizer.tokenizeState.sizeB = 0;

        if (tokenizer.current == '\t'.code || tokenizer.current == '\n'.code || tokenizer.current == ' '.code) {
            tokenizer.attempt(State.Next(StateName.LabelEndResourceBetween), State.Next(StateName.LabelEndResourceEnd));
            return State.Retry(PartialSpaceOrTabEol.spaceOrTabEol(tokenizer));
        }
        else {
            return State.Retry(StateName.LabelEndResourceEnd);
        }
    }

    /** At invalid destination. */
    public static function resourceDestinationMissing(tokenizer:Tokenizer):State {
        resetTokens(tokenizer, 5);
        tokenizer.tokenizeState.sizeB = 0;
        return State.Nok;
    }

    /** In resource, after destination and whitespace, at `(` or title. */
    public static function resourceBetween(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '"'.code | "'".code | '('.code:
                tokenizer.tokenizeState.token1 = Name.ResourceTitle;
                tokenizer.tokenizeState.token2 = Name.ResourceTitleMarker;
                tokenizer.tokenizeState.token3 = Name.ResourceTitleString;
                tokenizer.attempt(State.Next(StateName.LabelEndResourceTitleAfter), State.Nok);
                return State.Retry(StateName.TitleStart);
            default:
                return State.Retry(StateName.LabelEndResourceEnd);
        }
    }

    /** In resource, after title, at optional whitespace. */
    public static function resourceTitleAfter(tokenizer:Tokenizer):State {
        resetTokens(tokenizer, 3);

        if (tokenizer.current == '\t'.code || tokenizer.current == '\n'.code || tokenizer.current == ' '.code) {
            tokenizer.attempt(State.Next(StateName.LabelEndResourceEnd), State.Next(StateName.LabelEndResourceEnd));
            return State.Retry(PartialSpaceOrTabEol.spaceOrTabEol(tokenizer));
        }
        else {
            return State.Retry(StateName.LabelEndResourceEnd);
        }
    }

    /** In resource, at `)`. */
    public static function resourceEnd(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case ')'.code:
                tokenizer.enter(Name.ResourceMarker);
                tokenizer.consume();
                tokenizer.exit(Name.ResourceMarker);
                tokenizer.exit(Name.Resource);
                return State.Ok;
            default:
                return State.Nok;
        }
    }

    /** In reference (full), at `[`. */
    public static function referenceFull(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '['.code:
                tokenizer.tokenizeState.token1 = Name.Reference;
                tokenizer.tokenizeState.token2 = Name.ReferenceMarker;
                tokenizer.tokenizeState.token3 = Name.ReferenceString;
                tokenizer.attempt(State.Next(StateName.LabelEndReferenceFullAfter), State.Next(StateName.LabelEndReferenceFullMissing));
                return State.Retry(StateName.LabelStart);
            default:
                throw 'expected `[`';
        }
    }

    /** In reference (full), after `]`. */
    public static function referenceFullAfter(tokenizer:Tokenizer):State {
        resetTokens(tokenizer, 3);

        var id = NormalizeIdentifier.normalizeIdentifier(Slice.fromPosition(tokenizer.parseState.bytes,
            SlicePosition.fromExitEvent(tokenizer.events, Skip.toBack(tokenizer.events, tokenizer.events.length - 1, [Name.ReferenceString]))).asStr());
        return tokenizer.parseState.definitions.indexOf(id) != -1 ? State.Ok : State.Nok;
    }

    /** In reference (full) that was missing. */
    public static function referenceFullMissing(tokenizer:Tokenizer):State {
        resetTokens(tokenizer, 3);
        return State.Nok;
    }

    /** In reference (collapsed), at `[`. */
    public static function referenceCollapsed(tokenizer:Tokenizer):State {
        tokenizer.enter(Name.Reference);
        tokenizer.enter(Name.ReferenceMarker);
        tokenizer.consume();
        tokenizer.exit(Name.ReferenceMarker);
        return State.Next(StateName.LabelEndReferenceCollapsedOpen);
    }

    /** In reference (collapsed), at `]`. */
    public static function referenceCollapsedOpen(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case ']'.code:
                tokenizer.enter(Name.ReferenceMarker);
                tokenizer.consume();
                tokenizer.exit(Name.ReferenceMarker);
                tokenizer.exit(Name.Reference);
                return State.Ok;
            default:
                return State.Nok;
        }
    }

    /** Resolve images, links, and footnotes. */
    public static function resolve(tokenizer:Tokenizer):Null<Subresult> {
        var labels = tokenizer.tokenizeState.labels;
        tokenizer.tokenizeState.labels = [];
        injectLabels(tokenizer, labels);

        var starts = tokenizer.tokenizeState.labelStarts;
        tokenizer.tokenizeState.labelStarts = [];
        markAsData(tokenizer, starts);
        var starts = tokenizer.tokenizeState.labelStartsLoose;
        tokenizer.tokenizeState.labelStartsLoose = [];
        markAsData(tokenizer, starts);

        tokenizer.map.consume(tokenizer.events);
        return null;
    }

    /** Inject links/images/footnotes. */
    static function injectLabels(tokenizer:Tokenizer, labels:Array<Label>):Void {
        var index = 0;

        while (index < labels.length) {
            var label = labels[index];
            var groupName = label.kind == LabelKind.GfmFootnote ? Name.GfmFootnoteCall : label.kind == LabelKind.Image ? Name.Image : Name.Link;

            // If this is a fine link, which starts with a footnote start that did not match, we need to inject the caret as data.
            var caret:Array<Event> = [];

            if (label.kind == LabelKind.GfmUndefinedFootnote) {
                // Add caret.
                caret.push(new Event(Kind.Enter, Name.Data, tokenizer.events[label.start1 - 2].point.clone(), null));
                caret.push(new Event(Kind.Exit, Name.Data, tokenizer.events[label.start1 - 1].point.clone(), null));
                // Change and move label end.
                tokenizer.events[label.start0].name = Name.LabelLink;
                tokenizer.events[label.start1].name = Name.LabelLink;
                tokenizer.events[label.start1].point = caret[0].point.clone();
                // Remove the caret.
                tokenizer.map.add(label.start1 - 2, 2, []);
            }

            // Insert a group enter and label enter.
            tokenizer.map.add(label.start0, 0, [
                new Event(Kind.Enter, groupName, tokenizer.events[label.start0].point.clone(), null),
                new Event(Kind.Enter, Name.Label, tokenizer.events[label.start0].point.clone(), null),
            ]);

            // Empty events not allowed.
            // Though: if this was what looked like a footnote, but didn't match, it's a link instead, and we need to inject the `^`.
            if (label.start1 != label.end0 || caret.length > 0) {
                tokenizer.map.addBefore(label.start1 + 1, 0, [
                    new Event(Kind.Enter, Name.LabelText, tokenizer.events[label.start1].point.clone(), null),
                ]);
                tokenizer.map.add(label.end0, 0, [
                    new Event(Kind.Exit, Name.LabelText, tokenizer.events[label.end0].point.clone(), null),
                ]);
            }

            if (caret.length > 0) {
                tokenizer.map.add(label.start1 + 1, 0, caret);
            }

            // Insert a label exit.
            tokenizer.map.add(label.end0 + 4, 0, [
                new Event(Kind.Exit, Name.Label, tokenizer.events[label.end0 + 3].point.clone(), null),
            ]);

            // Insert a group exit.
            tokenizer.map.add(label.end1 + 1, 0, [
                new Event(Kind.Exit, groupName, tokenizer.events[label.end1].point.clone(), null),
            ]);

            index += 1;
        }
    }

    /** Remove loose label starts. */
    static function markAsData(tokenizer:Tokenizer, events:Array<LabelStart>):Void {
        var index = 0;

        while (index < events.length) {
            var dataEnterIndex = events[index].start0;
            var dataExitIndex = events[index].start1;

            tokenizer.map.add(dataEnterIndex, dataExitIndex - dataEnterIndex + 1, [
                new Event(Kind.Enter, Name.Data, tokenizer.events[dataEnterIndex].point.clone(), null),
                new Event(Kind.Exit, Name.Data, tokenizer.events[dataExitIndex].point.clone(), null),
            ]);

            index += 1;
        }
    }

}
