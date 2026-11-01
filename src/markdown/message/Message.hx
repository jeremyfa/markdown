// Ported from markdown 1.0.0: src/message.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.message;

/**
 * A message, used for errors (`Message` in `message.rs`). Errors are
 * thrown: `toHtmlWithOptions` and `toMdast` throw a `Message`.
 */
class Message {

    /** Place of message. */
    public var place:Null<Place>;
    /** Reason for message (should use markdown). */
    public var reason:String;
    /** Category of message. */
    public var ruleId:String;
    /** Namespace of message. */
    public var source:String;

    public function new(place:Null<Place>, reason:String, ruleId:String, source:String) {
        this.place = place;
        this.reason = reason;
        this.ruleId = ruleId;
        this.source = source;
    }

    public static function placeToString(place:Place):String {
        return switch place {
            case Position(position):
                position.start.line + ':' + position.start.column + '-' + position.end.line + ':' + position.end.column;
            case Point(point):
                point.line + ':' + point.column;
        }
    }

    /** Same as Rust's `Display` output. */
    public function toString():String {
        var prefix = place == null ? '' : placeToString(place) + ': ';
        return prefix + reason + ' (' + source + ':' + ruleId + ')';
    }

}
