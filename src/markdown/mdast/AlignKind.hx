// Ported from markdown 1.0.0: src/mdast.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.mdast;

/**
 * GFM: alignment of phrasing content (`AlignKind` in `mdast.rs`).
 * Serialized as `"left"`, `"right"`, `"center"` or `null`.
 */
enum abstract AlignKind(Int) {
    /** Left alignment. */
    var Left = 0;
    /** Right alignment. */
    var Right = 1;
    /** Center alignment. */
    var Center = 2;
    /** No alignment. */
    var None = 3;

    /** Same JSON as serde_json. */
    public function toJson():String {
        return switch (cast this : AlignKind) {
            case Left: '"left"';
            case Right: '"right"';
            case Center: '"center"';
            case None: 'null';
        }
    }
}
