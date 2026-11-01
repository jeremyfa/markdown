// Ported from markdown 1.0.0: src/state.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.state;

import markdown.message.Message;

/**
 * Result of a state (`State` in `state.rs`).
 *
 * Encoded as an `Int` so that moving from state to state never allocates:
 * `Next(name)` is `name * 2`, `Retry(name)` is `name * 2 + 1`, and `Ok`,
 * `Nok` and `Error` are negative. The message of an `Error` is kept in
 * `State.errorMessage` (an error always stops the whole parse).
 */
enum abstract State(Int) {

    var Ok = -1;
    var Nok = -2;
    var Error = -3;

    /** The message of the last `State.error()`. */
    public static var errorMessage:Message = null;

    /** Move to `name` with the next byte (`State::Next`). */
    public static inline function Next(name:StateName):State {
        return cast (name.toInt() << 1);
    }

    /** Retry `name` with the same byte (`State::Retry`). */
    public static inline function Retry(name:StateName):State {
        return cast ((name.toInt() << 1) | 1);
    }

    /** Stop with an error (`State::Error`). */
    public static function error(message:Message):State {
        errorMessage = message;
        return Error;
    }

    public inline function isNext():Bool {
        return this >= 0 && (this & 1) == 0;
    }

    public inline function isRetry():Bool {
        return this >= 0 && (this & 1) == 1;
    }

    /** The state name of a `Next` or `Retry`. */
    public inline function name():StateName {
        return cast (this >> 1);
    }

    public inline function toInt():Int {
        return this;
    }

    /** Turn a final state into a result: throws the message on `Error`. */
    public function toResult():Void {
        if (this == -3)
            throw errorMessage;
        if (this != -1)
            throw 'cannot turn intermediate state into result';
    }

}
