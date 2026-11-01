// Ported from markdown 1.0.0: src/util/mdx.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.util;

/**
 * Signal used as feedback when parsing MDX ESM or expressions (`Signal` in `mdx.rs`).
 */
enum MdxSignal {
    /** A syntax error: reason, relative byte offset, source, rule id. */
    Error(reason:String, offset:Int, source:String, ruleId:String);
    /** An error at the end of the (partial?) expression: reason, source, rule id. */
    Eof(reason:String, source:String, ruleId:String);
    /** Done, successfully. */
    Ok;
}

/** Expression kind (`ExpressionKind` in `mdx.rs`). */
enum abstract MdxExpressionKind(Int) {
    /** Kind of expressions in prose: `{Math.PI}`. */
    var Expression = 0;
    /** Kind of expressions as attributes: `<b {...props} />`. */
    var AttributeExpression = 1;
    /** Kind of expressions as attribute values: `<b c={1 + 1} />`. */
    var AttributeValueExpression = 2;
}

/** Signature of a function that parses ESM (`EsmParse`). */
typedef MdxEsmParse = (value:String) -> MdxSignal;

/** Signature of a function that parses expressions (`ExpressionParse`). */
typedef MdxExpressionParse = (value:String, kind:MdxExpressionKind) -> MdxSignal;
