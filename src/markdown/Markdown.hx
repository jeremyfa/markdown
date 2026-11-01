// Ported from markdown 1.0.0: src/lib.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown;

import markdown.mdast.Node;
import markdown.util.Utf8;

/**
 * Public API of markdown-rs (`lib.rs`): turn markdown into HTML or into a
 * syntax tree (mdast).
 *
 * Errors (only possible with MDX) are thrown as `markdown.message.Message`.
 */
class Markdown {

    /** Turn markdown into HTML (CommonMark, safe). */
    public static function toHtml(value:String):String {
        return toHtmlWithOptions(value, new Options());
    }

    /** Turn markdown into HTML, with configuration. Throws a `Message` on error (MDX). */
    public static function toHtmlWithOptions(value:String, options:Options):String {
        return toHtmlBytes(Utf8.bytesOf(value), options);
    }

    /** Same as `toHtmlWithOptions`, from UTF-8 bytes. */
    public static function toHtmlBytes(value:haxe.io.Bytes, options:Options):String {
        var result = Parser.parse(value, options.parse);
        return ToHtml.compile(result.events, result.parseState.bytes, options.compile);
    }

    /** Turn markdown into a syntax tree. Throws a `Message` on error (MDX). */
    public static function toMdast(value:String, options:ParseOptions):Node {
        return toMdastBytes(Utf8.bytesOf(value), options);
    }

    /** Same as `toMdast`, from UTF-8 bytes. */
    public static function toMdastBytes(value:haxe.io.Bytes, options:ParseOptions):Node {
        var result = Parser.parse(value, options);
        return ToMdast.compile(result.events, result.parseState.bytes);
    }

}
