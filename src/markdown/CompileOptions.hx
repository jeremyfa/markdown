// Ported from markdown 1.0.0: src/configuration.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown;

import markdown.util.Json;
import markdown.util.LineEnding;

/**
 * Configuration that describes how to compile to HTML (`CompileOptions`).
 */
class CompileOptions {

    /** Whether to allow all values in images. */
    public var allowAnyImgSrc:Bool = false;
    /** Whether to allow (dangerous) HTML. */
    public var allowDangerousHtml:Bool = false;
    /** Whether to allow dangerous protocols in links and images. */
    public var allowDangerousProtocol:Bool = false;
    /** Default line ending to use when compiling to HTML, for line endings not in `value`. */
    public var defaultLineEnding:LineEnding = LineEnding.LineFeed;
    /** Textual label to describe the backreference back to footnote calls. */
    public var gfmFootnoteBackLabel:Null<String> = null;
    /** Prefix to use before the `id` attribute on footnotes to prevent them from *clobbering*. */
    public var gfmFootnoteClobberPrefix:Null<String> = null;
    /** Attributes to use on the footnote label. */
    public var gfmFootnoteLabelAttributes:Null<String> = null;
    /** HTML tag name to use for the footnote label element. */
    public var gfmFootnoteLabelTagName:Null<String> = null;
    /** Textual label to use for the footnotes section. */
    public var gfmFootnoteLabel:Null<String> = null;
    /** Whether or not GFM task list html `<input>` items are enabled. */
    public var gfmTaskListItemCheckable:Bool = false;
    /** Whether to support the GFM tagfilter. */
    public var gfmTagfilter:Bool = false;

    public function new() {}

    /** GFM: turn on the tag filter. */
    public static function gfm():CompileOptions {
        var o = new CompileOptions();
        o.gfmTagfilter = true;
        return o;
    }

    public function clone():CompileOptions {
        var o = new CompileOptions();
        o.allowAnyImgSrc = allowAnyImgSrc;
        o.allowDangerousHtml = allowDangerousHtml;
        o.allowDangerousProtocol = allowDangerousProtocol;
        o.defaultLineEnding = defaultLineEnding;
        o.gfmFootnoteBackLabel = gfmFootnoteBackLabel;
        o.gfmFootnoteClobberPrefix = gfmFootnoteClobberPrefix;
        o.gfmFootnoteLabelAttributes = gfmFootnoteLabelAttributes;
        o.gfmFootnoteLabelTagName = gfmFootnoteLabelTagName;
        o.gfmFootnoteLabel = gfmFootnoteLabel;
        o.gfmTaskListItemCheckable = gfmTaskListItemCheckable;
        o.gfmTagfilter = gfmTagfilter;
        return o;
    }

    /** Same JSON as serde_json. */
    public function toJson():String {
        return '{"allowAnyImgSrc":' + allowAnyImgSrc
            + ',"allowDangerousHtml":' + allowDangerousHtml
            + ',"allowDangerousProtocol":' + allowDangerousProtocol
            + ',"defaultLineEnding":' + Json.quote(defaultLineEnding.asStr())
            + ',"gfmFootnoteBackLabel":' + Json.quoteOpt(gfmFootnoteBackLabel)
            + ',"gfmFootnoteClobberPrefix":' + Json.quoteOpt(gfmFootnoteClobberPrefix)
            + ',"gfmFootnoteLabelAttributes":' + Json.quoteOpt(gfmFootnoteLabelAttributes)
            + ',"gfmFootnoteLabelTagName":' + Json.quoteOpt(gfmFootnoteLabelTagName)
            + ',"gfmFootnoteLabel":' + Json.quoteOpt(gfmFootnoteLabel)
            + ',"gfmTaskListItemCheckable":' + gfmTaskListItemCheckable
            + ',"gfmTagfilter":' + gfmTagfilter
            + '}';
    }

    /** Read the JSON written by serde (missing fields keep their default). */
    public static function fromDynamic(value:Dynamic):CompileOptions {
        var o = new CompileOptions();
        if (Reflect.hasField(value, 'allowAnyImgSrc')) o.allowAnyImgSrc = Reflect.field(value, 'allowAnyImgSrc');
        if (Reflect.hasField(value, 'allowDangerousHtml')) o.allowDangerousHtml = Reflect.field(value, 'allowDangerousHtml');
        if (Reflect.hasField(value, 'allowDangerousProtocol')) o.allowDangerousProtocol = Reflect.field(value, 'allowDangerousProtocol');
        if (Reflect.hasField(value, 'defaultLineEnding')) o.defaultLineEnding = LineEnding.fromStr(Reflect.field(value, 'defaultLineEnding'));
        if (Reflect.hasField(value, 'gfmFootnoteBackLabel')) o.gfmFootnoteBackLabel = Reflect.field(value, 'gfmFootnoteBackLabel');
        if (Reflect.hasField(value, 'gfmFootnoteClobberPrefix')) o.gfmFootnoteClobberPrefix = Reflect.field(value, 'gfmFootnoteClobberPrefix');
        if (Reflect.hasField(value, 'gfmFootnoteLabelAttributes')) o.gfmFootnoteLabelAttributes = Reflect.field(value, 'gfmFootnoteLabelAttributes');
        if (Reflect.hasField(value, 'gfmFootnoteLabelTagName')) o.gfmFootnoteLabelTagName = Reflect.field(value, 'gfmFootnoteLabelTagName');
        if (Reflect.hasField(value, 'gfmFootnoteLabel')) o.gfmFootnoteLabel = Reflect.field(value, 'gfmFootnoteLabel');
        if (Reflect.hasField(value, 'gfmTaskListItemCheckable')) o.gfmTaskListItemCheckable = Reflect.field(value, 'gfmTaskListItemCheckable');
        if (Reflect.hasField(value, 'gfmTagfilter')) o.gfmTagfilter = Reflect.field(value, 'gfmTagfilter');
        return o;
    }

}
