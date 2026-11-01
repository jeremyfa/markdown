// Ported from markdown 1.0.0: src/subtokenize.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown;

/**
 * Result of a sub-tokenization (`Subresult` in `subtokenize.rs`).
 */
class Subresult {
    /** Whether all content was done. */
    public var done:Bool;
    /** GFM footnote definitions found. */
    public var gfmFootnoteDefinitions:Array<String>;
    /** Definitions found. */
    public var definitions:Array<String>;

    public inline function new(done:Bool, gfmFootnoteDefinitions:Array<String>, definitions:Array<String>) {
        this.done = done;
        this.gfmFootnoteDefinitions = gfmFootnoteDefinitions;
        this.definitions = definitions;
    }
}
