// Ported from markdown 1.0.0: src/configuration.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.


package markdown;

/**
 * Control which constructs are enabled (`Constructs` in `configuration.rs`).
 * `new Constructs()` is `Constructs::default()`: CommonMark.
 */
class Constructs {

    public var attention:Bool = true;
    public var autolink:Bool = true;
    public var blockQuote:Bool = true;
    public var characterEscape:Bool = true;
    public var characterReference:Bool = true;
    public var codeIndented:Bool = true;
    public var codeFenced:Bool = true;
    public var codeText:Bool = true;
    public var definition:Bool = true;
    public var frontmatter:Bool = false;
    public var gfmAutolinkLiteral:Bool = false;
    public var gfmFootnoteDefinition:Bool = false;
    public var gfmLabelStartFootnote:Bool = false;
    public var gfmStrikethrough:Bool = false;
    public var gfmTable:Bool = false;
    public var gfmTaskListItem:Bool = false;
    public var hardBreakEscape:Bool = true;
    public var hardBreakTrailing:Bool = true;
    public var headingAtx:Bool = true;
    public var headingSetext:Bool = true;
    public var htmlFlow:Bool = true;
    public var htmlText:Bool = true;
    public var labelStartImage:Bool = true;
    public var labelStartLink:Bool = true;
    public var labelEnd:Bool = true;
    public var listItem:Bool = true;
    public var mathFlow:Bool = false;
    public var mathText:Bool = false;
    public var mdxEsm:Bool = false;
    public var mdxExpressionFlow:Bool = false;
    public var mdxExpressionText:Bool = false;
    public var mdxJsxFlow:Bool = false;
    public var mdxJsxText:Bool = false;
    public var thematicBreak:Bool = true;

    public function new() {}

    /** GFM: CommonMark plus GFM autolink literals, footnotes, strikethrough, tables and task list items. */
    public static function gfm():Constructs {
        var c = new Constructs();
        c.gfmAutolinkLiteral = true;
        c.gfmFootnoteDefinition = true;
        c.gfmLabelStartFootnote = true;
        c.gfmStrikethrough = true;
        c.gfmTable = true;
        c.gfmTaskListItem = true;
        return c;
    }

    /** MDX: CommonMark without autolinks, indented code and HTML, plus the MDX constructs. */
    public static function mdx():Constructs {
        var c = new Constructs();
        c.autolink = false;
        c.codeIndented = false;
        c.htmlFlow = false;
        c.htmlText = false;
        c.mdxEsm = true;
        c.mdxExpressionFlow = true;
        c.mdxExpressionText = true;
        c.mdxJsxFlow = true;
        c.mdxJsxText = true;
        return c;
    }

    public function clone():Constructs {
        var c = new Constructs();
        c.attention = attention;
        c.autolink = autolink;
        c.blockQuote = blockQuote;
        c.characterEscape = characterEscape;
        c.characterReference = characterReference;
        c.codeIndented = codeIndented;
        c.codeFenced = codeFenced;
        c.codeText = codeText;
        c.definition = definition;
        c.frontmatter = frontmatter;
        c.gfmAutolinkLiteral = gfmAutolinkLiteral;
        c.gfmFootnoteDefinition = gfmFootnoteDefinition;
        c.gfmLabelStartFootnote = gfmLabelStartFootnote;
        c.gfmStrikethrough = gfmStrikethrough;
        c.gfmTable = gfmTable;
        c.gfmTaskListItem = gfmTaskListItem;
        c.hardBreakEscape = hardBreakEscape;
        c.hardBreakTrailing = hardBreakTrailing;
        c.headingAtx = headingAtx;
        c.headingSetext = headingSetext;
        c.htmlFlow = htmlFlow;
        c.htmlText = htmlText;
        c.labelStartImage = labelStartImage;
        c.labelStartLink = labelStartLink;
        c.labelEnd = labelEnd;
        c.listItem = listItem;
        c.mathFlow = mathFlow;
        c.mathText = mathText;
        c.mdxEsm = mdxEsm;
        c.mdxExpressionFlow = mdxExpressionFlow;
        c.mdxExpressionText = mdxExpressionText;
        c.mdxJsxFlow = mdxJsxFlow;
        c.mdxJsxText = mdxJsxText;
        c.thematicBreak = thematicBreak;
        return c;
    }

    public function equals(other:Constructs):Bool {
        return attention == other.attention
            && autolink == other.autolink
            && blockQuote == other.blockQuote
            && characterEscape == other.characterEscape
            && characterReference == other.characterReference
            && codeIndented == other.codeIndented
            && codeFenced == other.codeFenced
            && codeText == other.codeText
            && definition == other.definition
            && frontmatter == other.frontmatter
            && gfmAutolinkLiteral == other.gfmAutolinkLiteral
            && gfmFootnoteDefinition == other.gfmFootnoteDefinition
            && gfmLabelStartFootnote == other.gfmLabelStartFootnote
            && gfmStrikethrough == other.gfmStrikethrough
            && gfmTable == other.gfmTable
            && gfmTaskListItem == other.gfmTaskListItem
            && hardBreakEscape == other.hardBreakEscape
            && hardBreakTrailing == other.hardBreakTrailing
            && headingAtx == other.headingAtx
            && headingSetext == other.headingSetext
            && htmlFlow == other.htmlFlow
            && htmlText == other.htmlText
            && labelStartImage == other.labelStartImage
            && labelStartLink == other.labelStartLink
            && labelEnd == other.labelEnd
            && listItem == other.listItem
            && mathFlow == other.mathFlow
            && mathText == other.mathText
            && mdxEsm == other.mdxEsm
            && mdxExpressionFlow == other.mdxExpressionFlow
            && mdxExpressionText == other.mdxExpressionText
            && mdxJsxFlow == other.mdxJsxFlow
            && mdxJsxText == other.mdxJsxText
            && thematicBreak == other.thematicBreak;
    }

    /** Same JSON as serde_json (camelCase keys, declaration order). */
    public function toJson():String {
        var b = new StringBuf();
        b.add('{"attention":' + attention);
        b.add(',"autolink":' + autolink);
        b.add(',"blockQuote":' + blockQuote);
        b.add(',"characterEscape":' + characterEscape);
        b.add(',"characterReference":' + characterReference);
        b.add(',"codeIndented":' + codeIndented);
        b.add(',"codeFenced":' + codeFenced);
        b.add(',"codeText":' + codeText);
        b.add(',"definition":' + definition);
        b.add(',"frontmatter":' + frontmatter);
        b.add(',"gfmAutolinkLiteral":' + gfmAutolinkLiteral);
        b.add(',"gfmFootnoteDefinition":' + gfmFootnoteDefinition);
        b.add(',"gfmLabelStartFootnote":' + gfmLabelStartFootnote);
        b.add(',"gfmStrikethrough":' + gfmStrikethrough);
        b.add(',"gfmTable":' + gfmTable);
        b.add(',"gfmTaskListItem":' + gfmTaskListItem);
        b.add(',"hardBreakEscape":' + hardBreakEscape);
        b.add(',"hardBreakTrailing":' + hardBreakTrailing);
        b.add(',"headingAtx":' + headingAtx);
        b.add(',"headingSetext":' + headingSetext);
        b.add(',"htmlFlow":' + htmlFlow);
        b.add(',"htmlText":' + htmlText);
        b.add(',"labelStartImage":' + labelStartImage);
        b.add(',"labelStartLink":' + labelStartLink);
        b.add(',"labelEnd":' + labelEnd);
        b.add(',"listItem":' + listItem);
        b.add(',"mathFlow":' + mathFlow);
        b.add(',"mathText":' + mathText);
        b.add(',"mdxEsm":' + mdxEsm);
        b.add(',"mdxExpressionFlow":' + mdxExpressionFlow);
        b.add(',"mdxExpressionText":' + mdxExpressionText);
        b.add(',"mdxJsxFlow":' + mdxJsxFlow);
        b.add(',"mdxJsxText":' + mdxJsxText);
        b.add(',"thematicBreak":' + thematicBreak);
        b.add('}');
        return b.toString();
    }

    /** Read the JSON written by serde (missing fields keep their default). */
    public static function fromDynamic(value:Dynamic):Constructs {
        var c = new Constructs();
        if (Reflect.hasField(value, 'attention')) c.attention = Reflect.field(value, 'attention');
        if (Reflect.hasField(value, 'autolink')) c.autolink = Reflect.field(value, 'autolink');
        if (Reflect.hasField(value, 'blockQuote')) c.blockQuote = Reflect.field(value, 'blockQuote');
        if (Reflect.hasField(value, 'characterEscape')) c.characterEscape = Reflect.field(value, 'characterEscape');
        if (Reflect.hasField(value, 'characterReference')) c.characterReference = Reflect.field(value, 'characterReference');
        if (Reflect.hasField(value, 'codeIndented')) c.codeIndented = Reflect.field(value, 'codeIndented');
        if (Reflect.hasField(value, 'codeFenced')) c.codeFenced = Reflect.field(value, 'codeFenced');
        if (Reflect.hasField(value, 'codeText')) c.codeText = Reflect.field(value, 'codeText');
        if (Reflect.hasField(value, 'definition')) c.definition = Reflect.field(value, 'definition');
        if (Reflect.hasField(value, 'frontmatter')) c.frontmatter = Reflect.field(value, 'frontmatter');
        if (Reflect.hasField(value, 'gfmAutolinkLiteral')) c.gfmAutolinkLiteral = Reflect.field(value, 'gfmAutolinkLiteral');
        if (Reflect.hasField(value, 'gfmFootnoteDefinition')) c.gfmFootnoteDefinition = Reflect.field(value, 'gfmFootnoteDefinition');
        if (Reflect.hasField(value, 'gfmLabelStartFootnote')) c.gfmLabelStartFootnote = Reflect.field(value, 'gfmLabelStartFootnote');
        if (Reflect.hasField(value, 'gfmStrikethrough')) c.gfmStrikethrough = Reflect.field(value, 'gfmStrikethrough');
        if (Reflect.hasField(value, 'gfmTable')) c.gfmTable = Reflect.field(value, 'gfmTable');
        if (Reflect.hasField(value, 'gfmTaskListItem')) c.gfmTaskListItem = Reflect.field(value, 'gfmTaskListItem');
        if (Reflect.hasField(value, 'hardBreakEscape')) c.hardBreakEscape = Reflect.field(value, 'hardBreakEscape');
        if (Reflect.hasField(value, 'hardBreakTrailing')) c.hardBreakTrailing = Reflect.field(value, 'hardBreakTrailing');
        if (Reflect.hasField(value, 'headingAtx')) c.headingAtx = Reflect.field(value, 'headingAtx');
        if (Reflect.hasField(value, 'headingSetext')) c.headingSetext = Reflect.field(value, 'headingSetext');
        if (Reflect.hasField(value, 'htmlFlow')) c.htmlFlow = Reflect.field(value, 'htmlFlow');
        if (Reflect.hasField(value, 'htmlText')) c.htmlText = Reflect.field(value, 'htmlText');
        if (Reflect.hasField(value, 'labelStartImage')) c.labelStartImage = Reflect.field(value, 'labelStartImage');
        if (Reflect.hasField(value, 'labelStartLink')) c.labelStartLink = Reflect.field(value, 'labelStartLink');
        if (Reflect.hasField(value, 'labelEnd')) c.labelEnd = Reflect.field(value, 'labelEnd');
        if (Reflect.hasField(value, 'listItem')) c.listItem = Reflect.field(value, 'listItem');
        if (Reflect.hasField(value, 'mathFlow')) c.mathFlow = Reflect.field(value, 'mathFlow');
        if (Reflect.hasField(value, 'mathText')) c.mathText = Reflect.field(value, 'mathText');
        if (Reflect.hasField(value, 'mdxEsm')) c.mdxEsm = Reflect.field(value, 'mdxEsm');
        if (Reflect.hasField(value, 'mdxExpressionFlow')) c.mdxExpressionFlow = Reflect.field(value, 'mdxExpressionFlow');
        if (Reflect.hasField(value, 'mdxExpressionText')) c.mdxExpressionText = Reflect.field(value, 'mdxExpressionText');
        if (Reflect.hasField(value, 'mdxJsxFlow')) c.mdxJsxFlow = Reflect.field(value, 'mdxJsxFlow');
        if (Reflect.hasField(value, 'mdxJsxText')) c.mdxJsxText = Reflect.field(value, 'mdxJsxText');
        if (Reflect.hasField(value, 'thematicBreak')) c.thematicBreak = Reflect.field(value, 'thematicBreak');
        return c;
    }

}
