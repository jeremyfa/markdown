// Ported from markdown 1.0.0: src/to_html.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown;

import haxe.io.Bytes;
import markdown.event.Event;
import markdown.event.Kind;
import markdown.event.Name;
import markdown.mdast.AlignKind;
import markdown.util.CaseMap;
import markdown.util.CharacterReference;
import markdown.util.Constant;
import markdown.util.Encode;
import markdown.util.GfmTagfilter;
import markdown.util.Infer;
import markdown.util.LineEnding;
import markdown.util.NormalizeIdentifier;
import markdown.util.SanitizeUri;
import markdown.util.Skip;
import markdown.util.Slice;

/** Link, image, or footnote call (`Media`). */
private class Media {
    /** Whether this represents an image (`true`) or a link or definition (`false`). */
    public var image:Bool;
    /** The text between the brackets (`x` in `![x]()` and `[x]()`), as indices (`-1` for none). */
    public var labelId0:Int = -1;
    public var labelId1:Int = -1;
    /** The text between the brackets, as compiled HTML. */
    public var label:Null<String> = null;
    /** The text between the second brackets (`x` in `![a][x]` and `[a][x]`), as indices (`-1` for none). */
    public var referenceId0:Int = -1;
    public var referenceId1:Int = -1;
    /** The destination (url). */
    public var destination:Null<String> = null;
    /** The title. */
    public var title:Null<String> = null;

    public function new(image:Bool) {
        this.image = image;
    }
}

/** Representation of a definition. */
private class Definition {
    public var id:String;
    public var destination:Null<String>;
    public var title:Null<String>;

    public function new(id:String, destination:Null<String>, title:Null<String>) {
        this.id = id;
        this.destination = destination;
        this.title = title;
    }
}

/** A buffer that remembers its last byte (to check for line endings). */
private class Buffer {
    public var buf:StringBuf = new StringBuf();
    public var last:Int = -1;

    public function new() {}

    public inline function add(value:String):Void {
        var len = value.length;
        if (len > 0) {
            buf.add(value);
            last = StringTools.fastCodeAt(value, len - 1);
        }
    }

    public inline function toString():String {
        return buf.toString();
    }
}

/** Context used to compile markdown (`CompileContext`). */
private class CompileContext {
    public var events:Array<Event>;
    public var bytes:Bytes;
    public var options:CompileOptions;
    public var headingAtxRank:Int = -1;
    public var headingSetextBuffer:Null<String> = null;
    /** `-1` for none, `0` for false, `1` for true. */
    public var rawFlowSeenData:Int = -1;
    public var rawFlowFencesCount:Int = -1;
    public var rawTextInside:Bool = false;
    public var imageAltInside:Bool = false;
    public var characterReferenceMarker:Int = -1;
    /** `-1` for none, `0` for false, `1` for true. */
    public var listExpectFirstMarker:Int = -1;
    public var mediaStack:Array<Media> = [];
    public var tightStack:Array<Bool> = [];
    public var definitions:Array<Definition> = [];
    /** Pairs of id and compiled HTML. */
    public var gfmFootnoteDefinitions:Array<Array<String>> = [];
    /** Ids and call counts. */
    public var gfmFootnoteDefinitionCallIds:Array<String> = [];
    public var gfmFootnoteDefinitionCallCounts:Array<Int> = [];
    /** Pairs of indices, flattened. */
    public var gfmFootnoteDefinitionStack:Array<Int> = [];
    public var gfmTableInHead:Bool = false;
    public var gfmTableAlign:Null<Array<AlignKind>> = null;
    public var gfmTableColumn:Int = 0;
    public var slurpOneLineEnding:Bool = false;
    public var encodeHtml:Bool = true;
    public var lineEndingDefault:LineEnding;
    public var buffers:Array<Buffer>;
    public var index:Int = 0;

    public function new(events:Array<Event>, bytes:Bytes, options:CompileOptions, lineEnding:LineEnding) {
        this.events = events;
        this.bytes = bytes;
        this.options = options;
        this.lineEndingDefault = lineEnding;
        this.buffers = [new Buffer()];
    }

    /** Push a buffer. */
    public inline function buffer():Void {
        buffers.push(new Buffer());
    }

    /** Pop a buffer, returning its value. */
    public inline function resume():String {
        return buffers.pop().toString();
    }

    /** Push a str to the last buffer. */
    public inline function push(value:String):Void {
        buffers[buffers.length - 1].add(value);
    }

    /** Add a line ending. */
    public inline function lineEnding():Void {
        push(lineEndingDefault.asStr());
    }

    /** Add a line ending if needed (as in, there's no eol/eof already). */
    public function lineEndingIfNeeded():Void {
        var last = buffers[buffers.length - 1].last;
        if (!(last == -1 || last == '\n'.code || last == '\r'.code)) {
            lineEnding();
        }
    }
}

/**
 * Turn events and bytes into a string of HTML (`to_html.rs`).
 */
class ToHtml {

    /** Turn events and bytes into a string of HTML. */
    public static function compile(events:Array<Event>, bytes:Bytes, options:CompileOptions):String {
        var index = 0;
        var lineEndingInferred:Null<LineEnding> = null;

        // First, we figure out what the used line ending style is.
        // Stop when we find a line ending.
        while (index < events.length) {
            var event = events[index];

            // Find a line ending.
            if (event.kind == Kind.Exit && (event.name == Name.BlankLineEnding || event.name == Name.LineEnding)) {
                var slice = Slice.fromPosition(bytes, SlicePosition.fromExitEvent(events, index));
                lineEndingInferred = markdown.util.LineEnding.fromStr(slice.asStr());
                break;
            }

            index += 1;
        }

        // Figure out which line ending style we'll use.
        var lineEndingDefault = lineEndingInferred != null ? lineEndingInferred : options.defaultLineEnding;

        var context = new CompileContext(events, bytes, options, lineEndingDefault);
        var definitionIndices:Array<Int> = [];
        var index = 0;
        var definitionInside = false;

        // Handle all definitions first.
        // We must do two passes because we need to compile the events in
        // definitions which come after references already.
        //
        // To speed things up, we collect the places we can jump over for the
        // second pass.
        //
        // We don't need to handle GFM footnote definitions like this, because
        // unlike normal definitions, what they produce is not used in calls.
        // It would also get very complex, because footnote definitions can be
        // nested.
        while (index < events.length) {
            var event = events[index];

            if (definitionInside) {
                handle(context, index);
            }

            if (event.kind == Kind.Enter) {
                if (event.name == Name.Definition) {
                    handle(context, index); // Also handle start.
                    definitionInside = true;
                    definitionIndices.push(index);
                    definitionIndices.push(index);
                }
            }
            else if (event.name == Name.Definition) {
                definitionInside = false;
                definitionIndices[definitionIndices.length - 1] = index;
            }

            index += 1;
        }

        var index = 0;
        var definitionIndex = 0;
        var jump0 = definitionIndices.length > 0 ? definitionIndices[0] : events.length;
        var jump1 = definitionIndices.length > 0 ? definitionIndices[1] : events.length;

        while (index < events.length) {
            if (index == jump0) {
                index = jump1 + 1;
                definitionIndex += 1;
                jump0 = definitionIndex * 2 < definitionIndices.length ? definitionIndices[definitionIndex * 2] : events.length;
                jump1 = definitionIndex * 2 < definitionIndices.length ? definitionIndices[definitionIndex * 2 + 1] : events.length;
            }
            else {
                handle(context, index);
                index += 1;
            }
        }

        // No section to generate.
        if (context.gfmFootnoteDefinitionCallIds.length > 0) {
            generateFootnoteSection(context);
        }

        return context.buffers[0].toString();
    }

    /** Handle the event at `index`. */
    static function handle(context:CompileContext, index:Int):Void {
        context.index = index;

        if (context.events[index].kind == Kind.Enter) {
            enter(context);
        }
        else {
            exit(context);
        }
    }

    /** Handle [`Enter`][Kind::Enter]. */
    static function enter(context:CompileContext):Void {
        switch context.events[context.index].name {
            case Name.CodeFencedFenceInfo | Name.CodeFencedFenceMeta | Name.MathFlowFenceMeta | Name.DefinitionLabelString
                | Name.DefinitionTitleString | Name.GfmFootnoteDefinitionPrefix | Name.HeadingAtxText | Name.HeadingSetextText
                | Name.Label | Name.MdxEsm | Name.MdxFlowExpression | Name.MdxTextExpression | Name.MdxJsxFlowTag
                | Name.MdxJsxTextTag | Name.ReferenceString | Name.ResourceTitleString:
                onEnterBuffer(context);
            case Name.BlockQuote: onEnterBlockQuote(context);
            case Name.CodeIndented: onEnterCodeIndented(context);
            case Name.CodeFenced | Name.MathFlow: onEnterRawFlow(context);
            case Name.CodeText | Name.MathText: onEnterRawText(context);
            case Name.Definition: onEnterDefinition(context);
            case Name.DefinitionDestinationString: onEnterDefinitionDestinationString(context);
            case Name.Emphasis: onEnterEmphasis(context);
            case Name.Frontmatter: onEnterFrontmatter(context);
            case Name.GfmFootnoteDefinition: onEnterGfmFootnoteDefinition(context);
            case Name.GfmFootnoteCall: onEnterGfmFootnoteCall(context);
            case Name.GfmStrikethrough: onEnterGfmStrikethrough(context);
            case Name.GfmTable: onEnterGfmTable(context);
            case Name.GfmTableBody: onEnterGfmTableBody(context);
            case Name.GfmTableCell: onEnterGfmTableCell(context);
            case Name.GfmTableHead: onEnterGfmTableHead(context);
            case Name.GfmTableRow: onEnterGfmTableRow(context);
            case Name.GfmTaskListItemCheck: onEnterGfmTaskListItemCheck(context);
            case Name.HtmlFlow: onEnterHtmlFlow(context);
            case Name.HtmlText: onEnterHtmlText(context);
            case Name.Image: onEnterImage(context);
            case Name.Link: onEnterLink(context);
            case Name.ListItemMarker: onEnterListItemMarker(context);
            case Name.ListOrdered | Name.ListUnordered: onEnterList(context);
            case Name.Paragraph: onEnterParagraph(context);
            case Name.Resource: onEnterResource(context);
            case Name.ResourceDestinationString: onEnterResourceDestinationString(context);
            case Name.Strong: onEnterStrong(context);
            default:
        }
    }

    /** Handle [`Exit`][Kind::Exit]. */
    static function exit(context:CompileContext):Void {
        switch context.events[context.index].name {
            case Name.CodeFencedFenceMeta | Name.MathFlowFenceMeta | Name.MdxJsxTextTag | Name.MdxTextExpression | Name.Resource:
                onExitDrop(context);
            case Name.MdxEsm | Name.MdxFlowExpression | Name.MdxJsxFlowTag: onExitDropSlurp(context);
            case Name.CharacterEscapeValue | Name.CodeTextData | Name.Data | Name.MathTextData:
                onExitData(context);
            case Name.AutolinkEmail: onExitAutolinkEmail(context);
            case Name.AutolinkProtocol: onExitAutolinkProtocol(context);
            case Name.BlankLineEnding: onExitBlankLineEnding(context);
            case Name.BlockQuote: onExitBlockQuote(context);
            case Name.CharacterReferenceMarker: onExitCharacterReferenceMarker(context);
            case Name.CharacterReferenceMarkerNumeric: onExitCharacterReferenceMarkerNumeric(context);
            case Name.CharacterReferenceMarkerHexadecimal: onExitCharacterReferenceMarkerHexadecimal(context);
            case Name.CharacterReferenceValue: onExitCharacterReferenceValue(context);
            case Name.CodeFenced | Name.CodeIndented | Name.MathFlow: onExitRawFlow(context);
            case Name.CodeFencedFence | Name.MathFlowFence: onExitRawFlowFence(context);
            case Name.CodeFencedFenceInfo: onExitRawFlowFenceInfo(context);
            case Name.CodeFlowChunk | Name.MathFlowChunk: onExitRawFlowChunk(context);
            case Name.CodeText | Name.MathText: onExitRawText(context);
            case Name.Definition: onExitDefinition(context);
            case Name.DefinitionDestinationString: onExitDefinitionDestinationString(context);
            case Name.DefinitionLabelString: onExitDefinitionLabelString(context);
            case Name.DefinitionTitleString: onExitDefinitionTitleString(context);
            case Name.Emphasis: onExitEmphasis(context);
            case Name.Frontmatter: onExitFrontmatter(context);
            case Name.GfmAutolinkLiteralEmail: onExitGfmAutolinkLiteralEmail(context);
            case Name.GfmAutolinkLiteralMailto: onExitGfmAutolinkLiteralMailto(context);
            case Name.GfmAutolinkLiteralProtocol: onExitGfmAutolinkLiteralProtocol(context);
            case Name.GfmAutolinkLiteralWww: onExitGfmAutolinkLiteralWww(context);
            case Name.GfmAutolinkLiteralXmpp: onExitGfmAutolinkLiteralXmpp(context);
            case Name.GfmFootnoteCall: onExitGfmFootnoteCall(context);
            case Name.GfmFootnoteDefinitionLabelString: onExitGfmFootnoteDefinitionLabelString(context);
            case Name.GfmFootnoteDefinitionPrefix: onExitGfmFootnoteDefinitionPrefix(context);
            case Name.GfmFootnoteDefinition: onExitGfmFootnoteDefinition(context);
            case Name.GfmStrikethrough: onExitGfmStrikethrough(context);
            case Name.GfmTable: onExitGfmTable(context);
            case Name.GfmTableBody: onExitGfmTableBody(context);
            case Name.GfmTableCell: onExitGfmTableCell(context);
            case Name.GfmTableHead: onExitGfmTableHead(context);
            case Name.GfmTableRow: onExitGfmTableRow(context);
            case Name.GfmTaskListItemCheck: onExitGfmTaskListItemCheck(context);
            case Name.GfmTaskListItemValueChecked: onExitGfmTaskListItemValueChecked(context);
            case Name.HardBreakEscape | Name.HardBreakTrailing: onExitBreak(context);
            case Name.HeadingAtx: onExitHeadingAtx(context);
            case Name.HeadingAtxSequence: onExitHeadingAtxSequence(context);
            case Name.HeadingAtxText: onExitHeadingAtxText(context);
            case Name.HeadingSetextText: onExitHeadingSetextText(context);
            case Name.HeadingSetextUnderlineSequence: onExitHeadingSetextUnderlineSequence(context);
            case Name.HtmlFlow | Name.HtmlText: onExitHtml(context);
            case Name.HtmlFlowData | Name.HtmlTextData: onExitHtmlData(context);
            case Name.Image | Name.Link: onExitMedia(context);
            case Name.Label: onExitLabel(context);
            case Name.LabelText: onExitLabelText(context);
            case Name.LineEnding: onExitLineEnding(context);
            case Name.ListOrdered | Name.ListUnordered: onExitList(context);
            case Name.ListItem: onExitListItem(context);
            case Name.ListItemValue: onExitListItemValue(context);
            case Name.Paragraph: onExitParagraph(context);
            case Name.ReferenceString: onExitReferenceString(context);
            case Name.ResourceDestinationString: onExitResourceDestinationString(context);
            case Name.ResourceTitleString: onExitResourceTitleString(context);
            case Name.Strong: onExitStrong(context);
            case Name.ThematicBreak: onExitThematicBreak(context);
            default:
        }
    }

    static inline function exitSlice(context:CompileContext):Slice {
        return Slice.fromPosition(context.bytes, SlicePosition.fromExitEvent(context.events, context.index));
    }

    static inline function lastMedia(context:CompileContext):Media {
        return context.mediaStack[context.mediaStack.length - 1];
    }

    static inline function tight(context:CompileContext):Bool {
        return context.tightStack.length > 0 ? context.tightStack[context.tightStack.length - 1] : false;
    }

    static function onEnterBuffer(context:CompileContext):Void {
        context.buffer();
    }

    static function onEnterBlockQuote(context:CompileContext):Void {
        context.tightStack.push(false);
        context.lineEndingIfNeeded();
        context.push('<blockquote>');
    }

    static function onEnterCodeIndented(context:CompileContext):Void {
        context.rawFlowSeenData = 0;
        context.lineEndingIfNeeded();
        context.push('<pre><code>');
    }

    static function onEnterRawFlow(context:CompileContext):Void {
        context.rawFlowSeenData = 0;
        context.lineEndingIfNeeded();
        // Note that no `>` is used, which is added later (due to info)
        context.push('<pre><code');
        context.rawFlowFencesCount = 0;

        if (context.events[context.index].name == Name.MathFlow) {
            context.push(' class="language-math math-display"');
        }
    }

    static function onEnterRawText(context:CompileContext):Void {
        context.rawTextInside = true;
        if (!context.imageAltInside) {
            context.push('<code');
            if (context.events[context.index].name == Name.MathText) {
                context.push(' class="language-math math-inline"');
            }
            context.push('>');
        }
        context.buffer();
    }

    static function onEnterDefinition(context:CompileContext):Void {
        context.buffer();
        context.mediaStack.push(new Media(false));
    }

    static function onEnterDefinitionDestinationString(context:CompileContext):Void {
        context.buffer();
        context.encodeHtml = false;
    }

    static function onEnterEmphasis(context:CompileContext):Void {
        if (!context.imageAltInside) {
            context.push('<em>');
        }
    }

    static function onEnterFrontmatter(context:CompileContext):Void {
        context.buffer();
    }

    static function onEnterGfmFootnoteDefinition(context:CompileContext):Void {
        context.tightStack.push(false);
    }

    static function onEnterGfmFootnoteCall(context:CompileContext):Void {
        context.mediaStack.push(new Media(false));
    }

    static function onEnterGfmStrikethrough(context:CompileContext):Void {
        if (!context.imageAltInside) {
            context.push('<del>');
        }
    }

    static function onEnterGfmTable(context:CompileContext):Void {
        var align = Infer.gfmTableAlign(context.events, context.index);
        context.gfmTableAlign = align;
        context.lineEndingIfNeeded();
        context.push('<table>');
    }

    static function onEnterGfmTableBody(context:CompileContext):Void {
        context.push('<tbody>');
    }

    static function onEnterGfmTableCell(context:CompileContext):Void {
        var column = context.gfmTableColumn;
        var align = context.gfmTableAlign;

        if (column >= align.length) {
            // Capture cell to ignore it.
            context.buffer();
        }
        else {
            var value = align[column];
            context.lineEndingIfNeeded();

            if (context.gfmTableInHead) {
                context.push('<th');
            }
            else {
                context.push('<td');
            }

            switch value {
                case Left: context.push(' align="left"');
                case Right: context.push(' align="right"');
                case Center: context.push(' align="center"');
                case None:
            }

            context.push('>');
        }
    }

    static function onEnterGfmTableHead(context:CompileContext):Void {
        context.lineEndingIfNeeded();
        context.push('<thead>');
        context.gfmTableInHead = true;
    }

    static function onEnterGfmTableRow(context:CompileContext):Void {
        context.lineEndingIfNeeded();
        context.push('<tr>');
    }

    static function onEnterGfmTaskListItemCheck(context:CompileContext):Void {
        if (!context.imageAltInside) {
            context.push('<input type="checkbox" ');
            if (!context.options.gfmTaskListItemCheckable) {
                context.push('disabled="" ');
            }
        }
    }

    static function onEnterHtmlFlow(context:CompileContext):Void {
        context.lineEndingIfNeeded();
        if (context.options.allowDangerousHtml) {
            context.encodeHtml = false;
        }
    }

    static function onEnterHtmlText(context:CompileContext):Void {
        if (context.options.allowDangerousHtml) {
            context.encodeHtml = false;
        }
    }

    static function onEnterImage(context:CompileContext):Void {
        context.mediaStack.push(new Media(true));
        context.imageAltInside = true; // Disallow tags.
    }

    static function onEnterLink(context:CompileContext):Void {
        context.mediaStack.push(new Media(false));
    }

    static function onEnterList(context:CompileContext):Void {
        var loose = Infer.listLoose(context.events, context.index, true);
        context.tightStack.push(!loose);
        context.lineEndingIfNeeded();

        // Note: no `>`.
        context.push(context.events[context.index].name == Name.ListOrdered ? '<ol' : '<ul');
        context.listExpectFirstMarker = 1;
    }

    static function onEnterListItemMarker(context:CompileContext):Void {
        var expect = context.listExpectFirstMarker;
        context.listExpectFirstMarker = -1;
        if (expect == 1) {
            context.push('>');
        }

        context.lineEndingIfNeeded();
        context.push('<li>');
        context.listExpectFirstMarker = 0;
    }

    static function onEnterParagraph(context:CompileContext):Void {
        if (!tight(context)) {
            context.lineEndingIfNeeded();
            context.push('<p>');
        }
    }

    static function onEnterResource(context:CompileContext):Void {
        context.buffer(); // We can have line endings in the resource, ignore them.
        lastMedia(context).destination = '';
    }

    static function onEnterResourceDestinationString(context:CompileContext):Void {
        context.buffer();
        // Ignore encoding the result, as we'll first percent encode the url and
        // encode manually after.
        context.encodeHtml = false;
    }

    static function onEnterStrong(context:CompileContext):Void {
        if (!context.imageAltInside) {
            context.push('<strong>');
        }
    }

    static function onExitAutolinkEmail(context:CompileContext):Void {
        generateAutolink(context, 'mailto:', exitSlice(context).asStr(), false);
    }

    static function onExitAutolinkProtocol(context:CompileContext):Void {
        generateAutolink(context, null, exitSlice(context).asStr(), false);
    }

    static function onExitBreak(context:CompileContext):Void {
        if (!context.imageAltInside) {
            context.push('<br />');
        }
    }

    static function onExitBlankLineEnding(context:CompileContext):Void {
        context.slurpOneLineEnding = false;
        if (context.index == context.events.length - 1) {
            context.lineEndingIfNeeded();
        }
    }

    static function onExitBlockQuote(context:CompileContext):Void {
        context.tightStack.pop();
        context.lineEndingIfNeeded();
        context.slurpOneLineEnding = false;
        context.push('</blockquote>');
    }

    static function onExitCharacterReferenceMarker(context:CompileContext):Void {
        context.characterReferenceMarker = '&'.code;
    }

    static function onExitCharacterReferenceMarkerHexadecimal(context:CompileContext):Void {
        context.characterReferenceMarker = 'x'.code;
    }

    static function onExitCharacterReferenceMarkerNumeric(context:CompileContext):Void {
        context.characterReferenceMarker = '#'.code;
    }

    static function onExitCharacterReferenceValue(context:CompileContext):Void {
        var marker = context.characterReferenceMarker;
        context.characterReferenceMarker = -1;
        var slice = exitSlice(context);
        var value = markdown.util.CharacterReference.decode(slice.asStr(), marker, true);
        context.push(Encode.encode(value, context.encodeHtml));
    }

    static function onExitRawFlowChunk(context:CompileContext):Void {
        context.rawFlowSeenData = 1;
        context.push(Encode.encode(exitSlice(context).serialize(), context.encodeHtml));
    }

    static function onExitRawFlowFence(context:CompileContext):Void {
        var count = context.rawFlowFencesCount;

        if (count == 0) {
            context.push('>');
            context.slurpOneLineEnding = true;
        }

        context.rawFlowFencesCount = count + 1;
    }

    static function onExitRawFlowFenceInfo(context:CompileContext):Void {
        var value = context.resume();
        context.push(' class="language-');
        context.push(value);
        context.push('"');
    }

    static function onExitRawFlow(context:CompileContext):Void {
        // One special case is if we are inside a container, and the raw (flow) was
        // not closed (meaning it runs to the end).
        // In that case, the following line ending, is considered *outside* the
        // fenced code and block quote by `markdown-rs`, but CM wants to treat that
        // ending as part of the code.
        if (context.rawFlowFencesCount != -1) {
            var count = context.rawFlowFencesCount;
            if (count == 1 && context.tightStack.length > 0
                && !(context.events[context.index - 1].name == Name.CodeFencedFence || context.events[context.index - 1].name == Name.MathFlowFence)) {
                context.lineEnding();
            }
        }

        // But in most cases, it's simpler: when we've seen some data, emit an extra
        // line ending when needed.
        var seen = context.rawFlowSeenData;
        context.rawFlowSeenData = -1;
        if (seen == 1) {
            context.lineEndingIfNeeded();
        }

        context.push('</code></pre>');

        var count = context.rawFlowFencesCount;
        context.rawFlowFencesCount = -1;
        if (count != -1) {
            if (count < 2) {
                context.lineEndingIfNeeded();
            }
        }

        context.slurpOneLineEnding = false;
    }

    static function onExitRawText(context:CompileContext):Void {
        var result = context.resume();
        // To do: share with `to_mdast`.
        var bytes:Array<Int> = [];
        var b = Utf8Helper.bytesOf(result);
        for (i in 0...b.length)
            bytes.push(b.get(i));

        // If we are in a GFM table, we need to decode escaped pipes.
        // This is a rather weird GFM feature.
        if (context.gfmTableAlign != null) {
            var index = 0;
            var len = bytes.length;

            while (index < len) {
                if (index + 1 < len && bytes[index] == '\\'.code && bytes[index + 1] == '|'.code) {
                    bytes.splice(index, 1);
                    len -= 1;
                }

                index += 1;
            }
        }

        var trim = false;
        var index = 0;
        var end = bytes.length;

        if (end > 2 && bytes[index] == ' '.code && bytes[end - 1] == ' '.code) {
            index += 1;
            end -= 1;
            while (index < end && !trim) {
                if (bytes[index] != ' '.code) {
                    trim = true;
                    break;
                }
                index += 1;
            }
        }

        if (trim) {
            bytes.shift();
            bytes.pop();
        }

        context.rawTextInside = false;
        var out = new haxe.io.BytesBuffer();
        for (x in bytes)
            out.addByte(x);
        context.push(Utf8Helper.bytesToString(out.getBytes()));

        if (!context.imageAltInside) {
            context.push('</code>');
        }
    }

    static function onExitDrop(context:CompileContext):Void {
        context.resume();
    }

    static function onExitDropSlurp(context:CompileContext):Void {
        context.resume();
        context.slurpOneLineEnding = true;
    }

    static function onExitData(context:CompileContext):Void {
        context.push(Encode.encode(exitSlice(context).asStr(), context.encodeHtml));
    }

    static function onExitDefinition(context:CompileContext):Void {
        context.resume();
        var media = context.mediaStack.pop();
        var id = NormalizeIdentifier.normalizeIdentifier(Slice.fromIndices(context.bytes, media.referenceId0, media.referenceId1).asStr());

        context.definitions.push(new Definition(id, media.destination, media.title));
    }

    static function onExitDefinitionDestinationString(context:CompileContext):Void {
        var buf = context.resume();
        lastMedia(context).destination = buf;
        context.encodeHtml = true;
    }

    static function onExitDefinitionLabelString(context:CompileContext):Void {
        // Discard label, use the source content instead.
        context.resume();
        var position = SlicePosition.fromExitEvent(context.events, context.index);
        lastMedia(context).referenceId0 = position.start.index;
        lastMedia(context).referenceId1 = position.end.index;
    }

    static function onExitDefinitionTitleString(context:CompileContext):Void {
        var buf = context.resume();
        lastMedia(context).title = buf;
    }

    static function onExitEmphasis(context:CompileContext):Void {
        if (!context.imageAltInside) {
            context.push('</em>');
        }
    }

    static function onExitFrontmatter(context:CompileContext):Void {
        context.resume();
        context.slurpOneLineEnding = true;
    }

    static function onExitGfmAutolinkLiteralEmail(context:CompileContext):Void {
        generateAutolink(context, 'mailto:', exitSlice(context).asStr(), true);
    }

    static function onExitGfmAutolinkLiteralMailto(context:CompileContext):Void {
        generateAutolink(context, null, exitSlice(context).asStr(), true);
    }

    static function onExitGfmAutolinkLiteralProtocol(context:CompileContext):Void {
        generateAutolink(context, null, exitSlice(context).asStr(), true);
    }

    static function onExitGfmAutolinkLiteralWww(context:CompileContext):Void {
        generateAutolink(context, 'http://', exitSlice(context).asStr(), true);
    }

    static function onExitGfmAutolinkLiteralXmpp(context:CompileContext):Void {
        generateAutolink(context, null, exitSlice(context).asStr(), true);
    }

    static function onExitGfmFootnoteCall(context:CompileContext):Void {
        var media = context.mediaStack.pop();
        var id = NormalizeIdentifier.normalizeIdentifier(Slice.fromIndices(context.bytes, media.labelId0, media.labelId1).asStr());
        var safeId = SanitizeUri.sanitize(CaseMap.lowercase(id));
        var callIndex = 0;

        // See if this has been called before.
        while (callIndex < context.gfmFootnoteDefinitionCallIds.length) {
            if (context.gfmFootnoteDefinitionCallIds[callIndex] == id) {
                break;
            }
            callIndex += 1;
        }

        // New.
        if (callIndex == context.gfmFootnoteDefinitionCallIds.length) {
            context.gfmFootnoteDefinitionCallIds.push(id);
            context.gfmFootnoteDefinitionCallCounts.push(0);
        }

        // Increment.
        context.gfmFootnoteDefinitionCallCounts[callIndex] += 1;

        // No call is output in an image alt, though the definition and
        // backreferences are generated as if it was the case.
        if (context.imageAltInside) {
            return;
        }

        context.push('<sup><a href="#');
        if (context.options.gfmFootnoteClobberPrefix != null) {
            context.push(Encode.encode(context.options.gfmFootnoteClobberPrefix, context.encodeHtml));
        }
        else {
            context.push('user-content-');
        }
        context.push('fn-');
        context.push(safeId);
        context.push('" id="');
        if (context.options.gfmFootnoteClobberPrefix != null) {
            context.push(Encode.encode(context.options.gfmFootnoteClobberPrefix, context.encodeHtml));
        }
        else {
            context.push('user-content-');
        }
        context.push('fnref-');
        context.push(safeId);
        if (context.gfmFootnoteDefinitionCallCounts[callIndex] > 1) {
            context.push('-');
            context.push(Std.string(context.gfmFootnoteDefinitionCallCounts[callIndex]));
        }
        context.push('" data-footnote-ref="" aria-describedby="footnote-label">');

        context.push(Std.string(callIndex + 1));
        context.push('</a></sup>');
    }

    static function onExitGfmFootnoteDefinitionLabelString(context:CompileContext):Void {
        var position = SlicePosition.fromExitEvent(context.events, context.index);
        context.gfmFootnoteDefinitionStack.push(position.start.index);
        context.gfmFootnoteDefinitionStack.push(position.end.index);
    }

    static function onExitGfmFootnoteDefinitionPrefix(context:CompileContext):Void {
        // Drop the prefix.
        context.resume();
        // Capture everything until end of definition.
        context.buffer();
    }

    static function onExitGfmFootnoteDefinition(context:CompileContext):Void {
        var value = context.resume();
        var end = context.gfmFootnoteDefinitionStack.pop();
        var start = context.gfmFootnoteDefinitionStack.pop();
        context.tightStack.pop();
        context.gfmFootnoteDefinitions.push([
            NormalizeIdentifier.normalizeIdentifier(Slice.fromIndices(context.bytes, start, end).asStr()),
            value
        ]);
    }

    static function onExitGfmStrikethrough(context:CompileContext):Void {
        if (!context.imageAltInside) {
            context.push('</del>');
        }
    }

    static function onExitGfmTable(context:CompileContext):Void {
        context.gfmTableAlign = null;
        context.lineEndingIfNeeded();
        context.push('</table>');
    }

    static function onExitGfmTableBody(context:CompileContext):Void {
        context.lineEndingIfNeeded();
        context.push('</tbody>');
    }

    static function onExitGfmTableCell(context:CompileContext):Void {
        var align = context.gfmTableAlign;

        if (context.gfmTableColumn < align.length) {
            if (context.gfmTableInHead) {
                context.push('</th>');
            }
            else {
                context.push('</td>');
            }
        }
        else {
            // Stop capturing.
            context.resume();
        }

        context.gfmTableColumn += 1;
    }

    static function onExitGfmTableHead(context:CompileContext):Void {
        context.gfmTableInHead = false;
        context.lineEndingIfNeeded();
        context.push('</thead>');
    }

    static function onExitGfmTableRow(context:CompileContext):Void {
        var column = context.gfmTableColumn;
        var len = context.gfmTableAlign.length;

        // Add "phantom" cells, for body rows that are shorter than the delimiter
        // row (which is equal to the head row).
        while (column < len) {
            onEnterGfmTableCell(context);
            onExitGfmTableCell(context);
            column += 1;
        }

        context.gfmTableColumn = 0;
        context.lineEndingIfNeeded();
        context.push('</tr>');
    }

    static function onExitGfmTaskListItemCheck(context:CompileContext):Void {
        if (!context.imageAltInside) {
            context.push('/>');
        }
    }

    static function onExitGfmTaskListItemValueChecked(context:CompileContext):Void {
        if (!context.imageAltInside) {
            context.push('checked="" ');
        }
    }

    static function onExitHeadingAtx(context:CompileContext):Void {
        var rank = context.headingAtxRank;
        context.headingAtxRank = -1;

        context.push('</h');
        context.push(Std.string(rank));
        context.push('>');
    }

    static function onExitHeadingAtxSequence(context:CompileContext):Void {
        // First fence we see.
        if (context.headingAtxRank == -1) {
            var rank = exitSlice(context).len();
            context.lineEndingIfNeeded();
            context.headingAtxRank = rank;
            context.push('<h');
            context.push(Std.string(rank));
            context.push('>');
        }
    }

    static function onExitHeadingAtxText(context:CompileContext):Void {
        var value = context.resume();
        context.push(value);
    }

    static function onExitHeadingSetextText(context:CompileContext):Void {
        var buf = context.resume();
        context.headingSetextBuffer = buf;
        context.slurpOneLineEnding = true;
    }

    static function onExitHeadingSetextUnderlineSequence(context:CompileContext):Void {
        var text = context.headingSetextBuffer;
        context.headingSetextBuffer = null;
        var position = SlicePosition.fromExitEvent(context.events, context.index);
        var head = context.bytes.get(position.start.index);
        var rank = head == '-'.code ? '2' : '1';

        context.lineEndingIfNeeded();
        context.push('<h');
        context.push(rank);
        context.push('>');
        context.push(text);
        context.push('</h');
        context.push(rank);
        context.push('>');
    }

    static function onExitHtml(context:CompileContext):Void {
        context.encodeHtml = true;
    }

    static function onExitHtmlData(context:CompileContext):Void {
        var value = exitSlice(context).asStr();

        var encoded = context.options.gfmTagfilter && context.options.allowDangerousHtml
            ? Encode.encode(GfmTagfilter.gfmTagfilter(value), context.encodeHtml)
            : Encode.encode(value, context.encodeHtml);

        context.push(encoded);
    }

    static function onExitLabel(context:CompileContext):Void {
        var buf = context.resume();
        lastMedia(context).label = buf;
    }

    static function onExitLabelText(context:CompileContext):Void {
        var position = SlicePosition.fromExitEvent(context.events, context.index);
        lastMedia(context).labelId0 = position.start.index;
        lastMedia(context).labelId1 = position.end.index;
    }

    static function onExitLineEnding(context:CompileContext):Void {
        if (context.rawTextInside) {
            context.push(' ');
        }
        else if (context.slurpOneLineEnding
            // Ignore line endings after definitions.
            || (context.index > 1
                && (context.events[context.index - 2].name == Name.Definition
                    || context.events[context.index - 2].name == Name.GfmFootnoteDefinition))) {
            context.slurpOneLineEnding = false;
        }
        else {
            context.push(Encode.encode(exitSlice(context).asStr(), context.encodeHtml));
        }
    }

    static function onExitList(context:CompileContext):Void {
        context.tightStack.pop();
        context.lineEnding();
        context.push(context.events[context.index].name == Name.ListOrdered ? '</ol>' : '</ul>');
    }

    static function onExitListItem(context:CompileContext):Void {
        var tight = tight(context);
        var beforeItem = Skip.optBack(context.events, context.index - 1, [
            Name.BlankLineEnding,
            Name.BlockQuotePrefix,
            Name.LineEnding,
            Name.SpaceOrTab,
            // Also ignore things that don't contribute to the document.
            Name.Definition,
            Name.GfmFootnoteDefinition,
        ]);
        var previous = context.events[beforeItem];
        var tightParagraph = tight && previous.name == Name.Paragraph;
        var emptyItem = previous.name == Name.ListItemPrefix;

        context.slurpOneLineEnding = false;

        if (!tightParagraph && !emptyItem) {
            context.lineEndingIfNeeded();
        }

        context.push('</li>');
    }

    static function onExitListItemValue(context:CompileContext):Void {
        if (context.listExpectFirstMarker == 1) {
            var slice = exitSlice(context);
            var value = Std.parseInt(slice.asStr());

            if (value != 1) {
                context.push(' start="');
                context.push(Std.string(value));
                context.push('"');
            }
        }
    }

    static function onExitMedia(context:CompileContext):Void {
        var isInImage = false;
        var index = 0;

        // Skip current.
        var end = context.mediaStack.length - 1;
        while (index < end) {
            if (context.mediaStack[index].image) {
                isInImage = true;
                break;
            }
            index += 1;
        }

        context.imageAltInside = isInImage;

        var media = context.mediaStack.pop();
        var label = media.label;
        var id:Null<String> = null;
        if (media.referenceId0 != -1)
            id = NormalizeIdentifier.normalizeIdentifier(Slice.fromIndices(context.bytes, media.referenceId0, media.referenceId1).asStr());
        else if (media.labelId0 != -1)
            id = NormalizeIdentifier.normalizeIdentifier(Slice.fromIndices(context.bytes, media.labelId0, media.labelId1).asStr());

        var definitionIndex = -1;
        if (media.destination == null && id != null) {
            var index = 0;
            while (index < context.definitions.length && context.definitions[index].id != id) {
                index += 1;
            }
            definitionIndex = index;
        }

        if (!isInImage) {
            if (media.image) {
                context.push('<img src="');
            }
            else {
                context.push('<a href="');
            }

            var destination = definitionIndex != -1 ? context.definitions[definitionIndex].destination : media.destination;

            if (destination != null) {
                var allowDangerousProtocol = context.options.allowDangerousProtocol || (context.options.allowAnyImgSrc && media.image);

                var url = allowDangerousProtocol
                    ? SanitizeUri.sanitize(destination)
                    : SanitizeUri.sanitizeWithProtocols(destination, media.image ? Constant.SAFE_PROTOCOL_SRC : Constant.SAFE_PROTOCOL_HREF);
                context.push(url);
            }

            if (media.image) {
                context.push('" alt="');
            }
        }

        if (media.image) {
            context.push(label);
        }

        if (!isInImage) {
            context.push('"');

            var title = definitionIndex != -1 ? context.definitions[definitionIndex].title : media.title;

            if (title != null) {
                context.push(' title="');
                context.push(title);
                context.push('"');
            }

            if (media.image) {
                context.push(' /');
            }

            context.push('>');
        }

        if (!media.image) {
            context.push(label);

            if (!isInImage) {
                context.push('</a>');
            }
        }
    }

    static function onExitParagraph(context:CompileContext):Void {
        if (tight(context)) {
            context.slurpOneLineEnding = true;
        }
        else {
            context.push('</p>');
        }
    }

    static function onExitReferenceString(context:CompileContext):Void {
        // Drop stuff.
        context.resume();
        var position = SlicePosition.fromExitEvent(context.events, context.index);
        lastMedia(context).referenceId0 = position.start.index;
        lastMedia(context).referenceId1 = position.end.index;
    }

    static function onExitResourceDestinationString(context:CompileContext):Void {
        var buf = context.resume();
        lastMedia(context).destination = buf;
        context.encodeHtml = true;
    }

    static function onExitResourceTitleString(context:CompileContext):Void {
        var buf = context.resume();
        lastMedia(context).title = buf;
    }

    static function onExitStrong(context:CompileContext):Void {
        if (!context.imageAltInside) {
            context.push('</strong>');
        }
    }

    static function onExitThematicBreak(context:CompileContext):Void {
        context.lineEndingIfNeeded();
        context.push('<hr />');
    }

    static function clobberPrefix(context:CompileContext):String {
        return context.options.gfmFootnoteClobberPrefix != null ? Encode.encode(context.options.gfmFootnoteClobberPrefix, context.encodeHtml) : 'user-content-';
    }

    /** Generate a footnote section. */
    static function generateFootnoteSection(context:CompileContext):Void {
        context.lineEndingIfNeeded();
        context.push('<section data-footnotes="" class="footnotes"><');
        if (context.options.gfmFootnoteLabelTagName != null) {
            context.push(Encode.encode(context.options.gfmFootnoteLabelTagName, context.encodeHtml));
        }
        else {
            context.push('h2');
        }
        context.push(' id="footnote-label" ');
        if (context.options.gfmFootnoteLabelAttributes != null) {
            context.push(context.options.gfmFootnoteLabelAttributes);
        }
        else {
            context.push('class="sr-only"');
        }
        context.push('>');
        if (context.options.gfmFootnoteLabel != null) {
            context.push(Encode.encode(context.options.gfmFootnoteLabel, context.encodeHtml));
        }
        else {
            context.push('Footnotes');
        }
        context.push('</');
        if (context.options.gfmFootnoteLabelTagName != null) {
            context.push(Encode.encode(context.options.gfmFootnoteLabelTagName, context.encodeHtml));
        }
        else {
            context.push('h2');
        }
        context.push('>');
        context.lineEnding();
        context.push('<ol>');

        var index = 0;
        while (index < context.gfmFootnoteDefinitionCallIds.length) {
            generateFootnoteItem(context, index);
            index += 1;
        }

        context.lineEnding();
        context.push('</ol>');
        context.lineEnding();
        context.push('</section>');
        context.lineEnding();
    }

    /** Generate a footnote item from a call. */
    static function generateFootnoteItem(context:CompileContext, index:Int):Void {
        var id = context.gfmFootnoteDefinitionCallIds[index];
        var safeId = SanitizeUri.sanitize(CaseMap.lowercase(id));

        // Find definition: we'll always find it.
        var definitionIndex = 0;
        while (definitionIndex < context.gfmFootnoteDefinitions.length) {
            if (context.gfmFootnoteDefinitions[definitionIndex][0] == id) {
                break;
            }
            definitionIndex += 1;
        }

        // Start listing item.
        context.lineEnding();
        context.push('<li id="');
        context.push(clobberPrefix(context));
        context.push('fn-');
        context.push(safeId);
        context.push('">');
        context.lineEnding();

        // Create one or more backreferences.
        var referenceIndex = 0;
        var backreferences = new StringBuf();
        while (referenceIndex < context.gfmFootnoteDefinitionCallCounts[index]) {
            if (referenceIndex != 0) {
                backreferences.add(' ');
            }
            backreferences.add('<a href="#');
            backreferences.add(clobberPrefix(context));
            backreferences.add('fnref-');
            backreferences.add(safeId);
            if (referenceIndex != 0) {
                backreferences.add('-');
                backreferences.add(Std.string(referenceIndex + 1));
            }
            backreferences.add('" data-footnote-backref="" aria-label="');
            if (context.options.gfmFootnoteBackLabel != null) {
                backreferences.add(Encode.encode(context.options.gfmFootnoteBackLabel, context.encodeHtml));
            }
            else {
                backreferences.add('Back to content');
            }
            backreferences.add('" class="data-footnote-backref">\u{21A9}');
            if (referenceIndex != 0) {
                backreferences.add('<sup>');
                backreferences.add(Std.string(referenceIndex + 1));
                backreferences.add('</sup>');
            }
            backreferences.add('</a>');

            referenceIndex += 1;
        }
        var backreferences = backreferences.toString();

        var value = context.gfmFootnoteDefinitions[definitionIndex][1];
        var byteIndex = value.length;
        // Move back past EOL.
        while (byteIndex > 0 && (StringTools.fastCodeAt(value, byteIndex - 1) == '\n'.code || StringTools.fastCodeAt(value, byteIndex - 1) == '\r'.code)) {
            byteIndex -= 1;
        }
        // Check if it ends in `</p>`.
        // This is a bit funky if someone wrote a safe paragraph by hand in
        // there.
        // But in all other cases, `<` and `>` would be encoded, so we can be
        // sure that this is generated by our compiler.
        if (byteIndex > 3 && value.substr(byteIndex - 4, 4) == '</p>') {
            context.push(value.substring(0, byteIndex - 4) + ' ' + backreferences + value.substring(byteIndex - 4));
        }
        else {
            context.push(value);
            context.lineEndingIfNeeded();
            context.push(backreferences);
        }

        context.lineEndingIfNeeded();
        context.push('</li>');
    }

    /** Generate an autolink (used by unicode autolinks and GFM autolink literals). */
    static function generateAutolink(context:CompileContext, protocol:Null<String>, value:String, isGfmLiteral:Bool):Void {
        var isInLink = false;
        var index = 0;

        while (index < context.mediaStack.length) {
            if (!context.mediaStack[index].image) {
                isInLink = true;
                break;
            }
            index += 1;
        }

        if (!context.imageAltInside && (!isInLink || !isGfmLiteral)) {
            context.push('<a href="');
            var url = protocol != null ? protocol + value : value;

            var url = context.options.allowDangerousProtocol
                ? SanitizeUri.sanitize(url)
                : SanitizeUri.sanitizeWithProtocols(url, Constant.SAFE_PROTOCOL_HREF);

            context.push(url);
            context.push('">');
        }

        context.push(Encode.encode(value, context.encodeHtml));

        if (!context.imageAltInside && (!isInLink || !isGfmLiteral)) {
            context.push('</a>');
        }
    }

}

private typedef Utf8Helper = markdown.util.Utf8;
