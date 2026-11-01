// Ported from markdown 1.0.0: src/message.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.message;

/**
 * Where a message happened (`Place` in `message.rs`).
 */
enum Place {
    /** Between two points. */
    Position(position:markdown.unist.Position);
    /** At a point. */
    Point(point:markdown.unist.Point);
}
