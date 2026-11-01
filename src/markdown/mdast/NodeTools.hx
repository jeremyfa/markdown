// Ported from markdown 1.0.0: src/mdast.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.mdast;

import markdown.mdast.Node;
import markdown.unist.Position;

/**
 * Methods of `Node` (`impl Node` in `mdast.rs`), attached with `@:using`.
 */
class NodeTools {

    /** Children of a parent node, `null` otherwise. */
    public static function children(node:Node):Null<Array<Node>> {
        return switch node {
            case Root(x): x.children;
            case Blockquote(x): x.children;
            case FootnoteDefinition(x): x.children;
            case MdxJsxFlowElement(x): x.children;
            case List(x): x.children;
            case Delete(x): x.children;
            case Emphasis(x): x.children;
            case MdxJsxTextElement(x): x.children;
            case Link(x): x.children;
            case LinkReference(x): x.children;
            case Strong(x): x.children;
            case Heading(x): x.children;
            case Table(x): x.children;
            case TableRow(x): x.children;
            case TableCell(x): x.children;
            case ListItem(x): x.children;
            case Paragraph(x): x.children;
            default: null;
        }
    }

    /** Replace the children of a parent node (no-op on other nodes). */
    public static function setChildren(node:Node, children:Array<Node>):Void {
        switch node {
            case Root(x): x.children = children;
            case Blockquote(x): x.children = children;
            case FootnoteDefinition(x): x.children = children;
            case MdxJsxFlowElement(x): x.children = children;
            case List(x): x.children = children;
            case Delete(x): x.children = children;
            case Emphasis(x): x.children = children;
            case MdxJsxTextElement(x): x.children = children;
            case Link(x): x.children = children;
            case LinkReference(x): x.children = children;
            case Strong(x): x.children = children;
            case Heading(x): x.children = children;
            case Table(x): x.children = children;
            case TableRow(x): x.children = children;
            case TableCell(x): x.children = children;
            case ListItem(x): x.children = children;
            case Paragraph(x): x.children = children;
            default:
        }
    }

    /** Position of a node. */
    public static function position(node:Node):Null<Position> {
        return switch node {
            case Root(x): x.position;
            case Blockquote(x): x.position;
            case FootnoteDefinition(x): x.position;
            case MdxJsxFlowElement(x): x.position;
            case List(x): x.position;
            case MdxjsEsm(x): x.position;
            case Toml(x): x.position;
            case Yaml(x): x.position;
            case Break(x): x.position;
            case InlineCode(x): x.position;
            case InlineMath(x): x.position;
            case Delete(x): x.position;
            case Emphasis(x): x.position;
            case MdxTextExpression(x): x.position;
            case FootnoteReference(x): x.position;
            case Html(x): x.position;
            case Image(x): x.position;
            case ImageReference(x): x.position;
            case MdxJsxTextElement(x): x.position;
            case Link(x): x.position;
            case LinkReference(x): x.position;
            case Strong(x): x.position;
            case Text(x): x.position;
            case Code(x): x.position;
            case Math(x): x.position;
            case MdxFlowExpression(x): x.position;
            case Heading(x): x.position;
            case Table(x): x.position;
            case ThematicBreak(x): x.position;
            case TableRow(x): x.position;
            case TableCell(x): x.position;
            case ListItem(x): x.position;
            case Definition(x): x.position;
            case Paragraph(x): x.position;
        }
    }

    /** Set the position of a node (`position_set`). */
    public static function positionSet(node:Node, position:Null<Position>):Void {
        switch node {
            case Root(x): x.position = position;
            case Blockquote(x): x.position = position;
            case FootnoteDefinition(x): x.position = position;
            case MdxJsxFlowElement(x): x.position = position;
            case List(x): x.position = position;
            case MdxjsEsm(x): x.position = position;
            case Toml(x): x.position = position;
            case Yaml(x): x.position = position;
            case Break(x): x.position = position;
            case InlineCode(x): x.position = position;
            case InlineMath(x): x.position = position;
            case Delete(x): x.position = position;
            case Emphasis(x): x.position = position;
            case MdxTextExpression(x): x.position = position;
            case FootnoteReference(x): x.position = position;
            case Html(x): x.position = position;
            case Image(x): x.position = position;
            case ImageReference(x): x.position = position;
            case MdxJsxTextElement(x): x.position = position;
            case Link(x): x.position = position;
            case LinkReference(x): x.position = position;
            case Strong(x): x.position = position;
            case Text(x): x.position = position;
            case Code(x): x.position = position;
            case Math(x): x.position = position;
            case MdxFlowExpression(x): x.position = position;
            case Heading(x): x.position = position;
            case Table(x): x.position = position;
            case ThematicBreak(x): x.position = position;
            case TableRow(x): x.position = position;
            case TableCell(x): x.position = position;
            case ListItem(x): x.position = position;
            case Definition(x): x.position = position;
            case Paragraph(x): x.position = position;
        }
    }

    /** Serialize the textual content of a node (`ToString` in `mdast.rs`). */
    public static function toString(node:Node):String {
        return switch node {
            case Root(x): childrenToString(x.children);
            case Blockquote(x): childrenToString(x.children);
            case FootnoteDefinition(x): childrenToString(x.children);
            case MdxJsxFlowElement(x): childrenToString(x.children);
            case List(x): childrenToString(x.children);
            case MdxjsEsm(x): x.value;
            case Toml(x): x.value;
            case Yaml(x): x.value;
            case Break(_): '';
            case InlineCode(x): x.value;
            case InlineMath(x): x.value;
            case Delete(x): childrenToString(x.children);
            case Emphasis(x): childrenToString(x.children);
            case MdxTextExpression(x): x.value;
            case FootnoteReference(_): '';
            case Html(x): x.value;
            case Image(_): '';
            case ImageReference(_): '';
            case MdxJsxTextElement(x): childrenToString(x.children);
            case Link(x): childrenToString(x.children);
            case LinkReference(x): childrenToString(x.children);
            case Strong(x): childrenToString(x.children);
            case Text(x): x.value;
            case Code(x): x.value;
            case Math(x): x.value;
            case MdxFlowExpression(x): x.value;
            case Heading(x): childrenToString(x.children);
            case Table(x): childrenToString(x.children);
            case ThematicBreak(_): '';
            case TableRow(x): childrenToString(x.children);
            case TableCell(x): childrenToString(x.children);
            case ListItem(x): childrenToString(x.children);
            case Definition(_): '';
            case Paragraph(x): childrenToString(x.children);
        }
    }

    static function childrenToString(children:Array<Node>):String {
        var b = new StringBuf();
        for (child in children)
            b.add(toString(child));
        return b.toString();
    }

    /** Deep copy of a node (`Clone`). */
    public static function clone(node:Node):Node {
        return NodeJson.fromJson(NodeJson.toJson(node));
    }

    /** Structural equality (`PartialEq`). */
    public static function equals(a:Node, b:Node):Bool {
        return NodeJson.toJson(a) == NodeJson.toJson(b);
    }

}