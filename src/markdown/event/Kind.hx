// Ported from markdown 1.0.0: src/event.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.event;

/**
 * Kind of event (`Kind` in `event.rs`).
 */
enum abstract Kind(Int) {
    /** Start of a span. */
    var Enter = 0;
    /** End of a span. */
    var Exit = 1;
}
