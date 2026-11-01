// Ported from markdown 1.0.0: src/event.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.event;

/**
 * Something semantic happening somewhere (`Event` in `event.rs`).
 */
class Event {

    public var kind:Kind;
    public var name:Name;
    public var point:Point;
    public var link:Null<Link>;

    public inline function new(kind:Kind, name:Name, point:Point, link:Null<Link>) {
        this.kind = kind;
        this.name = name;
        this.point = point;
        this.link = link;
    }

    /** Deep copy, like Rust's `Clone`. */
    public inline function clone():Event {
        return new Event(kind, name, point.clone(), link == null ? null : link.clone());
    }

}
