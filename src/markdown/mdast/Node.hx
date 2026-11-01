// Ported from markdown 1.0.0: src/mdast.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.mdast;

/**
 * Nodes of the mdast syntax tree (`Node` in `mdast.rs`).
 *
 * Each constructor wraps a class with the fields of the node. Methods
 * (`children`, `position`, `toString`...) are in `NodeTools`; serialization
 * to JSON (same output as serde_json) is in `NodeJson`.
 */
@:using(markdown.mdast.NodeTools)
enum Node {
    /** Document. */
    Root(node:Root);
    /** Block quote. */
    Blockquote(node:Blockquote);
    /** GFM: footnote definition. */
    FootnoteDefinition(node:FootnoteDefinition);
    /** MDX: JSX element (container). */
    MdxJsxFlowElement(node:MdxJsxFlowElement);
    /** List. */
    List(node:List);
    /** MDX: ESM. */
    MdxjsEsm(node:MdxjsEsm);
    /** Frontmatter: toml. */
    Toml(node:Toml);
    /** Frontmatter: yaml. */
    Yaml(node:Yaml);
    /** Break. */
    Break(node:Break);
    /** Code (phrasing). */
    InlineCode(node:InlineCode);
    /** Math (phrasing). */
    InlineMath(node:InlineMath);
    /** GFM: delete. */
    Delete(node:Delete);
    /** Emphasis. */
    Emphasis(node:Emphasis);
    /** MDX: expression (text). */
    MdxTextExpression(node:MdxTextExpression);
    /** GFM: footnote reference. */
    FootnoteReference(node:FootnoteReference);
    /** HTML. */
    Html(node:Html);
    /** Image. */
    Image(node:Image);
    /** Image reference. */
    ImageReference(node:ImageReference);
    /** MDX: JSX element (text). */
    MdxJsxTextElement(node:MdxJsxTextElement);
    /** Link. */
    Link(node:Link);
    /** Link reference. */
    LinkReference(node:LinkReference);
    /** Strong. */
    Strong(node:Strong);
    /** Text. */
    Text(node:Text);
    /** Code (flow). */
    Code(node:Code);
    /** Math (flow). */
    Math(node:Math);
    /** MDX: expression (flow). */
    MdxFlowExpression(node:MdxFlowExpression);
    /** Heading. */
    Heading(node:Heading);
    /** GFM: table. */
    Table(node:Table);
    /** Thematic break. */
    ThematicBreak(node:ThematicBreak);
    /** GFM: table row. */
    TableRow(node:TableRow);
    /** GFM: table cell. */
    TableCell(node:TableCell);
    /** List item. */
    ListItem(node:ListItem);
    /** Definition. */
    Definition(node:Definition);
    /** Paragraph. */
    Paragraph(node:Paragraph);
}

/** Explicitness of a reference (`ReferenceKind`). */
enum abstract ReferenceKind(Int) {
    /** The reference is implicit, its identifier inferred from its content. */
    var Shortcut = 0;
    /** The reference is explicit, its identifier inferred from its content. */
    var Collapsed = 1;
    /** The reference is explicit, its identifier explicitly set. */
    var Full = 2;

    public function toJson():String {
        return switch (cast this : ReferenceKind) {
            case Shortcut: '"shortcut"';
            case Collapsed: '"collapsed"';
            case Full: '"full"';
        }
    }
}

/** MDX: attribute content (`AttributeContent`). */
enum AttributeContent {
    /** JSX expression: `{...a}`. */
    Expression(attribute:MdxJsxExpressionAttribute);
    /** JSX property: `key="value"`. */
    Property(attribute:MdxJsxAttribute);
}

/** MDX: attribute value (`AttributeValue`). */
enum AttributeValue {
    /** Expression value: `{1 + 1}`. */
    Expression(value:AttributeValueExpression);
    /** Static value: `"a"`. */
    Literal(value:String);
}

/** MDX: attribute value expression (`AttributeValueExpression`). */
class AttributeValueExpression {
    public var value:String;
    /** Pairs of relative and absolute offsets. */
    public var stops:Array<Array<Int>>;

    public function new(value:String, stops:Array<Array<Int>>) {
        this.value = value;
        this.stops = stops;
    }
}

/** MDX: JSX attribute (`MdxJsxAttribute`). */
class MdxJsxAttribute {
    public var name:String;
    public var value:Null<AttributeValue>;

    public function new(name:String, value:Null<AttributeValue>) {
        this.name = name;
        this.value = value;
    }
}

/** MDX: JSX expression attribute (`MdxJsxExpressionAttribute`). */
class MdxJsxExpressionAttribute {
    public var value:String;
    /** Pairs of relative and absolute offsets. */
    public var stops:Array<Array<Int>>;

    public function new(value:String, stops:Array<Array<Int>>) {
        this.value = value;
        this.stops = stops;
    }
}

/** Document (`Root`). */
class Root {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>) {
        this.children = children;
        this.position = position;
    }
}

/** Block quote (`Blockquote`). */
class Blockquote {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>) {
        this.children = children;
        this.position = position;
    }
}

/** GFM: footnote definition (`FootnoteDefinition`). */
class FootnoteDefinition {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;
    public var identifier:String;
    public var label:Null<String>;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>, identifier:String, label:Null<String>) {
        this.children = children;
        this.position = position;
        this.identifier = identifier;
        this.label = label;
    }
}

/** MDX: JSX element (container) (`MdxJsxFlowElement`). */
class MdxJsxFlowElement {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;
    public var name:Null<String>;
    public var attributes:Array<AttributeContent>;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>, name:Null<String>, attributes:Array<AttributeContent>) {
        this.children = children;
        this.position = position;
        this.name = name;
        this.attributes = attributes;
    }
}

/** List (`List`). */
class List {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;
    public var ordered:Bool;
    public var start:Null<Int>;
    public var spread:Bool;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>, ordered:Bool, start:Null<Int>, spread:Bool) {
        this.children = children;
        this.position = position;
        this.ordered = ordered;
        this.start = start;
        this.spread = spread;
    }
}

/** MDX: ESM (`MdxjsEsm`). */
class MdxjsEsm {
    public var value:String;
    public var position:Null<markdown.unist.Position>;
    public var stops:Array<Array<Int>>;

    public function new(value:String, position:Null<markdown.unist.Position>, stops:Array<Array<Int>>) {
        this.value = value;
        this.position = position;
        this.stops = stops;
    }
}

/** Frontmatter: toml (`Toml`). */
class Toml {
    public var value:String;
    public var position:Null<markdown.unist.Position>;

    public function new(value:String, position:Null<markdown.unist.Position>) {
        this.value = value;
        this.position = position;
    }
}

/** Frontmatter: yaml (`Yaml`). */
class Yaml {
    public var value:String;
    public var position:Null<markdown.unist.Position>;

    public function new(value:String, position:Null<markdown.unist.Position>) {
        this.value = value;
        this.position = position;
    }
}

/** Break (`Break`). */
class Break {
    public var position:Null<markdown.unist.Position>;

    public function new(position:Null<markdown.unist.Position>) {
        this.position = position;
    }
}

/** Code (phrasing) (`InlineCode`). */
class InlineCode {
    public var value:String;
    public var position:Null<markdown.unist.Position>;

    public function new(value:String, position:Null<markdown.unist.Position>) {
        this.value = value;
        this.position = position;
    }
}

/** Math (phrasing) (`InlineMath`). */
class InlineMath {
    public var value:String;
    public var position:Null<markdown.unist.Position>;

    public function new(value:String, position:Null<markdown.unist.Position>) {
        this.value = value;
        this.position = position;
    }
}

/** GFM: delete (`Delete`). */
class Delete {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>) {
        this.children = children;
        this.position = position;
    }
}

/** Emphasis (`Emphasis`). */
class Emphasis {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>) {
        this.children = children;
        this.position = position;
    }
}

/** MDX: expression (text) (`MdxTextExpression`). */
class MdxTextExpression {
    public var value:String;
    public var position:Null<markdown.unist.Position>;
    public var stops:Array<Array<Int>>;

    public function new(value:String, position:Null<markdown.unist.Position>, stops:Array<Array<Int>>) {
        this.value = value;
        this.position = position;
        this.stops = stops;
    }
}

/** GFM: footnote reference (`FootnoteReference`). */
class FootnoteReference {
    public var position:Null<markdown.unist.Position>;
    public var identifier:String;
    public var label:Null<String>;

    public function new(position:Null<markdown.unist.Position>, identifier:String, label:Null<String>) {
        this.position = position;
        this.identifier = identifier;
        this.label = label;
    }
}

/** HTML (`Html`). */
class Html {
    public var value:String;
    public var position:Null<markdown.unist.Position>;

    public function new(value:String, position:Null<markdown.unist.Position>) {
        this.value = value;
        this.position = position;
    }
}

/** Image (`Image`). */
class Image {
    public var position:Null<markdown.unist.Position>;
    public var alt:String;
    public var url:String;
    public var title:Null<String>;

    public function new(position:Null<markdown.unist.Position>, alt:String, url:String, title:Null<String>) {
        this.position = position;
        this.alt = alt;
        this.url = url;
        this.title = title;
    }
}

/** Image reference (`ImageReference`). */
class ImageReference {
    public var position:Null<markdown.unist.Position>;
    public var alt:String;
    public var referenceKind:ReferenceKind;
    public var identifier:String;
    public var label:Null<String>;

    public function new(position:Null<markdown.unist.Position>, alt:String, referenceKind:ReferenceKind, identifier:String, label:Null<String>) {
        this.position = position;
        this.alt = alt;
        this.referenceKind = referenceKind;
        this.identifier = identifier;
        this.label = label;
    }
}

/** MDX: JSX element (text) (`MdxJsxTextElement`). */
class MdxJsxTextElement {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;
    public var name:Null<String>;
    public var attributes:Array<AttributeContent>;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>, name:Null<String>, attributes:Array<AttributeContent>) {
        this.children = children;
        this.position = position;
        this.name = name;
        this.attributes = attributes;
    }
}

/** Link (`Link`). */
class Link {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;
    public var url:String;
    public var title:Null<String>;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>, url:String, title:Null<String>) {
        this.children = children;
        this.position = position;
        this.url = url;
        this.title = title;
    }
}

/** Link reference (`LinkReference`). */
class LinkReference {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;
    public var referenceKind:ReferenceKind;
    public var identifier:String;
    public var label:Null<String>;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>, referenceKind:ReferenceKind, identifier:String, label:Null<String>) {
        this.children = children;
        this.position = position;
        this.referenceKind = referenceKind;
        this.identifier = identifier;
        this.label = label;
    }
}

/** Strong (`Strong`). */
class Strong {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>) {
        this.children = children;
        this.position = position;
    }
}

/** Text (`Text`). */
class Text {
    public var value:String;
    public var position:Null<markdown.unist.Position>;

    public function new(value:String, position:Null<markdown.unist.Position>) {
        this.value = value;
        this.position = position;
    }
}

/** Code (flow) (`Code`). */
class Code {
    public var value:String;
    public var position:Null<markdown.unist.Position>;
    public var lang:Null<String>;
    public var meta:Null<String>;

    public function new(value:String, position:Null<markdown.unist.Position>, lang:Null<String>, meta:Null<String>) {
        this.value = value;
        this.position = position;
        this.lang = lang;
        this.meta = meta;
    }
}

/** Math (flow) (`Math`). */
class Math {
    public var value:String;
    public var position:Null<markdown.unist.Position>;
    public var meta:Null<String>;

    public function new(value:String, position:Null<markdown.unist.Position>, meta:Null<String>) {
        this.value = value;
        this.position = position;
        this.meta = meta;
    }
}

/** MDX: expression (flow) (`MdxFlowExpression`). */
class MdxFlowExpression {
    public var value:String;
    public var position:Null<markdown.unist.Position>;
    public var stops:Array<Array<Int>>;

    public function new(value:String, position:Null<markdown.unist.Position>, stops:Array<Array<Int>>) {
        this.value = value;
        this.position = position;
        this.stops = stops;
    }
}

/** Heading (`Heading`). */
class Heading {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;
    public var depth:Int;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>, depth:Int) {
        this.children = children;
        this.position = position;
        this.depth = depth;
    }
}

/** GFM: table (`Table`). */
class Table {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;
    public var align:Array<AlignKind>;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>, align:Array<AlignKind>) {
        this.children = children;
        this.position = position;
        this.align = align;
    }
}

/** Thematic break (`ThematicBreak`). */
class ThematicBreak {
    public var position:Null<markdown.unist.Position>;

    public function new(position:Null<markdown.unist.Position>) {
        this.position = position;
    }
}

/** GFM: table row (`TableRow`). */
class TableRow {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>) {
        this.children = children;
        this.position = position;
    }
}

/** GFM: table cell (`TableCell`). */
class TableCell {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>) {
        this.children = children;
        this.position = position;
    }
}

/** List item (`ListItem`). */
class ListItem {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;
    public var spread:Bool;
    public var checked:Null<Bool>;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>, spread:Bool, checked:Null<Bool>) {
        this.children = children;
        this.position = position;
        this.spread = spread;
        this.checked = checked;
    }
}

/** Definition (`Definition`). */
class Definition {
    public var position:Null<markdown.unist.Position>;
    public var url:String;
    public var title:Null<String>;
    public var identifier:String;
    public var label:Null<String>;

    public function new(position:Null<markdown.unist.Position>, url:String, title:Null<String>, identifier:String, label:Null<String>) {
        this.position = position;
        this.url = url;
        this.title = title;
        this.identifier = identifier;
        this.label = label;
    }
}

/** Paragraph (`Paragraph`). */
class Paragraph {
    public var children:Array<Node>;
    public var position:Null<markdown.unist.Position>;

    public function new(children:Array<Node>, position:Null<markdown.unist.Position>) {
        this.children = children;
        this.position = position;
    }
}
