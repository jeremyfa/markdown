// Ported from markdown 1.0.0: src/configuration.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown;

import markdown.util.Mdx;

/**
 * Configuration that describes how to parse from markdown (`ParseOptions`).
 */
class ParseOptions {

    /** Which constructs to enable and disable. */
    public var constructs:Constructs = new Constructs();
    /** Whether to support GFM strikethrough with a single tilde. */
    public var gfmStrikethroughSingleTilde:Bool = true;
    /** Whether to support math (text) with a single dollar. */
    public var mathTextSingleDollar:Bool = true;
    /** Function to parse expressions with (not serialized). */
    public var mdxExpressionParse:Null<MdxExpressionParse> = null;
    /** Function to parse ESM with (not serialized). */
    public var mdxEsmParse:Null<MdxEsmParse> = null;

    /** `ParseOptions::default()`: CommonMark. */
    public function new() {}

    /** GFM. */
    public static function gfm():ParseOptions {
        var o = new ParseOptions();
        o.constructs = Constructs.gfm();
        return o;
    }

    /** MDX. */
    public static function mdx():ParseOptions {
        var o = new ParseOptions();
        o.constructs = Constructs.mdx();
        return o;
    }

    public function clone():ParseOptions {
        var o = new ParseOptions();
        o.constructs = constructs.clone();
        o.gfmStrikethroughSingleTilde = gfmStrikethroughSingleTilde;
        o.mathTextSingleDollar = mathTextSingleDollar;
        o.mdxExpressionParse = mdxExpressionParse;
        o.mdxEsmParse = mdxEsmParse;
        return o;
    }

    /** Same JSON as serde_json (the parse functions are skipped). */
    public function toJson():String {
        return '{"constructs":' + constructs.toJson()
            + ',"gfmStrikethroughSingleTilde":' + gfmStrikethroughSingleTilde
            + ',"mathTextSingleDollar":' + mathTextSingleDollar
            + '}';
    }

    /** Read the JSON written by serde (missing fields keep their default). */
    public static function fromDynamic(value:Dynamic):ParseOptions {
        var o = new ParseOptions();
        if (Reflect.hasField(value, 'constructs')) o.constructs = Constructs.fromDynamic(Reflect.field(value, 'constructs'));
        if (Reflect.hasField(value, 'gfmStrikethroughSingleTilde')) o.gfmStrikethroughSingleTilde = Reflect.field(value, 'gfmStrikethroughSingleTilde');
        if (Reflect.hasField(value, 'mathTextSingleDollar')) o.mathTextSingleDollar = Reflect.field(value, 'mathTextSingleDollar');
        return o;
    }

}
