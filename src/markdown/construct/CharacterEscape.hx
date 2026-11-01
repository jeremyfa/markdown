// Ported from markdown 1.0.0: src/construct/character_escape.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.construct;

import markdown.Resolve;
import markdown.Subresult;
import markdown.Tokenizer;
import markdown.Parser;
import markdown.event.Event;
import markdown.event.Kind;
import markdown.event.Link;
import markdown.event.Name;
import markdown.state.State;
import markdown.state.StateName;
import markdown.event.Content;

/**
 * Character escapes occur in the string and text content types (`character_escape.rs`).
 */
class CharacterEscape {

    /** Start of character escape. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.characterEscape && tokenizer.current == '\\'.code) {
            tokenizer.enter(Name.CharacterEscape);
            tokenizer.enter(Name.CharacterEscapeMarker);
            tokenizer.consume();
            tokenizer.exit(Name.CharacterEscapeMarker);
            return State.Next(StateName.CharacterEscapeInside);
        }
        else {
            return State.Nok;
        }
    }

    /** After `\`, at punctuation. */
    public static function inside(tokenizer:Tokenizer):State {
        var c = tokenizer.current;
        if ((c >= '!'.code && c <= '/'.code) || (c >= ':'.code && c <= '@'.code) || (c >= '['.code && c <= '`'.code) || (c >= '{'.code && c <= '~'.code)) {
            tokenizer.enter(Name.CharacterEscapeValue);
            tokenizer.consume();
            tokenizer.exit(Name.CharacterEscapeValue);
            tokenizer.exit(Name.CharacterEscape);
            return State.Ok;
        }
        return State.Nok;
    }

}
