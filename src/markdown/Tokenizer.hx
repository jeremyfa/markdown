// Ported from markdown 1.0.0: src/tokenizer.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown;

import haxe.io.Bytes;
import markdown.event.Content;
import markdown.event.Event;
import markdown.event.Kind;
import markdown.event.Link;
import markdown.event.Name;
import markdown.event.Point;
import markdown.message.Message;
import markdown.state.State;
import markdown.state.StateCall;
import markdown.util.Constant;
import markdown.util.EditMap;
import markdown.Resolve;
import markdown.Parser;

/** Containers (`Container` in `tokenizer.rs`). */
enum abstract Container(Int) {
    var BlockQuote = 0;
    var ListItem = 1;
    var GfmFootnoteDefinition = 2;
}

/** Info used to tokenize a container (`ContainerState`). */
class ContainerState {
    public var kind:Container;
    public var blankInitial:Bool;
    public var size:Int;

    public inline function new(kind:Container, blankInitial:Bool, size:Int) {
        this.kind = kind;
        this.blankInitial = blankInitial;
        this.size = size;
    }
}

/** Different kinds of attempts (`LabelKind`). */
enum abstract LabelKind(Int) {
    var Image = 0;
    var Link = 1;
    var GfmFootnote = 2;
    var GfmUndefinedFootnote = 3;
}

/** Label start, looking for an end (`LabelStart`). */
class LabelStart {
    public var kind:LabelKind;
    /** Indices of where the label starts and ends in `events`. */
    public var start0:Int;
    public var start1:Int;
    /** A boolean used internally to figure out if a (link) label start can't be used anymore. */
    public var inactive:Bool;

    public inline function new(kind:LabelKind, start0:Int, start1:Int, inactive:Bool) {
        this.kind = kind;
        this.start0 = start0;
        this.start1 = start1;
        this.inactive = inactive;
    }
}

/** Valid label (`Label`). */
class Label {
    public var kind:LabelKind;
    public var start0:Int;
    public var start1:Int;
    public var end0:Int;
    public var end1:Int;

    public inline function new(kind:LabelKind, start0:Int, start1:Int, end0:Int, end1:Int) {
        this.kind = kind;
        this.start0 = start0;
        this.start1 = start1;
        this.end0 = end0;
        this.end1 = end1;
    }
}

/** How to handle a byte (`ByteAction`): `Normal` is the byte, `Insert` is `-2 - byte`, `Ignore` is `-1`. */
private enum abstract ByteAction(Int) {
    var Ignore = -1;
}

/** State needed to rewind (`Progress`). */
private class Progress {
    public var eventsLen:Int;
    public var stackLen:Int;
    public var previous:Int;
    public var current:Int;
    public var point:Point;

    public inline function new(eventsLen:Int, stackLen:Int, previous:Int, current:Int, point:Point) {
        this.eventsLen = eventsLen;
        this.stackLen = stackLen;
        this.previous = previous;
        this.current = current;
        this.point = point;
    }
}

/** Attempts (`Attempt`). */
private class Attempt {
    public var ok:State;
    public var nok:State;
    public var check:Bool;
    public var progress:Null<Progress>;

    public inline function new(ok:State, nok:State, check:Bool, progress:Null<Progress>) {
        this.ok = ok;
        this.nok = nok;
        this.check = check;
        this.progress = progress;
    }
}

/** Info used to tokenize the current container (`TokenizeState`). */
class TokenizeState {
    // Couple complex fields used to tokenize the document.
    public var documentChild:Tokenizer = null;
    public var documentChildState:Null<State> = null;
    public var documentContainerStack:Array<ContainerState> = [];
    public var documentContinued:Int = 0;
    public var documentDataIndex:Int = -1;
    public var documentExits:Array<Array<Event>> = [];
    public var documentLazyAcceptingBefore:Bool = false;
    public var documentAtFirstParagraphOfListItem:Bool = false;

    // Couple of very frequent settings for parsing whitespace.
    public var spaceOrTabEolContent:Null<Content> = null;
    public var spaceOrTabEolConnect:Bool = false;
    public var spaceOrTabEolOk:Bool = false;
    public var spaceOrTabConnect:Bool = false;
    public var spaceOrTabContent:Null<Content> = null;
    public var spaceOrTabMin:Int = 0;
    public var spaceOrTabMax:Int = 0;
    public var spaceOrTabSize:Int = 0;
    public var spaceOrTabToken:Name = Name.SpaceOrTab;

    // Couple of media related fields.
    public var labelStarts:Array<LabelStart> = [];
    public var labelStartsLoose:Array<LabelStart> = [];
    public var labels:Array<Label> = [];

    /** List of defined definition identifiers. */
    public var definitions:Array<String> = [];
    /** List of defined GFM footnote definition identifiers. */
    public var gfmFootnoteDefinitions:Array<String> = [];

    /** Last error message provided at an EOF of an expression (reason, rule id, source). */
    public var mdxLastParseError:Null<Array<String>> = null;

    /** Whether to connect events. */
    public var connect:Bool = false;
    /** Marker. */
    public var marker:Int = 0;
    /** Secondary marker. */
    public var markerB:Int = 0;
    /** Several markers, as a lookup table of 256 bytes. */
    public var markers:Array<Bool> = NO_MARKERS;

    public static final NO_MARKERS:Array<Bool> = markerTable([]);

    /** Turn a list of bytes into a lookup table. */
    public static function markerTable(bytes:Array<Int>):Array<Bool> {
        var table = [for (_ in 0...256) false];
        for (b in bytes)
            table[b] = true;
        return table;
    }
    /** Whether something was seen. */
    public var seen:Bool = false;
    /** Size. */
    public var size:Int = 0;
    /** Secondary size. */
    public var sizeB:Int = 0;
    /** Tertiary size. */
    public var sizeC:Int = 0;
    /** Index. */
    public var start:Int = 0;
    /** Index. */
    public var end:Int = 0;
    /** Slot for an event name. */
    public var token1:Name = Name.Data;
    public var token2:Name = Name.Data;
    public var token3:Name = Name.Data;
    public var token4:Name = Name.Data;
    public var token5:Name = Name.Data;
    public var token6:Name = Name.Data;

    public function new() {}
}

/**
 * A tokenizer itself (`Tokenizer` in `tokenizer.rs`).
 *
 * `current` and `previous` are bytes, `-1` stands for `None` (end of file).
 */
class Tokenizer {

    /** Jump between line endings: pairs of index and virtual spaces, flattened. */
    var columnStart:Array<Int> = [];
    /** First line where this tokenizer starts. */
    var firstLine:Int;
    /** Current point after the last line ending (excluding jump). */
    var lineStart:Point;
    /** Track whether the current byte is already consumed. */
    var consumed:Bool = true;
    /** Stack of how to handle attempts. */
    var attempts:Array<Attempt> = [];
    /** Current byte. */
    public var current:Int = -1;
    /** Previous byte. */
    public var previous:Int = -1;
    /** Current relative and absolute place in the file. */
    public var point:Point;
    /** Semantic labels. */
    public var events:Array<Event> = [];
    /** Hierarchy of semantic labels. */
    public var stack:Array<Name> = [];
    /** Edit map, to batch changes. */
    public var map:EditMap = new EditMap();
    /** List of resolvers. */
    public var resolvers:Array<ResolveName> = [];
    /** Shared parsing state across tokenizers. */
    public var parseState:ParseState;
    /** A lot of shared fields used to tokenize things. */
    public var tokenizeState:TokenizeState = new TokenizeState();
    /** Whether we would be interrupting something. */
    public var interrupt:Bool = false;
    /** Whether containers cannot "pierce" into the current construct. */
    public var concrete:Bool = false;
    /** Whether this row is piercing into the current construct with more containers. */
    public var pierce:Bool = false;
    /** Whether this line is lazy: there are less containers than before. */
    public var lazy:Bool = false;

    /** The bytes of the document (shortcut to `parseState.bytes`). */
    public var bytes:Bytes;
    var bytesLen:Int;

    /** Create a new tokenizer. */
    public function new(point:Point, parseState:ParseState) {
        this.firstLine = point.line;
        this.lineStart = point.clone();
        this.point = point;
        this.parseState = parseState;
        this.bytes = parseState.bytes;
        this.bytesLen = parseState.bytes.length;
    }

    /** Register a resolver. */
    public function registerResolver(name:ResolveName):Void {
        if (resolvers.indexOf(name) == -1)
            resolvers.push(name);
    }

    /** Register a resolver, before others. */
    public function registerResolverBefore(name:ResolveName):Void {
        if (resolvers.indexOf(name) == -1)
            resolvers.unshift(name);
    }

    /** Define a jump between two places. */
    public function defineSkip(point:Point):Void {
        point = point.clone();
        movePointBack(point);
        var at = point.line - firstLine;
        if (at * 2 >= columnStart.length) {
            columnStart.push(point.index);
            columnStart.push(point.vs);
        }
        else {
            columnStart[at * 2] = point.index;
            columnStart[at * 2 + 1] = point.vs;
        }
        accountForPotentialSkip();
    }

    /** Increment the current positional info if we're right after a line ending, which has a skip defined. */
    function accountForPotentialSkip():Void {
        var at = point.line - firstLine;
        if (point.column == 1 && at * 2 != columnStart.length) {
            moveTo(columnStart[at * 2], columnStart[at * 2 + 1]);
        }
    }

    /** Prepare for a next byte to get consumed. */
    inline function expect(byte:Int):Void {
        consumed = false;
        current = byte;
    }

    /** Consume the current byte. */
    public function consume():Void {
        #if debug
        if (consumed)
            throw 'expected code to *not* have been consumed';
        #end
        moveOne();
        previous = current;
        current = -1;
        consumed = true;
    }

    /** Move to the next (virtual) byte. */
    function moveOne():Void {
        var action = byteAction(point);
        if (action == -1) {
            point.index += 1;
        }
        else if (action <= -2) {
            previous = -2 - action;
            point.column += 1;
            point.vs += 1;
        }
        else {
            previous = action;
            point.vs = 0;
            point.index += 1;
            if (action == '\n'.code) {
                point.line += 1;
                point.column = 1;
                if ((point.line - firstLine + 1) * 2 > columnStart.length) {
                    columnStart.push(point.index);
                    columnStart.push(point.vs);
                }
                lineStart = point.clone();
                accountForPotentialSkip();
            }
            else {
                point.column += 1;
            }
        }
    }

    /** Move (virtual) bytes. */
    function moveTo(toIndex:Int, toVs:Int):Void {
        while (point.index < toIndex || point.index == toIndex && point.vs < toVs) {
            moveOne();
        }
    }

    /** Mark the start of a semantic label. */
    public inline function enter(name:Name):Void {
        enterImpl(name, null);
    }

    /** Enter with a link. */
    public inline function enterLink(name:Name, link:Link):Void {
        enterImpl(name, link);
    }

    /** Mark the end of a semantic label. */
    public function exit(name:Name):Void {
        var current = stack.pop();
        #if debug
        if (current != name)
            throw 'expected exit event to match current event';
        #end
        var point = this.point.clone();
        if (previous == '\n'.code) {
            point = lineStart.clone();
        }
        else {
            movePointBack(point);
        }
        events.push(new Event(Kind.Exit, name, point, null));
    }

    /** Capture the tokenizer progress. */
    function capture():Progress {
        return new Progress(events.length, stack.length, previous, current, point.clone());
    }

    /** Apply tokenizer progress. */
    function free(previous:Progress):Void {
        this.previous = previous.previous;
        this.current = previous.current;
        this.point = previous.point;
        if (events.length > previous.eventsLen)
            events.resize(previous.eventsLen);
        if (stack.length > previous.stackLen)
            stack.resize(previous.stackLen);
    }

    /** Stack an attempt, moving to `ok` on `State.Ok` and `nok` on `State.Nok`, reverting in both cases. */
    public function check(ok:State, nok:State):Void {
        attempts.push(new Attempt(ok, nok, true, capture()));
    }

    /** Stack an attempt, moving to `ok` on `State.Ok` and `nok` on `State.Nok`, reverting in the latter case. */
    public function attempt(ok:State, nok:State):Void {
        var progress = nok == State.Nok ? null : capture();
        attempts.push(new Attempt(ok, nok, false, progress));
    }

    /** Tokenize `bytes` from `from` to `to`, starting at `state`. */
    public function push(fromIndex:Int, fromVs:Int, toIndex:Int, toVs:Int, state:State):State {
        return pushImpl(fromIndex, fromVs, toIndex, toVs, state, false);
    }

    /** Flush. Throws a `Message` on error. */
    public function flush(state:State, resolve:Bool):Subresult {
        var toIndex = point.index;
        var toVs = point.vs;
        var state = pushImpl(toIndex, toVs, toIndex, toVs, state, true);
        state.toResult();

        var value = new Subresult(false, tokenizeState.gfmFootnoteDefinitions, tokenizeState.definitions);
        tokenizeState.gfmFootnoteDefinitions = [];
        tokenizeState.definitions = [];

        if (resolve) {
            var resolvers = this.resolvers;
            this.resolvers = [];
            var index = 0;
            var defs = value.definitions;
            var fnDefs = value.gfmFootnoteDefinitions;

            while (index < resolvers.length) {
                var result = Resolve.call(this, resolvers[index]);
                if (result != null) {
                    for (d in result.gfmFootnoteDefinitions)
                        fnDefs.push(d);
                    for (d in result.definitions)
                        defs.push(d);
                }
                index += 1;
            }

            map.consume(events);
        }

        return value;
    }

    /** Move back past ignored bytes. */
    function movePointBack(point:Point):Void {
        while (point.index > 0) {
            point.index -= 1;
            var action = byteAction(point);
            if (action != -1) {
                point.index += 1;
                break;
            }
        }
    }

    /** Enter. */
    function enterImpl(name:Name, link:Null<Link>):Void {
        var point = this.point.clone();
        movePointBack(point);
        stack.push(name);
        events.push(new Event(Kind.Enter, name, point, link));
    }

    /** Run the tokenizer. */
    function pushImpl(fromIndex:Int, fromVs:Int, toIndex:Int, toVs:Int, state:State, flush:Bool):State {
        moveTo(fromIndex, fromVs);

        while (true) {
            if (state == State.Error) {
                break;
            }
            else if (state == State.Ok || state == State.Nok) {
                if (attempts.length > 0) {
                    var attempt = attempts.pop();
                    if (attempt.check || state == State.Nok) {
                        if (attempt.progress != null) {
                            free(attempt.progress);
                        }
                    }
                    consumed = true;
                    state = state == State.Ok ? attempt.ok : attempt.nok;
                }
                else {
                    break;
                }
            }
            else if (state.isNext()) {
                var action:Int;
                var hasAction = true;
                if (point.index < toIndex || (point.index == toIndex && point.vs < toVs)) {
                    action = byteAction(point);
                }
                else if (flush) {
                    action = 0;
                    hasAction = false;
                }
                else {
                    break;
                }

                if (hasAction && action == -1) {
                    moveOne();
                }
                else {
                    var byte = !hasAction ? -1 : (action <= -2 ? -2 - action : action);
                    expect(byte);
                    state = StateCall.call(this, state.name());
                }
            }
            else {
                state = StateCall.call(this, state.name());
            }
        }

        consumed = true;
        return state;
    }

    /**
     * Figure out how to handle a byte: `-1` is ignore, `<= -2` is insert
     * (`-2 - byte`), otherwise the byte itself.
     */
    function byteAction(point:Point):Int {
        if (point.index < bytesLen) {
            var byte = bytes.get(point.index);
            if (byte == '\r'.code) {
                // CRLF.
                if (point.index < bytesLen - 1 && bytes.get(point.index + 1) == '\n'.code) {
                    return -1;
                }
                // CR.
                else {
                    return '\n'.code;
                }
            }
            else if (byte == '\t'.code) {
                var remainder = point.column % Constant.TAB_SIZE;
                var vs = remainder == 0 ? 0 : Constant.TAB_SIZE - remainder;
                // On the tab itself, first send it.
                if (point.vs == 0) {
                    if (vs == 0) {
                        return byte;
                    }
                    else {
                        return -2 - byte;
                    }
                }
                else if (vs == 0) {
                    return ' '.code;
                }
                else {
                    return -2 - ' '.code;
                }
            }
            else {
                return byte;
            }
        }
        else {
            throw 'out of bounds';
        }
    }

}
