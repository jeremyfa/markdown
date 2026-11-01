// Ported from markdown 1.0.0: src/to_mdast.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown;

import haxe.io.Bytes;
import markdown.event.Event;
import markdown.event.Kind;
import markdown.event.Name;
import markdown.mdast.AlignKind;
import markdown.mdast.Node;
import markdown.message.Message;
import markdown.message.Place;
import markdown.unist.Point;
import markdown.unist.Position;
import markdown.util.CaseMap;
import markdown.util.CharacterReference;
import markdown.util.Infer;
import markdown.util.MdxCollect;
import markdown.util.NormalizeIdentifier;
import markdown.util.Slice;
import markdown.util.Utf8;

/** A reference to something (`Reference`). */
private class Reference {
    /** `null` when this is a resource. */
    public var referenceKind:Null<ReferenceKind> = ReferenceKind.Shortcut;
    public var identifier:String = '';
    public var label:String = '';

    public function new() {}
}

/** Info on a tag (`JsxTag`). */
private class JsxTag {
    public var name:Null<String> = null;
    public var attributes:Array<AttributeContent> = [];
    public var close:Bool = false;
    public var selfClosing:Bool = false;
    public var start:Point;
    public var end:Point;

    public function new(start:Point, end:Point) {
        this.start = start;
        this.end = end;
    }

    public function clone():JsxTag {
        var tag = new JsxTag(start.clone(), end.clone());
        tag.name = name;
        tag.attributes = attributes.copy();
        tag.close = close;
        tag.selfClosing = selfClosing;
        return tag;
    }
}

/** A tree being built, with the path to its tail and the opening events. */
private class Tree {
    public var node:Node;
    public var stack:Array<Int> = [];
    public var eventStack:Array<Int> = [];

    public function new(node:Node) {
        this.node = node;
    }
}

/** Context used to compile markdown (`CompileContext`). */
private class CompileContext {
    public var events:Array<Event>;
    public var bytes:Bytes;
    public var characterReferenceMarker:Int = 0;
    public var gfmTableInside:Bool = false;
    public var hardBreakAfter:Bool = false;
    public var headingSetextTextAfter:Bool = false;
    public var jsxTagStack:Array<JsxTag> = [];
    public var jsxTag:Null<JsxTag> = null;
    public var mediaReferenceStack:Array<Reference> = [];
    public var rawFlowFenceSeen:Bool = false;
    public var trees:Array<Tree>;
    public var index:Int = 0;

    public function new(events:Array<Event>, bytes:Bytes) {
        this.events = events;
        this.bytes = bytes;
        var tree = Node.Root(new markdown.mdast.Node.Root([], new Position(
            events.length == 0 ? new Point(1, 1, 0) : events[0].point.toUnist(),
            events.length == 0 ? new Point(1, 1, 0) : events[events.length - 1].point.toUnist()
        )));
        this.trees = [new Tree(tree)];
    }

    /** Push a buffer. */
    public function buffer():Void {
        trees.push(new Tree(Node.Paragraph(new markdown.mdast.Node.Paragraph([], null))));
    }

    /** Pop a buffer, returning its value. */
    public function resume():Node {
        return trees.pop().node;
    }

    public function tailMut():Node {
        var tree = trees[trees.length - 1];
        return ToMdast.delveMut(tree.node, tree.stack, tree.stack.length);
    }

    public function tailPenultimateMut():Node {
        var tree = trees[trees.length - 1];
        return ToMdast.delveMut(tree.node, tree.stack, tree.stack.length - 1);
    }

    public function tailPush(child:Node):Void {
        if (child.position() == null) {
            child.positionSet(ToMdast.positionFromEvent(events[index]));
        }

        var tree = trees[trees.length - 1];
        var node = ToMdast.delveMut(tree.node, tree.stack, tree.stack.length);
        var children = node.children();
        var index = children.length;
        children.push(child);
        tree.stack.push(index);
        tree.eventStack.push(this.index);
    }

    public function tailPushAgain():Void {
        var tree = trees[trees.length - 1];
        var node = ToMdast.delveMut(tree.node, tree.stack, tree.stack.length);
        var children = node.children();
        tree.stack.push(children.length - 1);
        tree.eventStack.push(index);
    }

    /** Throws a `Message` on error. */
    public function tailPop():Void {
        var ev = events[index];
        var end = ev.point.toUnist();
        var tree = trees[trees.length - 1];
        var node = ToMdast.delveMut(tree.node, tree.stack, tree.stack.length);
        var pos = node.position();
        pos.end = end;

        tree.stack.pop();
        var leftIndex = tree.eventStack.pop();
        var left = events[leftIndex];
        if (left.name != ev.name) {
            ToMdast.onMismatchError(this, ev, left);
        }
    }
}

/**
 * Turn events and bytes into a syntax tree (`to_mdast.rs`).
 */
class ToMdast {

    /** Turn events and bytes into a syntax tree. Throws a `Message` on error. */
    public static function compile(events:Array<Event>, bytes:Bytes):Node {
        var context = new CompileContext(events, bytes);

        var index = 0;
        while (index < events.length) {
            handle(context, index);
            index += 1;
        }

        var tree = context.trees.pop();

        if (tree.eventStack.length > 0) {
            var event = events[tree.eventStack[tree.eventStack.length - 1]];
            onMismatchError(context, null, event);
        }

        return tree.node;
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
            case Name.AutolinkEmail | Name.AutolinkProtocol | Name.CharacterEscapeValue | Name.CharacterReference | Name.CodeFlowChunk
                | Name.CodeTextData | Name.Data | Name.FrontmatterChunk | Name.HtmlFlowData | Name.HtmlTextData | Name.MathFlowChunk
                | Name.MathTextData | Name.MdxJsxTagAttributeValueLiteralValue:
                onEnterData(context);
            case Name.CodeFencedFenceInfo | Name.CodeFencedFenceMeta | Name.DefinitionDestinationString | Name.DefinitionLabelString
                | Name.DefinitionTitleString | Name.GfmFootnoteDefinitionLabelString | Name.LabelText | Name.MathFlowFenceMeta
                | Name.MdxJsxTagAttributeValueLiteral | Name.ReferenceString | Name.ResourceDestinationString | Name.ResourceTitleString:
                onEnterBuffer(context);
            case Name.Autolink: onEnterAutolink(context);
            case Name.BlockQuote: onEnterBlockQuote(context);
            case Name.CodeFenced: onEnterCodeFenced(context);
            case Name.CodeIndented: onEnterCodeIndented(context);
            case Name.CodeText: onEnterCodeText(context);
            case Name.Definition: onEnterDefinition(context);
            case Name.Emphasis: onEnterEmphasis(context);
            case Name.Frontmatter: onEnterFrontmatter(context);
            case Name.GfmAutolinkLiteralEmail | Name.GfmAutolinkLiteralMailto | Name.GfmAutolinkLiteralProtocol | Name.GfmAutolinkLiteralWww
                | Name.GfmAutolinkLiteralXmpp:
                onEnterGfmAutolinkLiteral(context);
            case Name.GfmFootnoteCall: onEnterGfmFootnoteCall(context);
            case Name.GfmFootnoteDefinition: onEnterGfmFootnoteDefinition(context);
            case Name.GfmStrikethrough: onEnterGfmStrikethrough(context);
            case Name.GfmTable: onEnterGfmTable(context);
            case Name.GfmTableRow: onEnterGfmTableRow(context);
            case Name.GfmTableCell: onEnterGfmTableCell(context);
            case Name.HardBreakEscape | Name.HardBreakTrailing: onEnterHardBreak(context);
            case Name.HeadingAtx | Name.HeadingSetext: onEnterHeading(context);
            case Name.HtmlFlow | Name.HtmlText: onEnterHtml(context);
            case Name.Image: onEnterImage(context);
            case Name.Link: onEnterLink(context);
            case Name.ListItem: onEnterListItem(context);
            case Name.ListOrdered | Name.ListUnordered: onEnterList(context);
            case Name.MathFlow: onEnterMathFlow(context);
            case Name.MathText: onEnterMathText(context);
            case Name.MdxEsm: onEnterMdxEsm(context);
            case Name.MdxFlowExpression: onEnterMdxFlowExpression(context);
            case Name.MdxTextExpression: onEnterMdxTextExpression(context);
            case Name.MdxJsxFlowTag | Name.MdxJsxTextTag: onEnterMdxJsxTag(context);
            case Name.MdxJsxTagClosingMarker: onEnterMdxJsxTagClosingMarker(context);
            case Name.MdxJsxTagAttribute: onEnterMdxJsxTagAttribute(context);
            case Name.MdxJsxTagAttributeExpression: onEnterMdxJsxTagAttributeExpression(context);
            case Name.MdxJsxTagAttributeValueExpression: onEnterMdxJsxTagAttributeValueExpression(context);
            case Name.MdxJsxTagSelfClosingMarker: onEnterMdxJsxTagSelfClosingMarker(context);
            case Name.Paragraph: onEnterParagraph(context);
            case Name.Reference: onEnterReference(context);
            case Name.Resource: onEnterResource(context);
            case Name.Strong: onEnterStrong(context);
            case Name.ThematicBreak: onEnterThematicBreak(context);
            default:
        }
    }

    /** Handle [`Exit`][Kind::Exit]. */
    static function exit(context:CompileContext):Void {
        switch context.events[context.index].name {
            case Name.Autolink | Name.BlockQuote | Name.CharacterReference | Name.Definition | Name.Emphasis | Name.GfmFootnoteDefinition
                | Name.GfmStrikethrough | Name.GfmTableRow | Name.GfmTableCell | Name.HeadingAtx | Name.ListOrdered | Name.ListUnordered
                | Name.Paragraph | Name.Strong | Name.ThematicBreak:
                onExit(context);
            case Name.CharacterEscapeValue | Name.CodeFlowChunk | Name.CodeTextData | Name.Data | Name.FrontmatterChunk | Name.HtmlFlowData
                | Name.HtmlTextData | Name.MathFlowChunk | Name.MathTextData | Name.MdxJsxTagAttributeValueLiteralValue:
                onExitData(context);
            case Name.MdxJsxTagAttributeExpression | Name.MdxJsxTagAttributeValueExpression:
                onExitDrop(context);
            case Name.AutolinkProtocol: onExitAutolinkProtocol(context);
            case Name.AutolinkEmail: onExitAutolinkEmail(context);
            case Name.CharacterReferenceMarker: onExitCharacterReferenceMarker(context);
            case Name.CharacterReferenceMarkerNumeric: onExitCharacterReferenceMarkerNumeric(context);
            case Name.CharacterReferenceMarkerHexadecimal: onExitCharacterReferenceMarkerHexadecimal(context);
            case Name.CharacterReferenceValue: onExitCharacterReferenceValue(context);
            case Name.CodeFencedFenceInfo: onExitCodeFencedFenceInfo(context);
            case Name.CodeFencedFenceMeta | Name.MathFlowFenceMeta: onExitRawFlowFenceMeta(context);
            case Name.CodeFencedFence | Name.MathFlowFence: onExitRawFlowFence(context);
            case Name.CodeFenced | Name.MathFlow: onExitRawFlow(context);
            case Name.CodeIndented: onExitCodeIndented(context);
            case Name.CodeText | Name.MathText: onExitRawText(context);
            case Name.DefinitionDestinationString: onExitDefinitionDestinationString(context);
            case Name.DefinitionLabelString | Name.GfmFootnoteDefinitionLabelString: onExitDefinitionId(context);
            case Name.DefinitionTitleString: onExitDefinitionTitleString(context);
            case Name.Frontmatter: onExitFrontmatter(context);
            case Name.GfmAutolinkLiteralEmail | Name.GfmAutolinkLiteralMailto | Name.GfmAutolinkLiteralProtocol | Name.GfmAutolinkLiteralWww
                | Name.GfmAutolinkLiteralXmpp:
                onExitGfmAutolinkLiteral(context);
            case Name.GfmFootnoteCall | Name.Image | Name.Link: onExitMedia(context);
            case Name.GfmTable: onExitGfmTable(context);
            case Name.GfmTaskListItemValueUnchecked | Name.GfmTaskListItemValueChecked: onExitGfmTaskListItemValue(context);
            case Name.HardBreakEscape | Name.HardBreakTrailing: onExitHardBreak(context);
            case Name.HeadingAtxSequence: onExitHeadingAtxSequence(context);
            case Name.HeadingSetext: onExitHeadingSetext(context);
            case Name.HeadingSetextUnderlineSequence: onExitHeadingSetextUnderlineSequence(context);
            case Name.HeadingSetextText: onExitHeadingSetextText(context);
            case Name.HtmlFlow | Name.HtmlText: onExitHtml(context);
            case Name.LabelText: onExitLabelText(context);
            case Name.LineEnding: onExitLineEnding(context);
            case Name.ListItem: onExitListItem(context);
            case Name.ListItemValue: onExitListItemValue(context);
            case Name.MdxEsm | Name.MdxFlowExpression | Name.MdxTextExpression: onExitMdxEsmOrExpression(context);
            case Name.MdxJsxFlowTag | Name.MdxJsxTextTag: onExitMdxJsxTag(context);
            case Name.MdxJsxTagClosingMarker: onExitMdxJsxTagClosingMarker(context);
            case Name.MdxJsxTagNamePrimary: onExitMdxJsxTagNamePrimary(context);
            case Name.MdxJsxTagNameMember: onExitMdxJsxTagNameMember(context);
            case Name.MdxJsxTagNameLocal: onExitMdxJsxTagNameLocal(context);
            case Name.MdxJsxTagAttributePrimaryName: onExitMdxJsxTagAttributePrimaryName(context);
            case Name.MdxJsxTagAttributeNameLocal: onExitMdxJsxTagAttributeNameLocal(context);
            case Name.MdxJsxTagAttributeValueLiteral: onExitMdxJsxTagAttributeValueLiteral(context);
            case Name.MdxJsxTagSelfClosingMarker: onExitMdxJsxTagSelfClosingMarker(context);
            case Name.ReferenceString: onExitReferenceString(context);
            case Name.ResourceDestinationString: onExitResourceDestinationString(context);
            case Name.ResourceTitleString: onExitResourceTitleString(context);
            default:
        }
    }

    static inline function exitSlice(context:CompileContext):Slice {
        return Slice.fromPosition(context.bytes, SlicePosition.fromExitEvent(context.events, context.index));
    }

    static inline function lastReference(context:CompileContext):Reference {
        return context.mediaReferenceStack[context.mediaReferenceStack.length - 1];
    }

    static function onEnterBuffer(context:CompileContext):Void {
        context.buffer();
    }

    static function onEnterData(context:CompileContext):Void {
        var parent = context.tailMut();
        var children = parent.children();
        var last = children.length > 0 ? children[children.length - 1] : null;
        var isText = last != null && switch last {
            case Text(_): true;
            default: false;
        };
        if (isText) {
            context.tailPushAgain();
        }
        else {
            context.tailPush(Text(new markdown.mdast.Node.Text('', null)));
        }
    }

    static function onEnterAutolink(context:CompileContext):Void {
        context.tailPush(Link(new markdown.mdast.Node.Link([], null, '', null)));
    }

    static function onEnterBlockQuote(context:CompileContext):Void {
        context.tailPush(Blockquote(new markdown.mdast.Node.Blockquote([], null)));
    }

    static function onEnterCodeFenced(context:CompileContext):Void {
        context.tailPush(Code(new markdown.mdast.Node.Code('', null, null, null)));
    }

    static function onEnterCodeIndented(context:CompileContext):Void {
        onEnterCodeFenced(context);
        onEnterBuffer(context);
    }

    static function onEnterCodeText(context:CompileContext):Void {
        context.tailPush(InlineCode(new markdown.mdast.Node.InlineCode('', null)));
        context.buffer();
    }

    static function onEnterMathText(context:CompileContext):Void {
        context.tailPush(InlineMath(new markdown.mdast.Node.InlineMath('', null)));
        context.buffer();
    }

    static function onEnterMdxEsm(context:CompileContext):Void {
        var result = MdxCollect.collect(context.events, context.bytes, context.index, [Name.MdxEsmData, Name.LineEnding], [Name.MdxEsm]);
        context.tailPush(MdxjsEsm(new markdown.mdast.Node.MdxjsEsm(result.value, null, pairs(result.stops))));
        context.buffer();
    }

    static function onEnterMdxFlowExpression(context:CompileContext):Void {
        var result = MdxCollect.collect(context.events, context.bytes, context.index, [Name.MdxExpressionData, Name.LineEnding], [Name.MdxFlowExpression]);
        context.tailPush(MdxFlowExpression(new markdown.mdast.Node.MdxFlowExpression(result.value, null, pairs(result.stops))));
        context.buffer();
    }

    static function onEnterMdxTextExpression(context:CompileContext):Void {
        var result = MdxCollect.collect(context.events, context.bytes, context.index, [Name.MdxExpressionData, Name.LineEnding], [Name.MdxTextExpression]);
        context.tailPush(MdxTextExpression(new markdown.mdast.Node.MdxTextExpression(result.value, null, pairs(result.stops))));
        context.buffer();
    }

    static function onEnterDefinition(context:CompileContext):Void {
        context.tailPush(Definition(new markdown.mdast.Node.Definition(null, '', null, '', null)));
    }

    static function onEnterEmphasis(context:CompileContext):Void {
        context.tailPush(Emphasis(new markdown.mdast.Node.Emphasis([], null)));
    }

    static function onEnterGfmAutolinkLiteral(context:CompileContext):Void {
        onEnterAutolink(context);
        onEnterData(context);
    }

    static function onEnterGfmFootnoteCall(context:CompileContext):Void {
        context.tailPush(FootnoteReference(new markdown.mdast.Node.FootnoteReference(null, '', null)));
        context.mediaReferenceStack.push(new Reference());
    }

    static function onEnterGfmFootnoteDefinition(context:CompileContext):Void {
        context.tailPush(FootnoteDefinition(new markdown.mdast.Node.FootnoteDefinition([], null, '', null)));
    }

    static function onEnterGfmStrikethrough(context:CompileContext):Void {
        context.tailPush(Delete(new markdown.mdast.Node.Delete([], null)));
    }

    static function onEnterGfmTable(context:CompileContext):Void {
        var align = Infer.gfmTableAlign(context.events, context.index);
        context.tailPush(Table(new markdown.mdast.Node.Table([], null, align)));
        context.gfmTableInside = true;
    }

    static function onEnterGfmTableRow(context:CompileContext):Void {
        context.tailPush(TableRow(new markdown.mdast.Node.TableRow([], null)));
    }

    static function onEnterGfmTableCell(context:CompileContext):Void {
        context.tailPush(TableCell(new markdown.mdast.Node.TableCell([], null)));
    }

    static function onEnterHardBreak(context:CompileContext):Void {
        context.tailPush(Break(new markdown.mdast.Node.Break(null)));
    }

    static function onEnterFrontmatter(context:CompileContext):Void {
        var index = context.events[context.index].point.index;
        var byte = context.bytes.get(index);
        var node = byte == '+'.code ? Toml(new markdown.mdast.Node.Toml('', null)) : Yaml(new markdown.mdast.Node.Yaml('', null));

        context.tailPush(node);
        context.buffer();
    }

    static function onEnterReference(context:CompileContext):Void {
        lastReference(context).referenceKind = ReferenceKind.Collapsed;
    }

    static function onEnterResource(context:CompileContext):Void {
        lastReference(context).referenceKind = null;
    }

    static function onEnterStrong(context:CompileContext):Void {
        context.tailPush(Strong(new markdown.mdast.Node.Strong([], null)));
    }

    static function onEnterThematicBreak(context:CompileContext):Void {
        context.tailPush(ThematicBreak(new markdown.mdast.Node.ThematicBreak(null)));
    }

    static function onEnterHeading(context:CompileContext):Void {
        context.tailPush(Heading(new markdown.mdast.Node.Heading([], null, 0)));
    }

    static function onEnterHtml(context:CompileContext):Void {
        context.tailPush(Html(new markdown.mdast.Node.Html('', null)));
        context.buffer();
    }

    static function onEnterImage(context:CompileContext):Void {
        context.tailPush(Image(new markdown.mdast.Node.Image(null, '', '', null)));
        context.mediaReferenceStack.push(new Reference());
    }

    static function onEnterLink(context:CompileContext):Void {
        context.tailPush(Link(new markdown.mdast.Node.Link([], null, '', null)));
        context.mediaReferenceStack.push(new Reference());
    }

    static function onEnterList(context:CompileContext):Void {
        var ordered = context.events[context.index].name == Name.ListOrdered;
        var spread = Infer.listLoose(context.events, context.index, false);

        context.tailPush(List(new markdown.mdast.Node.List([], null, ordered, null, spread)));
    }

    static function onEnterListItem(context:CompileContext):Void {
        var spread = Infer.listItemLoose(context.events, context.index);

        context.tailPush(ListItem(new markdown.mdast.Node.ListItem([], null, spread, null)));
    }

    static function onEnterMathFlow(context:CompileContext):Void {
        context.tailPush(Math(new markdown.mdast.Node.Math('', null, null)));
    }

    static function onEnterMdxJsxTag(context:CompileContext):Void {
        var point = context.events[context.index].point.toUnist();
        context.jsxTag = new JsxTag(point.clone(), point);
        context.buffer();
    }

    static function onEnterMdxJsxTagClosingMarker(context:CompileContext):Void {
        if (context.jsxTagStack.length == 0) {
            var event = context.events[context.index];
            throw new Message(Place.Point(event.point.toUnist()), 'Unexpected closing slash `/` in tag, expected an open tag first',
                'unexpected-closing-slash', 'markdown-rs');
        }
    }

    static function onEnterMdxJsxTagAnyAttribute(context:CompileContext):Void {
        if (context.jsxTag.close) {
            var event = context.events[context.index];
            throw new Message(Place.Point(event.point.toUnist()), 'Unexpected attribute in closing tag, expected the end of the tag',
                'unexpected-attribute', 'markdown-rs');
        }
    }

    static function onEnterMdxJsxTagAttribute(context:CompileContext):Void {
        onEnterMdxJsxTagAnyAttribute(context);

        context.jsxTag.attributes.push(AttributeContent.Property(new MdxJsxAttribute('', null)));
    }

    static function onEnterMdxJsxTagAttributeExpression(context:CompileContext):Void {
        onEnterMdxJsxTagAnyAttribute(context);

        var result = MdxCollect.collect(context.events, context.bytes, context.index, [Name.MdxExpressionData, Name.LineEnding], [Name.MdxJsxTagAttributeExpression]);
        context.jsxTag.attributes.push(AttributeContent.Expression(new MdxJsxExpressionAttribute(result.value, pairs(result.stops))));
        context.buffer();
    }

    static function onEnterMdxJsxTagAttributeValueExpression(context:CompileContext):Void {
        var result = MdxCollect.collect(context.events, context.bytes, context.index, [Name.MdxExpressionData, Name.LineEnding], [Name.MdxJsxTagAttributeValueExpression]);

        switch context.jsxTag.attributes[context.jsxTag.attributes.length - 1] {
            case Property(node):
                node.value = AttributeValue.Expression(new AttributeValueExpression(result.value, pairs(result.stops)));
            default:
                throw 'expected property';
        }

        context.buffer();
    }

    static function onEnterMdxJsxTagSelfClosingMarker(context:CompileContext):Void {
        if (context.jsxTag.close) {
            var event = context.events[context.index];
            throw new Message(Place.Point(event.point.toUnist()), 'Unexpected self-closing slash `/` in closing tag, expected the end of the tag',
                'unexpected-self-closing-slash', 'markdown-rs');
        }
    }

    static function onEnterParagraph(context:CompileContext):Void {
        context.tailPush(Paragraph(new markdown.mdast.Node.Paragraph([], null)));
    }

    static function onExit(context:CompileContext):Void {
        context.tailPop();
    }

    static function onExitAutolinkProtocol(context:CompileContext):Void {
        onExitData(context);
        var value = exitSlice(context);
        switch context.tailMut() {
            case Link(link): link.url += value.asStr();
            default: throw 'expected link on stack';
        }
    }

    static function onExitAutolinkEmail(context:CompileContext):Void {
        onExitData(context);
        var value = exitSlice(context);
        switch context.tailMut() {
            case Link(link): link.url += 'mailto:' + value.asStr();
            default: throw 'expected link on stack';
        }
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
        var slice = exitSlice(context);
        var value = markdown.util.CharacterReference.decode(slice.asStr(), context.characterReferenceMarker, true);

        switch context.tailMut() {
            case Text(node): node.value += value;
            default: throw 'expected text on stack';
        }

        context.characterReferenceMarker = 0;
    }

    static function onExitCodeFencedFenceInfo(context:CompileContext):Void {
        var value = context.resume().toString();
        switch context.tailMut() {
            case Code(node): node.lang = value;
            default: throw 'expected code on stack';
        }
    }

    static function onExitRawFlowFenceMeta(context:CompileContext):Void {
        var value = context.resume().toString();
        switch context.tailMut() {
            case Code(node): node.meta = value;
            case Math(node): node.meta = value;
            default: throw 'expected code or math on stack';
        }
    }

    static function onExitRawFlowFence(context:CompileContext):Void {
        if (context.rawFlowFenceSeen) {
            // Second fence, ignore.
        }
        else {
            context.buffer();
            context.rawFlowFenceSeen = true;
        }
    }

    static function onExitRawFlow(context:CompileContext):Void {
        var value = trimEol(context.resume().toString(), true, true);

        switch context.tailMut() {
            case Code(node): node.value = value;
            case Math(node): node.value = value;
            default: throw 'expected code or math on stack for value';
        }

        onExit(context);
        context.rawFlowFenceSeen = false;
    }

    static function onExitCodeIndented(context:CompileContext):Void {
        var value = context.resume().toString();

        switch context.tailMut() {
            case Code(node): node.value = trimEol(value, false, true);
            default: throw 'expected code on stack for value';
        }

        onExit(context);
        context.rawFlowFenceSeen = false;
    }

    static function onExitRawText(context:CompileContext):Void {
        var value = context.resume().toString();

        // To do: share with `to_html`.
        // If we are in a GFM table, we need to decode escaped pipes.
        // This is a rather weird GFM feature.
        if (context.gfmTableInside && value.indexOf('\\|') != -1) {
            var b = new StringBuf();
            var index = 0;
            var len = value.length;
            while (index < len) {
                var c = StringTools.fastCodeAt(value, index);
                if (index + 1 < len && c == '\\'.code && StringTools.fastCodeAt(value, index + 1) == '|'.code) {
                    b.addChar('|'.code);
                    index += 2;
                    continue;
                }
                b.addChar(c);
                index += 1;
            }
            value = b.toString();
        }

        var len = value.length;
        if (len > 2 && StringTools.fastCodeAt(value, 0) == ' '.code && StringTools.fastCodeAt(value, len - 1) == ' '.code && !allSpaces(value)) {
            value = value.substring(1, len - 1);
        }

        switch context.tailMut() {
            case InlineCode(node): node.value = value;
            case InlineMath(node): node.value = value;
            default: throw 'expected inline code or math on stack for value';
        }

        onExit(context);
    }

    static function allSpaces(value:String):Bool {
        for (i in 0...value.length)
            if (StringTools.fastCodeAt(value, i) != ' '.code)
                return false;
        return true;
    }

    static function onExitData(context:CompileContext):Void {
        var value = exitSlice(context);

        switch context.tailMut() {
            case Text(text): text.value += value.asStr();
            default: throw 'expected text on stack';
        }

        onExit(context);
    }

    static function onExitDefinitionDestinationString(context:CompileContext):Void {
        var value = context.resume().toString();
        switch context.tailMut() {
            case Definition(node): node.url = value;
            default: throw 'expected definition on stack';
        }
    }

    static function onExitDefinitionId(context:CompileContext):Void {
        var label = context.resume().toString();
        var slice = exitSlice(context);
        var identifier = CaseMap.lowercase(NormalizeIdentifier.normalizeIdentifier(slice.asStr()));

        switch context.tailMut() {
            case Definition(node):
                node.label = label;
                node.identifier = identifier;
            case FootnoteDefinition(node):
                node.label = label;
                node.identifier = identifier;
            default:
                throw 'expected definition or footnote definition on stack';
        }
    }

    static function onExitDefinitionTitleString(context:CompileContext):Void {
        var value = context.resume().toString();
        switch context.tailMut() {
            case Definition(node): node.title = value;
            default: throw 'expected definition on stack';
        }
    }

    static function onExitDrop(context:CompileContext):Void {
        context.resume();
    }

    static function onExitFrontmatter(context:CompileContext):Void {
        var value = trimEol(context.resume().toString(), true, true);

        switch context.tailMut() {
            case Yaml(node): node.value = value;
            case Toml(node): node.value = value;
            default: throw 'expected yaml/toml on stack for value';
        }

        onExit(context);
    }

    static function onExitGfmAutolinkLiteral(context:CompileContext):Void {
        onExitData(context);

        var value = exitSlice(context);

        var prefix = switch context.events[context.index].name {
            case Name.GfmAutolinkLiteralEmail: 'mailto:';
            case Name.GfmAutolinkLiteralWww: 'http://';
            default: null;
        };

        switch context.tailMut() {
            case Link(link):
                if (prefix != null) {
                    link.url += prefix;
                }
                link.url += value.asStr();
            default:
                throw 'expected link on stack';
        }

        onExit(context);
    }

    static function onExitGfmTable(context:CompileContext):Void {
        onExit(context);
        context.gfmTableInside = false;
    }

    static function onExitGfmTaskListItemValue(context:CompileContext):Void {
        var checked = context.events[context.index].name == Name.GfmTaskListItemValueChecked;
        switch context.tailPenultimateMut() {
            case ListItem(node): node.checked = checked;
            default: throw 'expected list item on stack';
        }
    }

    static function onExitHardBreak(context:CompileContext):Void {
        onExit(context);
        context.hardBreakAfter = true;
    }

    static function onExitHeadingAtxSequence(context:CompileContext):Void {
        var slice = exitSlice(context);

        switch context.tailMut() {
            case Heading(node):
                if (node.depth == 0) {
                    node.depth = slice.len() & 0xFF;
                }
            default:
                throw 'expected heading on stack';
        }
    }

    static function onExitHeadingSetext(context:CompileContext):Void {
        context.headingSetextTextAfter = false;
        onExit(context);
    }

    static function onExitHeadingSetextText(context:CompileContext):Void {
        context.headingSetextTextAfter = true;
    }

    static function onExitHeadingSetextUnderlineSequence(context:CompileContext):Void {
        var position = SlicePosition.fromExitEvent(context.events, context.index);
        var head = context.bytes.get(position.start.index);
        var depth = head == '-'.code ? 2 : 1;

        switch context.tailMut() {
            case Heading(node): node.depth = depth;
            default: throw 'expected heading on stack';
        }
    }

    static function onExitLabelText(context:CompileContext):Void {
        var fragment = context.resume();
        var label = fragment.toString();
        var children = fragment.children();
        fragment.setChildren([]);
        var slice = exitSlice(context);
        var identifier = CaseMap.lowercase(NormalizeIdentifier.normalizeIdentifier(slice.asStr()));
        var reference = lastReference(context);
        reference.label = label;
        reference.identifier = identifier;

        switch context.tailMut() {
            case Link(node): node.children = children;
            case Image(node): node.alt = label;
            case FootnoteReference(_):
            default: throw 'expected footnote refereence, image, or link on stack';
        }
    }

    static function onExitLineEnding(context:CompileContext):Void {
        if (context.headingSetextTextAfter) {
            // Ignore.
        }
        // Line ending position after hard break is part of it.
        else if (context.hardBreakAfter) {
            var end = context.events[context.index].point.toUnist();
            var node = context.tailMut();
            var children = node.children();
            var tail = children[children.length - 1];
            tail.position().end = end;
            context.hardBreakAfter = false;
        }
        // Line ending is a part of nodes that accept phrasing.
        else if (switch context.tailMut() {
            case Emphasis(_) | Heading(_) | Paragraph(_) | Strong(_) | Delete(_): true;
            default: false;
        }) {
            context.index -= 1;
            onEnterData(context);
            context.index += 1;
            onExitData(context);
        }
    }

    static function onExitHtml(context:CompileContext):Void {
        var value = context.resume().toString();

        switch context.tailMut() {
            case Html(node): node.value = value;
            default: throw 'expected html on stack for value';
        }

        onExit(context);
    }

    static function onExitMedia(context:CompileContext):Void {
        var reference = context.mediaReferenceStack.pop();
        onExit(context);

        // It's a reference.
        var kind = reference.referenceKind;
        if (kind != null) {
            var parent = context.tailMut();
            var siblings = parent.children();

            switch siblings[siblings.length - 1] {
                case FootnoteReference(node):
                    node.identifier = reference.identifier;
                    node.label = reference.label;
                case Image(node):
                    siblings.pop();
                    siblings.push(ImageReference(new markdown.mdast.Node.ImageReference(node.position, node.alt, kind, reference.identifier, reference.label)));
                case Link(node):
                    siblings.pop();
                    siblings.push(LinkReference(new markdown.mdast.Node.LinkReference(node.children, node.position, kind, reference.identifier, reference.label)));
                default:
                    throw 'expected footnote reference, image, or link on stack';
            }
        }
    }

    static function onExitListItem(context:CompileContext):Void {
        switch context.tailMut() {
            case ListItem(item):
                if (item.checked != null && item.children.length > 0) {
                    switch item.children[0] {
                        case Paragraph(paragraph):
                            if (paragraph.children.length > 0) {
                                switch paragraph.children[0] {
                                    case Text(text):
                                        var point = text.position.start.clone();
                                        var bytes = Utf8.bytesOf(text.value);
                                        var start = 0;

                                        // Remove initial spacing.
                                        if (bytes.get(0) == '\t'.code || bytes.get(0) == ' '.code) {
                                            point.offset += 1;
                                            point.column += 1;
                                            start += 1;
                                        }
                                        else if (bytes.get(0) == '\r'.code || bytes.get(0) == '\n'.code) {
                                            point.line += 1;
                                            point.column = 1;
                                            point.offset += 1;
                                            start += 1;
                                            // Move past the LF of CRLF.
                                            if (bytes.length > 1 && bytes.get(0) == '\r'.code && bytes.get(1) == '\n'.code) {
                                                point.offset += 1;
                                                start += 1;
                                            }
                                        }

                                        // The whole text is whitespace: update the text.
                                        if (start == bytes.length) {
                                            paragraph.children.shift();
                                        }
                                        else {
                                            text.value = Utf8.slice(bytes, start, bytes.length);
                                            text.position.start = point.clone();
                                        }
                                        paragraph.position.start = point;
                                    default:
                                }
                            }
                        default:
                    }
                }
            default:
        }

        onExit(context);
    }

    static function onExitListItemValue(context:CompileContext):Void {
        var start = Std.parseInt(exitSlice(context).asStr());

        switch context.tailPenultimateMut() {
            case List(node):
                if (node.start == null) {
                    node.start = start;
                }
            default:
                throw 'expected list on stack';
        }
    }

    static function onExitMdxJsxTag(context:CompileContext):Void {
        var tag = context.jsxTag.clone();
        context.resume();
        tag.end = context.events[context.index].point.toUnist();
        var stack = context.jsxTagStack;
        var tail = stack.length > 0 ? stack[stack.length - 1] : null;

        if (tag.close) {
            // Unwrap: we crashed earlier if there's nothing on the stack.
            if (tail.name != tag.name) {
                var label = serializeAbbreviatedTag(tag);
                throw new Message(Place.Position(new Position(tag.start, tag.end)),
                    'Unexpected closing tag `' + label + '`, expected corresponding closing tag for `' + serializeAbbreviatedTag(tail) + '` ('
                    + tail.start.line + ':' + tail.start.column + ')',
                    'end-tag-mismatch', 'markdown-rs');
            }

            // Remove from our custom stack.
            // Note that this does not exit the node.
            context.jsxTagStack.pop();
        }
        else {
            var node = context.events[context.index].name == Name.MdxJsxFlowTag
                ? MdxJsxFlowElement(new markdown.mdast.Node.MdxJsxFlowElement([], new Position(tag.start.clone(), tag.end.clone()), tag.name, tag.attributes.copy()))
                : MdxJsxTextElement(new markdown.mdast.Node.MdxJsxTextElement([], new Position(tag.start.clone(), tag.end.clone()), tag.name, tag.attributes.copy()));

            context.tailPush(node);
        }

        if (tag.selfClosing || tag.close) {
            context.tailPop();
        }
        else {
            context.jsxTagStack.push(tag);
        }
    }

    static function onExitMdxJsxTagClosingMarker(context:CompileContext):Void {
        context.jsxTag.close = true;
    }

    static function onExitMdxJsxTagNamePrimary(context:CompileContext):Void {
        context.jsxTag.name = exitSlice(context).serialize();
    }

    static function onExitMdxJsxTagNameMember(context:CompileContext):Void {
        context.jsxTag.name += '.' + exitSlice(context).asStr();
    }

    static function onExitMdxJsxTagNameLocal(context:CompileContext):Void {
        context.jsxTag.name += ':' + exitSlice(context).asStr();
    }

    static function onExitMdxEsmOrExpression(context:CompileContext):Void {
        onExitDrop(context);
        context.tailPop();
    }

    static function onExitMdxJsxTagAttributePrimaryName(context:CompileContext):Void {
        var value = exitSlice(context).serialize();
        switch context.jsxTag.attributes[context.jsxTag.attributes.length - 1] {
            case Property(attribute): attribute.name = value;
            default: throw 'expected property';
        }
    }

    static function onExitMdxJsxTagAttributeNameLocal(context:CompileContext):Void {
        var slice = exitSlice(context);
        switch context.jsxTag.attributes[context.jsxTag.attributes.length - 1] {
            case Property(attribute): attribute.name += ':' + slice.asStr();
            default: throw 'expected property';
        }
    }

    static function onExitMdxJsxTagAttributeValueLiteral(context:CompileContext):Void {
        var value = context.resume();

        switch context.jsxTag.attributes[context.jsxTag.attributes.length - 1] {
            case Property(node): node.value = AttributeValue.Literal(markdown.util.CharacterReference.parse(value.toString()));
            default: throw 'expected property';
        }
    }

    static function onExitMdxJsxTagSelfClosingMarker(context:CompileContext):Void {
        context.jsxTag.selfClosing = true;
    }

    static function onExitReferenceString(context:CompileContext):Void {
        var label = context.resume().toString();
        var slice = exitSlice(context);
        var identifier = CaseMap.lowercase(NormalizeIdentifier.normalizeIdentifier(slice.asStr()));
        var reference = lastReference(context);
        reference.referenceKind = ReferenceKind.Full;
        reference.label = label;
        reference.identifier = identifier;
    }

    static function onExitResourceDestinationString(context:CompileContext):Void {
        var value = context.resume().toString();

        switch context.tailMut() {
            case Link(node): node.url = value;
            case Image(node): node.url = value;
            default: throw 'expected link, image on stack';
        }
    }

    static function onExitResourceTitleString(context:CompileContext):Void {
        var value = context.resume().toString();

        switch context.tailMut() {
            case Link(node): node.title = value;
            case Image(node): node.title = value;
            default: throw 'expected link, image on stack';
        }
    }

    /** Create a position from an event. */
    public static function positionFromEvent(event:Event):Position {
        var end = new Point(event.point.line, event.point.column, event.point.index);
        return new Position(end.clone(), end);
    }

    /** Resolve the current stack on the tree. */
    public static function delveMut(node:Node, stack:Array<Int>, count:Int):Node {
        var stackIndex = 0;
        while (stackIndex < count) {
            var index = stack[stackIndex];
            node = node.children()[index];
            stackIndex += 1;
        }
        return node;
    }

    /** Pairs of relative and absolute offsets. */
    static function pairs(stops:Array<Int>):Array<Array<Int>> {
        var result = [];
        var i = 0;
        while (i < stops.length) {
            result.push([stops[i], stops[i + 1]]);
            i += 2;
        }
        return result;
    }

    /** Remove initial/final EOLs. */
    static function trimEol(value:String, atStart:Bool, atEnd:Bool):String {
        var len = value.length;
        var start = 0;
        var end = len;

        if (atStart && len > 0) {
            var c = StringTools.fastCodeAt(value, 0);
            if (c == '\n'.code) {
                start += 1;
            }
            else if (c == '\r'.code) {
                start += 1;
                if (len > 1 && StringTools.fastCodeAt(value, 1) == '\n'.code) {
                    start += 1;
                }
            }
        }

        if (atEnd && end > start) {
            if (StringTools.fastCodeAt(value, end - 1) == '\n'.code) {
                end -= 1;
                if (end > start && StringTools.fastCodeAt(value, end - 1) == '\r'.code) {
                    end -= 1;
                }
            }
            else if (StringTools.fastCodeAt(value, end - 1) == '\r'.code) {
                end -= 1;
            }
        }

        if (start > 0 || end < len) {
            return value.substring(start, end);
        }
        else {
            return value;
        }
    }

    /** Handle a mismatch. Throws a `Message`. */
    public static function onMismatchError(context:CompileContext, left:Null<Event>, right:Event):Void {
        if (right.name == Name.MdxJsxFlowTag || right.name == Name.MdxJsxTextTag) {
            var stack = context.jsxTagStack;
            var tag = stack[stack.length - 1];
            var point = left != null ? left.point : context.events[context.events.length - 1].point;

            throw new Message(Place.Point(point.toUnist()),
                'Expected a closing tag for `' + serializeAbbreviatedTag(tag) + '` (' + tag.start.line + ':' + tag.start.column + ')'
                + (left != null ? ' before the end of `' + left.name.toString() + '`' : ''),
                'end-tag-mismatch', 'markdown-rs');
        }

        if (left != null) {
            if (left.name == Name.MdxJsxFlowTag || left.name == Name.MdxJsxTextTag) {
                var tag = context.jsxTag;

                throw new Message(Place.Point(tag.start.clone()),
                    'Expected the closing tag `' + serializeAbbreviatedTag(tag) + '` either before the start of `' + right.name.toString()
                    + '` (' + right.point.line + ':' + right.point.column + '), or another opening tag after that start',
                    'end-tag-mismatch', 'markdown-rs');
            }
            throw 'mismatched (non-jsx): ' + left.name.toString() + ' / ' + right.name.toString();
        }
        else {
            throw 'mismatched (non-jsx): document / ' + right.name.toString();
        }
    }

    /** Format a JSX tag, ignoring its attributes. */
    static function serializeAbbreviatedTag(tag:JsxTag):String {
        return '<' + (tag.close ? '/' : '') + (tag.name != null ? tag.name : '') + '>';
    }

}
