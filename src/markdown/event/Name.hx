// Ported from markdown 1.0.0: src/event.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.event;

/**
 * Semantic label of a span (`Name` in `event.rs`).
 */
enum abstract Name(Int) {

    var AttentionSequence = 0;
    var Autolink = 1;
    var AutolinkEmail = 2;
    var AutolinkMarker = 3;
    var AutolinkProtocol = 4;
    var BlankLineEnding = 5;
    var BlockQuote = 6;
    var BlockQuoteMarker = 7;
    var BlockQuotePrefix = 8;
    var ByteOrderMark = 9;
    var CharacterEscape = 10;
    var CharacterEscapeMarker = 11;
    var CharacterEscapeValue = 12;
    var CharacterReference = 13;
    var CharacterReferenceMarker = 14;
    var CharacterReferenceMarkerHexadecimal = 15;
    var CharacterReferenceMarkerNumeric = 16;
    var CharacterReferenceMarkerSemi = 17;
    var CharacterReferenceValue = 18;
    var CodeFenced = 19;
    var CodeFencedFence = 20;
    var CodeFencedFenceInfo = 21;
    var CodeFencedFenceMeta = 22;
    var CodeFencedFenceSequence = 23;
    var CodeFlowChunk = 24;
    var CodeIndented = 25;
    var CodeText = 26;
    var CodeTextData = 27;
    var CodeTextSequence = 28;
    var Content = 29;
    var Data = 30;
    var Definition = 31;
    var DefinitionDestination = 32;
    var DefinitionDestinationLiteral = 33;
    var DefinitionDestinationLiteralMarker = 34;
    var DefinitionDestinationRaw = 35;
    var DefinitionDestinationString = 36;
    var DefinitionLabel = 37;
    var DefinitionLabelMarker = 38;
    var DefinitionLabelString = 39;
    var DefinitionMarker = 40;
    var DefinitionTitle = 41;
    var DefinitionTitleMarker = 42;
    var DefinitionTitleString = 43;
    var Emphasis = 44;
    var EmphasisSequence = 45;
    var EmphasisText = 46;
    var Frontmatter = 47;
    var FrontmatterChunk = 48;
    var FrontmatterFence = 49;
    var FrontmatterSequence = 50;
    var GfmAutolinkLiteralEmail = 51;
    var GfmAutolinkLiteralMailto = 52;
    var GfmAutolinkLiteralProtocol = 53;
    var GfmAutolinkLiteralWww = 54;
    var GfmAutolinkLiteralXmpp = 55;
    var GfmFootnoteCall = 56;
    var GfmFootnoteCallLabel = 57;
    var GfmFootnoteCallMarker = 58;
    var GfmFootnoteDefinition = 59;
    var GfmFootnoteDefinitionPrefix = 60;
    var GfmFootnoteDefinitionLabel = 61;
    var GfmFootnoteDefinitionLabelMarker = 62;
    var GfmFootnoteDefinitionLabelString = 63;
    var GfmFootnoteDefinitionMarker = 64;
    var GfmStrikethrough = 65;
    var GfmStrikethroughSequence = 66;
    var GfmStrikethroughText = 67;
    var GfmTable = 68;
    var GfmTableBody = 69;
    var GfmTableCell = 70;
    var GfmTableCellText = 71;
    var GfmTableCellDivider = 72;
    var GfmTableDelimiterRow = 73;
    var GfmTableDelimiterMarker = 74;
    var GfmTableDelimiterCell = 75;
    var GfmTableDelimiterCellValue = 76;
    var GfmTableDelimiterFiller = 77;
    var GfmTableHead = 78;
    var GfmTableRow = 79;
    var GfmTaskListItemCheck = 80;
    var GfmTaskListItemMarker = 81;
    var GfmTaskListItemValueChecked = 82;
    var GfmTaskListItemValueUnchecked = 83;
    var HardBreakEscape = 84;
    var HardBreakTrailing = 85;
    var HeadingAtx = 86;
    var HeadingAtxSequence = 87;
    var HeadingAtxText = 88;
    var HeadingSetext = 89;
    var HeadingSetextText = 90;
    var HeadingSetextUnderline = 91;
    var HeadingSetextUnderlineSequence = 92;
    var HtmlFlow = 93;
    var HtmlFlowData = 94;
    var HtmlText = 95;
    var HtmlTextData = 96;
    var Image = 97;
    var Label = 98;
    var LabelEnd = 99;
    var LabelImage = 100;
    var LabelImageMarker = 101;
    var LabelLink = 102;
    var LabelMarker = 103;
    var LabelText = 104;
    var LineEnding = 105;
    var Link = 106;
    var ListItem = 107;
    var ListItemMarker = 108;
    var ListItemPrefix = 109;
    var ListItemValue = 110;
    var ListOrdered = 111;
    var ListUnordered = 112;
    var MathFlow = 113;
    var MathFlowFence = 114;
    var MathFlowFenceMeta = 115;
    var MathFlowFenceSequence = 116;
    var MathFlowChunk = 117;
    var MathText = 118;
    var MathTextData = 119;
    var MathTextSequence = 120;
    var MdxEsm = 121;
    var MdxEsmData = 122;
    var MdxExpressionMarker = 123;
    var MdxExpressionData = 124;
    var MdxFlowExpression = 125;
    var MdxTextExpression = 126;
    var MdxJsxFlowTag = 127;
    var MdxJsxTextTag = 128;
    var MdxJsxEsWhitespace = 129;
    var MdxJsxTagMarker = 130;
    var MdxJsxTagClosingMarker = 131;
    var MdxJsxTagName = 132;
    var MdxJsxTagNamePrimary = 133;
    var MdxJsxTagNameMemberMarker = 134;
    var MdxJsxTagNamePrefixMarker = 135;
    var MdxJsxTagNameMember = 136;
    var MdxJsxTagNameLocal = 137;
    var MdxJsxTagAttribute = 138;
    var MdxJsxTagAttributeExpression = 139;
    var MdxJsxTagAttributeName = 140;
    var MdxJsxTagAttributePrimaryName = 141;
    var MdxJsxTagAttributeNamePrefixMarker = 142;
    var MdxJsxTagAttributeNameLocal = 143;
    var MdxJsxTagAttributeInitializerMarker = 144;
    var MdxJsxTagAttributeValueExpression = 145;
    var MdxJsxTagAttributeValueLiteral = 146;
    var MdxJsxTagAttributeValueLiteralMarker = 147;
    var MdxJsxTagAttributeValueLiteralValue = 148;
    var MdxJsxTagSelfClosingMarker = 149;
    var Paragraph = 150;
    var Reference = 151;
    var ReferenceMarker = 152;
    var ReferenceString = 153;
    var Resource = 154;
    var ResourceDestination = 155;
    var ResourceDestinationLiteral = 156;
    var ResourceDestinationLiteralMarker = 157;
    var ResourceDestinationRaw = 158;
    var ResourceDestinationString = 159;
    var ResourceMarker = 160;
    var ResourceTitle = 161;
    var ResourceTitleMarker = 162;
    var ResourceTitleString = 163;
    var SpaceOrTab = 164;
    var Strong = 165;
    var StrongSequence = 166;
    var StrongText = 167;
    var ThematicBreak = 168;
    var ThematicBreakSequence = 169;
    var LinePrefix = 170;

    public static final NAMES:Array<String> = ["AttentionSequence", "Autolink", "AutolinkEmail", "AutolinkMarker", "AutolinkProtocol", "BlankLineEnding", "BlockQuote", "BlockQuoteMarker", "BlockQuotePrefix", "ByteOrderMark", "CharacterEscape", "CharacterEscapeMarker", "CharacterEscapeValue", "CharacterReference", "CharacterReferenceMarker", "CharacterReferenceMarkerHexadecimal", "CharacterReferenceMarkerNumeric", "CharacterReferenceMarkerSemi", "CharacterReferenceValue", "CodeFenced", "CodeFencedFence", "CodeFencedFenceInfo", "CodeFencedFenceMeta", "CodeFencedFenceSequence", "CodeFlowChunk", "CodeIndented", "CodeText", "CodeTextData", "CodeTextSequence", "Content", "Data", "Definition", "DefinitionDestination", "DefinitionDestinationLiteral", "DefinitionDestinationLiteralMarker", "DefinitionDestinationRaw", "DefinitionDestinationString", "DefinitionLabel", "DefinitionLabelMarker", "DefinitionLabelString", "DefinitionMarker", "DefinitionTitle", "DefinitionTitleMarker", "DefinitionTitleString", "Emphasis", "EmphasisSequence", "EmphasisText", "Frontmatter", "FrontmatterChunk", "FrontmatterFence", "FrontmatterSequence", "GfmAutolinkLiteralEmail", "GfmAutolinkLiteralMailto", "GfmAutolinkLiteralProtocol", "GfmAutolinkLiteralWww", "GfmAutolinkLiteralXmpp", "GfmFootnoteCall", "GfmFootnoteCallLabel", "GfmFootnoteCallMarker", "GfmFootnoteDefinition", "GfmFootnoteDefinitionPrefix", "GfmFootnoteDefinitionLabel", "GfmFootnoteDefinitionLabelMarker", "GfmFootnoteDefinitionLabelString", "GfmFootnoteDefinitionMarker", "GfmStrikethrough", "GfmStrikethroughSequence", "GfmStrikethroughText", "GfmTable", "GfmTableBody", "GfmTableCell", "GfmTableCellText", "GfmTableCellDivider", "GfmTableDelimiterRow", "GfmTableDelimiterMarker", "GfmTableDelimiterCell", "GfmTableDelimiterCellValue", "GfmTableDelimiterFiller", "GfmTableHead", "GfmTableRow", "GfmTaskListItemCheck", "GfmTaskListItemMarker", "GfmTaskListItemValueChecked", "GfmTaskListItemValueUnchecked", "HardBreakEscape", "HardBreakTrailing", "HeadingAtx", "HeadingAtxSequence", "HeadingAtxText", "HeadingSetext", "HeadingSetextText", "HeadingSetextUnderline", "HeadingSetextUnderlineSequence", "HtmlFlow", "HtmlFlowData", "HtmlText", "HtmlTextData", "Image", "Label", "LabelEnd", "LabelImage", "LabelImageMarker", "LabelLink", "LabelMarker", "LabelText", "LineEnding", "Link", "ListItem", "ListItemMarker", "ListItemPrefix", "ListItemValue", "ListOrdered", "ListUnordered", "MathFlow", "MathFlowFence", "MathFlowFenceMeta", "MathFlowFenceSequence", "MathFlowChunk", "MathText", "MathTextData", "MathTextSequence", "MdxEsm", "MdxEsmData", "MdxExpressionMarker", "MdxExpressionData", "MdxFlowExpression", "MdxTextExpression", "MdxJsxFlowTag", "MdxJsxTextTag", "MdxJsxEsWhitespace", "MdxJsxTagMarker", "MdxJsxTagClosingMarker", "MdxJsxTagName", "MdxJsxTagNamePrimary", "MdxJsxTagNameMemberMarker", "MdxJsxTagNamePrefixMarker", "MdxJsxTagNameMember", "MdxJsxTagNameLocal", "MdxJsxTagAttribute", "MdxJsxTagAttributeExpression", "MdxJsxTagAttributeName", "MdxJsxTagAttributePrimaryName", "MdxJsxTagAttributeNamePrefixMarker", "MdxJsxTagAttributeNameLocal", "MdxJsxTagAttributeInitializerMarker", "MdxJsxTagAttributeValueExpression", "MdxJsxTagAttributeValueLiteral", "MdxJsxTagAttributeValueLiteralMarker", "MdxJsxTagAttributeValueLiteralValue", "MdxJsxTagSelfClosingMarker", "Paragraph", "Reference", "ReferenceMarker", "ReferenceString", "Resource", "ResourceDestination", "ResourceDestinationLiteral", "ResourceDestinationLiteralMarker", "ResourceDestinationRaw", "ResourceDestinationString", "ResourceMarker", "ResourceTitle", "ResourceTitleMarker", "ResourceTitleString", "SpaceOrTab", "Strong", "StrongSequence", "StrongText", "ThematicBreak", "ThematicBreakSequence", "LinePrefix"];

    public inline function toInt():Int {
        return this;
    }

    public function toString():String {
        return NAMES[this];
    }

}
