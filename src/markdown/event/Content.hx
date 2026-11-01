// Ported from markdown 1.0.0: src/event.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.event;

/**
 * Embedded content type (`Content` in `event.rs`).
 */
enum abstract Content(Int) {
    var Flow = 0;
    var Content = 1;
    var String = 2;
    var Text = 3;
}
