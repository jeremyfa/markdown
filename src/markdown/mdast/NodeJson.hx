// Ported from markdown 1.0.0: src/mdast.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.mdast;

import markdown.mdast.Node;
import markdown.unist.Point;
import markdown.unist.Position;
import markdown.util.Json;

/**
 * JSON serialization of mdast nodes, with exactly the output of serde_json
 * for `markdown::mdast::Node` (feature `serde`): same keys, same key order,
 * same escaping. `fromJson` reads it back (serde `Deserialize`).
 */
class NodeJson {

    /** Serialize a node, compact (`serde_json::to_string`) or pretty (`serde_json::to_string_pretty`). */
    public static function toJson(node:Node, pretty:Bool = false):String {
        var b = new StringBuf();
        write(b, node);
        var s = b.toString();
        return pretty ? Json.pretty(s) : s;
    }

    static function writePosition(b:StringBuf, p:Position):Void {
        b.add('{"start":');
        writePoint(b, p.start);
        b.add(',"end":');
        writePoint(b, p.end);
        b.add('}');
    }

    static function writePoint(b:StringBuf, p:Point):Void {
        b.add('{"line":');
        b.add(p.line);
        b.add(',"column":');
        b.add(p.column);
        b.add(',"offset":');
        b.add(p.offset);
        b.add('}');
    }

    static function writeChildren(b:StringBuf, children:Array<Node>):Void {
        b.add('[');
        for (i in 0...children.length) {
            if (i > 0) b.add(',');
            write(b, children[i]);
        }
        b.add(']');
    }

    static function writeStops(b:StringBuf, stops:Array<Array<Int>>):Void {
        b.add('[');
        for (i in 0...stops.length) {
            if (i > 0) b.add(',');
            b.add('[' + stops[i][0] + ',' + stops[i][1] + ']');
        }
        b.add(']');
    }

    static function writeAttributes(b:StringBuf, attributes:Array<AttributeContent>):Void {
        b.add('[');
        for (i in 0...attributes.length) {
            if (i > 0) b.add(',');
            switch attributes[i] {
                case Expression(a):
                    b.add('{"type":"mdxJsxExpressionAttribute","value":');
                    Json.addQuoted(b, a.value);
                    b.add(',"_markdownRsStops":');
                    writeStops(b, a.stops);
                    b.add('}');
                case Property(a):
                    b.add('{"type":"mdxJsxAttribute","name":');
                    Json.addQuoted(b, a.name);
                    if (a.value != null) {
                        b.add(',"value":');
                        switch a.value {
                            case Expression(v):
                                b.add('{"type":"mdxJsxAttributeValueExpression","value":');
                                Json.addQuoted(b, v.value);
                                b.add(',"_markdownRsStops":');
                                writeStops(b, v.stops);
                                b.add('}');
                            case Literal(v):
                                Json.addQuoted(b, v);
                        }
                    }
                    b.add('}');
            }
        }
        b.add(']');
    }

    static function write(b:StringBuf, node:Node):Void {
        switch node {
            case Root(x):
                b.add('{"type":"root"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add('}');
            case Blockquote(x):
                b.add('{"type":"blockquote"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add('}');
            case FootnoteDefinition(x):
                b.add('{"type":"footnoteDefinition"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add(',"identifier":');
                Json.addQuoted(b, x.identifier);
                if (x.label != null) {
                    b.add(',"label":');
                    Json.addQuoted(b, x.label);
                }
                b.add('}');
            case MdxJsxFlowElement(x):
                b.add('{"type":"mdxJsxFlowElement"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                if (x.name != null) {
                    b.add(',"name":');
                    Json.addQuoted(b, x.name);
                }
                b.add(',"attributes":');
                writeAttributes(b, x.attributes);
                b.add('}');
            case List(x):
                b.add('{"type":"list"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add(',"ordered":');
                b.add(x.ordered);
                if (x.start != null) {
                    b.add(',"start":');
                    b.add(x.start);
                }
                b.add(',"spread":');
                b.add(x.spread);
                b.add('}');
            case MdxjsEsm(x):
                b.add('{"type":"mdxjsEsm"');
                b.add(',"value":');
                Json.addQuoted(b, x.value);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add(',"_markdownRsStops":');
                writeStops(b, x.stops);
                b.add('}');
            case Toml(x):
                b.add('{"type":"toml"');
                b.add(',"value":');
                Json.addQuoted(b, x.value);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add('}');
            case Yaml(x):
                b.add('{"type":"yaml"');
                b.add(',"value":');
                Json.addQuoted(b, x.value);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add('}');
            case Break(x):
                b.add('{"type":"break"');
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add('}');
            case InlineCode(x):
                b.add('{"type":"inlineCode"');
                b.add(',"value":');
                Json.addQuoted(b, x.value);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add('}');
            case InlineMath(x):
                b.add('{"type":"inlineMath"');
                b.add(',"value":');
                Json.addQuoted(b, x.value);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add('}');
            case Delete(x):
                b.add('{"type":"delete"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add('}');
            case Emphasis(x):
                b.add('{"type":"emphasis"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add('}');
            case MdxTextExpression(x):
                b.add('{"type":"mdxTextExpression"');
                b.add(',"value":');
                Json.addQuoted(b, x.value);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add(',"_markdownRsStops":');
                writeStops(b, x.stops);
                b.add('}');
            case FootnoteReference(x):
                b.add('{"type":"footnoteReference"');
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add(',"identifier":');
                Json.addQuoted(b, x.identifier);
                if (x.label != null) {
                    b.add(',"label":');
                    Json.addQuoted(b, x.label);
                }
                b.add('}');
            case Html(x):
                b.add('{"type":"html"');
                b.add(',"value":');
                Json.addQuoted(b, x.value);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add('}');
            case Image(x):
                b.add('{"type":"image"');
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add(',"alt":');
                Json.addQuoted(b, x.alt);
                b.add(',"url":');
                Json.addQuoted(b, x.url);
                if (x.title != null) {
                    b.add(',"title":');
                    Json.addQuoted(b, x.title);
                }
                b.add('}');
            case ImageReference(x):
                b.add('{"type":"imageReference"');
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add(',"alt":');
                Json.addQuoted(b, x.alt);
                b.add(',"referenceType":');
                b.add(x.referenceKind.toJson());
                b.add(',"identifier":');
                Json.addQuoted(b, x.identifier);
                if (x.label != null) {
                    b.add(',"label":');
                    Json.addQuoted(b, x.label);
                }
                b.add('}');
            case MdxJsxTextElement(x):
                b.add('{"type":"mdxJsxTextElement"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                if (x.name != null) {
                    b.add(',"name":');
                    Json.addQuoted(b, x.name);
                }
                b.add(',"attributes":');
                writeAttributes(b, x.attributes);
                b.add('}');
            case Link(x):
                b.add('{"type":"link"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add(',"url":');
                Json.addQuoted(b, x.url);
                if (x.title != null) {
                    b.add(',"title":');
                    Json.addQuoted(b, x.title);
                }
                b.add('}');
            case LinkReference(x):
                b.add('{"type":"linkReference"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add(',"referenceType":');
                b.add(x.referenceKind.toJson());
                b.add(',"identifier":');
                Json.addQuoted(b, x.identifier);
                if (x.label != null) {
                    b.add(',"label":');
                    Json.addQuoted(b, x.label);
                }
                b.add('}');
            case Strong(x):
                b.add('{"type":"strong"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add('}');
            case Text(x):
                b.add('{"type":"text"');
                b.add(',"value":');
                Json.addQuoted(b, x.value);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add('}');
            case Code(x):
                b.add('{"type":"code"');
                b.add(',"value":');
                Json.addQuoted(b, x.value);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                if (x.lang != null) {
                    b.add(',"lang":');
                    Json.addQuoted(b, x.lang);
                }
                if (x.meta != null) {
                    b.add(',"meta":');
                    Json.addQuoted(b, x.meta);
                }
                b.add('}');
            case Math(x):
                b.add('{"type":"math"');
                b.add(',"value":');
                Json.addQuoted(b, x.value);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                if (x.meta != null) {
                    b.add(',"meta":');
                    Json.addQuoted(b, x.meta);
                }
                b.add('}');
            case MdxFlowExpression(x):
                b.add('{"type":"mdxFlowExpression"');
                b.add(',"value":');
                Json.addQuoted(b, x.value);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add(',"_markdownRsStops":');
                writeStops(b, x.stops);
                b.add('}');
            case Heading(x):
                b.add('{"type":"heading"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add(',"depth":');
                b.add(x.depth);
                b.add('}');
            case Table(x):
                b.add('{"type":"table"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add(',"align":');
                b.add('[' + [for (a in x.align) a.toJson()].join(',') + ']');
                b.add('}');
            case ThematicBreak(x):
                b.add('{"type":"thematicBreak"');
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add('}');
            case TableRow(x):
                b.add('{"type":"tableRow"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add('}');
            case TableCell(x):
                b.add('{"type":"tableCell"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add('}');
            case ListItem(x):
                b.add('{"type":"listItem"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add(',"spread":');
                b.add(x.spread);
                if (x.checked != null) {
                    b.add(',"checked":');
                    b.add(x.checked);
                }
                b.add('}');
            case Definition(x):
                b.add('{"type":"definition"');
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add(',"url":');
                Json.addQuoted(b, x.url);
                if (x.title != null) {
                    b.add(',"title":');
                    Json.addQuoted(b, x.title);
                }
                b.add(',"identifier":');
                Json.addQuoted(b, x.identifier);
                if (x.label != null) {
                    b.add(',"label":');
                    Json.addQuoted(b, x.label);
                }
                b.add('}');
            case Paragraph(x):
                b.add('{"type":"paragraph"');
                b.add(',"children":');
                writeChildren(b, x.children);
                if (x.position != null) {
                    b.add(',"position":');
                    writePosition(b, x.position);
                }
                b.add('}');
        }
    }

    /** Read a node from JSON (serde `Deserialize`). Throws on invalid input. */
    public static function fromJson(json:String):Node {
        return fromDynamic(haxe.Json.parse(json));
    }

    static function pos(v:Dynamic):Null<Position> {
        var p:Dynamic = Reflect.field(v, 'position');
        if (p == null) return null;
        return new Position(new Point(p.start.line, p.start.column, p.start.offset), new Point(p.end.line, p.end.column, p.end.offset));
    }

    static function kids(v:Dynamic):Array<Node> {
        var c:Array<Dynamic> = Reflect.field(v, 'children');
        return [for (x in c) fromDynamic(x)];
    }

    static function stops(v:Dynamic):Array<Array<Int>> {
        var s:Array<Array<Int>> = Reflect.field(v, '_markdownRsStops');
        return [for (x in s) [x[0], x[1]]];
    }

    static function refKind(v:Dynamic):ReferenceKind {
        return switch (Reflect.field(v, 'referenceType'):String) {
            case 'shortcut': Shortcut;
            case 'collapsed': Collapsed;
            case 'full': Full;
            default: throw 'invalid reference type';
        }
    }

    static function align(v:Dynamic):Array<AlignKind> {
        var a:Array<Dynamic> = Reflect.field(v, 'align');
        return [for (x in a) x == null ? AlignKind.None : x == 'left' ? AlignKind.Left : x == 'right' ? AlignKind.Right : x == 'center' ? AlignKind.Center : throw 'invalid align'];
    }

    static function attributes(v:Dynamic):Array<AttributeContent> {
        var a:Array<Dynamic> = Reflect.field(v, 'attributes');
        var result = [];
        for (x in a) {
            if (x.type == 'mdxJsxExpressionAttribute') {
                result.push(AttributeContent.Expression(new MdxJsxExpressionAttribute(x.value, stops(x))));
            }
            else {
                var value:Dynamic = Reflect.field(x, 'value');
                var attrValue:Null<AttributeValue> = null;
                if (value != null) {
                    attrValue = Std.isOfType(value, String) ? AttributeValue.Literal(value) : AttributeValue.Expression(new AttributeValueExpression(value.value, stops(value)));
                }
                result.push(AttributeContent.Property(new MdxJsxAttribute(x.name, attrValue)));
            }
        }
        return result;
    }

    static function fromDynamic(v:Dynamic):Node {
        return switch (Reflect.field(v, 'type'):String) {
            case 'root': Root(new Root(kids(v), pos(v)));
            case 'blockquote': Blockquote(new Blockquote(kids(v), pos(v)));
            case 'footnoteDefinition': FootnoteDefinition(new FootnoteDefinition(kids(v), pos(v), Reflect.field(v, 'identifier'), Reflect.field(v, 'label')));
            case 'mdxJsxFlowElement': MdxJsxFlowElement(new MdxJsxFlowElement(kids(v), pos(v), Reflect.field(v, 'name'), attributes(v)));
            case 'list': List(new List(kids(v), pos(v), Reflect.field(v, 'ordered'), Reflect.field(v, 'start'), Reflect.field(v, 'spread')));
            case 'mdxjsEsm': MdxjsEsm(new MdxjsEsm(Reflect.field(v, 'value'), pos(v), stops(v)));
            case 'toml': Toml(new Toml(Reflect.field(v, 'value'), pos(v)));
            case 'yaml': Yaml(new Yaml(Reflect.field(v, 'value'), pos(v)));
            case 'break': Break(new Break(pos(v)));
            case 'inlineCode': InlineCode(new InlineCode(Reflect.field(v, 'value'), pos(v)));
            case 'inlineMath': InlineMath(new InlineMath(Reflect.field(v, 'value'), pos(v)));
            case 'delete': Delete(new Delete(kids(v), pos(v)));
            case 'emphasis': Emphasis(new Emphasis(kids(v), pos(v)));
            case 'mdxTextExpression': MdxTextExpression(new MdxTextExpression(Reflect.field(v, 'value'), pos(v), stops(v)));
            case 'footnoteReference': FootnoteReference(new FootnoteReference(pos(v), Reflect.field(v, 'identifier'), Reflect.field(v, 'label')));
            case 'html': Html(new Html(Reflect.field(v, 'value'), pos(v)));
            case 'image': Image(new Image(pos(v), Reflect.field(v, 'alt'), Reflect.field(v, 'url'), Reflect.field(v, 'title')));
            case 'imageReference': ImageReference(new ImageReference(pos(v), Reflect.field(v, 'alt'), refKind(v), Reflect.field(v, 'identifier'), Reflect.field(v, 'label')));
            case 'mdxJsxTextElement': MdxJsxTextElement(new MdxJsxTextElement(kids(v), pos(v), Reflect.field(v, 'name'), attributes(v)));
            case 'link': Link(new Link(kids(v), pos(v), Reflect.field(v, 'url'), Reflect.field(v, 'title')));
            case 'linkReference': LinkReference(new LinkReference(kids(v), pos(v), refKind(v), Reflect.field(v, 'identifier'), Reflect.field(v, 'label')));
            case 'strong': Strong(new Strong(kids(v), pos(v)));
            case 'text': Text(new Text(Reflect.field(v, 'value'), pos(v)));
            case 'code': Code(new Code(Reflect.field(v, 'value'), pos(v), Reflect.field(v, 'lang'), Reflect.field(v, 'meta')));
            case 'math': Math(new Math(Reflect.field(v, 'value'), pos(v), Reflect.field(v, 'meta')));
            case 'mdxFlowExpression': MdxFlowExpression(new MdxFlowExpression(Reflect.field(v, 'value'), pos(v), stops(v)));
            case 'heading': Heading(new Heading(kids(v), pos(v), Reflect.field(v, 'depth')));
            case 'table': Table(new Table(kids(v), pos(v), align(v)));
            case 'thematicBreak': ThematicBreak(new ThematicBreak(pos(v)));
            case 'tableRow': TableRow(new TableRow(kids(v), pos(v)));
            case 'tableCell': TableCell(new TableCell(kids(v), pos(v)));
            case 'listItem': ListItem(new ListItem(kids(v), pos(v), Reflect.field(v, 'spread'), Reflect.field(v, 'checked')));
            case 'definition': Definition(new Definition(pos(v), Reflect.field(v, 'url'), Reflect.field(v, 'title'), Reflect.field(v, 'identifier'), Reflect.field(v, 'label')));
            case 'paragraph': Paragraph(new Paragraph(kids(v), pos(v)));
            default: throw 'invalid node type';
        }
    }

}
