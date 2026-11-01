// Ported from markdown 1.0.0: src/event.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.event;

/**
 * Link to another event (`Link` in `event.rs`). `-1` stands for `None`.
 */
class Link {

    public var previous:Int;
    public var next:Int;
    public var content:Content;

    public inline function new(previous:Int, next:Int, content:Content) {
        this.previous = previous;
        this.next = next;
        this.content = content;
    }

    public inline function clone():Link {
        return new Link(previous, next, content);
    }

}
