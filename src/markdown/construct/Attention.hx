// Ported from markdown 1.0.0: src/construct/attention.rs
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
import markdown.event.Point;
import markdown.util.CharUtil;

/** Attention sequence that we can take markers from. */
private class Sequence {
    public var marker:Int;
    public var stack:Array<Int>;
    public var index:Int;
    public var startPoint:Point;
    public var endPoint:Point;
    public var size:Int;
    public var open:Bool;
    public var close:Bool;

    public function new(marker:Int, stack:Array<Int>, index:Int, startPoint:Point, endPoint:Point, size:Int, open:Bool, close:Bool) {
        this.marker = marker;
        this.stack = stack;
        this.index = index;
        this.startPoint = startPoint;
        this.endPoint = endPoint;
        this.size = size;
        this.open = open;
        this.close = close;
    }
}

/**
 * Attention (emphasis, strong, optionally GFM strikethrough) occurs in the
 * text content type (`attention.rs`).
 */
class Attention {

    /** Start of attention. */
    public static function start(tokenizer:Tokenizer):State {
        // Emphasis/strong:
        if ((tokenizer.parseState.options.constructs.attention && (tokenizer.current == '*'.code || tokenizer.current == '_'.code))
            // GFM strikethrough:
            || (tokenizer.parseState.options.constructs.gfmStrikethrough && tokenizer.current == '~'.code)) {
            tokenizer.tokenizeState.marker = tokenizer.current;
            tokenizer.enter(Name.AttentionSequence);
            return State.Retry(StateName.AttentionInside);
        }
        else {
            return State.Nok;
        }
    }

    /** In sequence. */
    public static function inside(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.marker) {
            tokenizer.consume();
            return State.Next(StateName.AttentionInside);
        }
        else {
            tokenizer.exit(Name.AttentionSequence);
            tokenizer.registerResolver(ResolveName.Attention);
            tokenizer.tokenizeState.marker = 0;
            return State.Ok;
        }
    }

    static function stackEquals(a:Array<Int>, b:Array<Int>):Bool {
        if (a.length != b.length)
            return false;
        for (i in 0...a.length)
            if (a[i] != b[i])
                return false;
        return true;
    }

    /** Resolve sequences. */
    public static function resolve(tokenizer:Tokenizer):Null<Subresult> {
        // Find all sequences, gather info about them.
        var sequences = getSequences(tokenizer);

        // Now walk through them and match them.
        var close = 0;

        while (close < sequences.length) {
            var sequenceClose = sequences[close];
            var nextIndex = close + 1;

            // Find a sequence that can close.
            if (sequenceClose.close) {
                var open = close;

                // Now walk back to find an opener.
                while (open > 0) {
                    open -= 1;

                    var sequenceOpen = sequences[open];

                    // An opener matching our closer:
                    if (sequenceOpen.open && sequenceClose.marker == sequenceOpen.marker && stackEquals(sequenceClose.stack, sequenceOpen.stack)) {
                        // If the opening can close or the closing can open, and the close size *is not* a multiple of three, but the sum of the opening and closing size *is* multiple of three, then **don't** match.
                        if ((sequenceOpen.close || sequenceClose.open) && sequenceClose.size % 3 != 0 && (sequenceOpen.size + sequenceClose.size) % 3 == 0) {
                            continue;
                        }

                        // For GFM strikethrough:
                        // * both sequences must have the same size
                        // * more than 2 markers don't work
                        // * one marker is prohibited by the spec, but supported by GH
                        if (sequenceClose.marker == '~'.code
                            && (sequenceClose.size != sequenceOpen.size
                                || sequenceClose.size > 2
                                || sequenceClose.size == 1 && !tokenizer.parseState.options.gfmStrikethroughSingleTilde)) {
                            continue;
                        }

                        // We found a match!
                        nextIndex = matchSequences(tokenizer, sequences, open, close);

                        break;
                    }
                }
            }

            close = nextIndex;
        }

        // Mark remaining sequences as data.
        var index = 0;
        while (index < sequences.length) {
            var sequence = sequences[index];
            tokenizer.events[sequence.index].name = Name.Data;
            tokenizer.events[sequence.index + 1].name = Name.Data;
            index += 1;
        }

        tokenizer.map.consume(tokenizer.events);
        return null;
    }

    /** Get sequences. */
    static function getSequences(tokenizer:Tokenizer):Array<Sequence> {
        var index = 0;
        var stack:Array<Int> = [];
        var sequences:Array<Sequence> = [];
        var bytes = tokenizer.parseState.bytes;
        var gfmStrikethrough = tokenizer.parseState.options.constructs.gfmStrikethrough;

        while (index < tokenizer.events.length) {
            var enter = tokenizer.events[index];

            if (enter.name == Name.AttentionSequence) {
                if (enter.kind == Kind.Enter) {
                    var end = index + 1;
                    var exit = tokenizer.events[end];

                    var marker = bytes.get(enter.point.index);
                    var beforeChar = CharUtil.beforeIndex(bytes, enter.point.index);
                    var before = CharUtil.classifyOpt(beforeChar);
                    var afterChar = CharUtil.afterIndex(bytes, exit.point.index);
                    var after = CharUtil.classifyOpt(afterChar);
                    var open = after == CharKind.Other
                        || (after == CharKind.Punctuation && before != CharKind.Other)
                        // For regular attention markers (not strikethrough), the other attention markers can be used around them
                        || (marker != '~'.code && (afterChar == '*'.code || afterChar == '_'.code))
                        || (marker != '~'.code && gfmStrikethrough && afterChar == '~'.code);
                    var close = before == CharKind.Other
                        || (before == CharKind.Punctuation && after != CharKind.Other)
                        || (marker != '~'.code && (beforeChar == '*'.code || beforeChar == '_'.code))
                        || (marker != '~'.code && gfmStrikethrough && beforeChar == '~'.code);

                    sequences.push(new Sequence(
                        marker,
                        stack.copy(),
                        index,
                        enter.point.clone(),
                        exit.point.clone(),
                        exit.point.index - enter.point.index,
                        marker == '_'.code ? open && (before != CharKind.Other || !close) : open,
                        marker == '_'.code ? close && (after != CharKind.Other || !open) : close
                    ));
                }
            }
            else if (enter.kind == Kind.Enter) {
                stack.push(index);
            }
            else {
                stack.pop();
            }

            index += 1;
        }

        return sequences;
    }

    /** Match two sequences. */
    static function matchSequences(tokenizer:Tokenizer, sequences:Array<Sequence>, open:Int, close:Int):Int {
        // Where to move to next.
        // Stay on this closing sequence for the next iteration: it might close more things.
        // It's changed if sequences are removed.
        var next = close;

        // Number of markers to use from the sequence.
        var take = sequences[open].size > 1 && sequences[close].size > 1 ? 2 : 1;

        // We're *on* a closing sequence, with a matching opening sequence.
        // Now we make sure that we can't have misnested attention:
        // Mark all sequences between them as not open.
        var between = open + 1;
        while (between < close) {
            sequences[between].open = false;
            between += 1;
        }

        var groupName:Name;
        var seqName:Name;
        var textName:Name;
        if (sequences[open].marker == '~'.code) {
            groupName = Name.GfmStrikethrough;
            seqName = Name.GfmStrikethroughSequence;
            textName = Name.GfmStrikethroughText;
        }
        else if (take == 1) {
            groupName = Name.Emphasis;
            seqName = Name.EmphasisSequence;
            textName = Name.EmphasisText;
        }
        else {
            groupName = Name.Strong;
            seqName = Name.StrongSequence;
            textName = Name.StrongText;
        }
        var openIndex = sequences[open].index;
        var closeIndex = sequences[close].index;
        var openExit = sequences[open].endPoint.clone();
        var closeEnter = sequences[close].startPoint.clone();

        // No need to worry about `VS`, because sequences are only actual characters.
        sequences[open].size -= take;
        sequences[close].size -= take;
        sequences[open].endPoint.column -= take;
        sequences[open].endPoint.index -= take;
        sequences[close].startPoint.column += take;
        sequences[close].startPoint.index += take;

        // Opening.
        tokenizer.map.addBefore(openIndex + 2, 0, [
            new Event(Kind.Enter, groupName, sequences[open].endPoint.clone(), null),
            new Event(Kind.Enter, seqName, sequences[open].endPoint.clone(), null),
            new Event(Kind.Exit, seqName, openExit.clone(), null),
            new Event(Kind.Enter, textName, openExit, null),
        ]);
        // Closing.
        tokenizer.map.add(closeIndex, 0, [
            new Event(Kind.Exit, textName, closeEnter.clone(), null),
            new Event(Kind.Enter, seqName, closeEnter, null),
            new Event(Kind.Exit, seqName, sequences[close].startPoint.clone(), null),
            new Event(Kind.Exit, groupName, sequences[close].startPoint.clone(), null),
        ]);

        // Remove closing sequence if fully used.
        if (sequences[close].size == 0) {
            sequences.splice(close, 1);
            tokenizer.map.add(closeIndex, 2, []);
        }
        else {
            // Shift remaining closing sequence forward.
            // Do it here because a sequence can open and close different other sequences, and the remainder can be on any side or somewhere in the middle.
            tokenizer.events[closeIndex].point = sequences[close].startPoint.clone();
        }

        if (sequences[open].size == 0) {
            sequences.splice(open, 1);
            tokenizer.map.add(openIndex, 2, []);
            // Everything shifts one to the left, account for it in next iteration.
            next -= 1;
        }
        else {
            tokenizer.events[openIndex + 1].point = sequences[open].endPoint.clone();
        }

        return next;
    }

}
