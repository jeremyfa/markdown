// Ported from markdown 1.0.0: src/construct/content.rs
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
import markdown.Subtokenize;

/**
 * Content occurs in the flow content type (`content.rs`).
 */
class ContentConstruct {

    /** Before a content chunk. */
    public static function chunkStart(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                throw 'unexpected eol/eof';
            default:
                tokenizer.enterLink(Name.Content, new Link(-1, -1, Content.Content));
                return State.Retry(StateName.ContentChunkInside);
        }
    }

    /** In a content chunk. */
    public static function chunkInside(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                tokenizer.exit(Name.Content);
                tokenizer.registerResolverBefore(ResolveName.Content);
                // You'd be interrupting.
                tokenizer.interrupt = true;
                return State.Ok;
            default:
                tokenizer.consume();
                return State.Next(StateName.ContentChunkInside);
        }
    }

    /** Before a definition. */
    public static function definitionBefore(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.ContentDefinitionAfter), State.Next(StateName.ParagraphStart));
        return State.Retry(StateName.DefinitionStart);
    }

    /** After a definition. */
    public static function definitionAfter(tokenizer:Tokenizer):State {
        if (tokenizer.current == -1) {
            return State.Ok;
        }
        else {
            tokenizer.enter(Name.LineEnding);
            tokenizer.consume();
            tokenizer.exit(Name.LineEnding);
            return State.Next(StateName.ContentDefinitionBefore);
        }
    }

    /** Merge `Content` chunks, which currently span a single line, into actual `Content`s that span multiple lines. */
    public static function resolve(tokenizer:Tokenizer):Null<Subresult> {
        var index = 0;

        while (index < tokenizer.events.length) {
            var event = tokenizer.events[index];

            if (event.kind == Kind.Enter && event.name == Name.Content) {
                // Exit:Content
                var exitIndex = index + 1;

                while (true) {
                    var enterIndex = exitIndex + 1;

                    if (enterIndex == tokenizer.events.length || tokenizer.events[enterIndex].name != Name.LineEnding) {
                        break;
                    }

                    // Skip past line ending.
                    enterIndex += 2;

                    // Skip past prefix.
                    while (enterIndex < tokenizer.events.length) {
                        var event = tokenizer.events[enterIndex];

                        if (event.name != Name.SpaceOrTab && event.name != Name.BlockQuotePrefix && event.name != Name.BlockQuoteMarker) {
                            break;
                        }

                        enterIndex += 1;
                    }

                    if (enterIndex == tokenizer.events.length || tokenizer.events[enterIndex].name != Name.Content) {
                        break;
                    }

                    // Set Exit:Content point to Exit:LineEnding.
                    tokenizer.events[exitIndex].point = tokenizer.events[exitIndex + 2].point.clone();
                    // Remove Enter:LineEnding, Exit:LineEnding.
                    tokenizer.map.add(exitIndex + 1, 2, []);

                    // Link Enter:Content to Enter:Content on this line and vice versa.
                    tokenizer.events[exitIndex - 1].link.next = enterIndex;
                    tokenizer.events[enterIndex].link.previous = exitIndex - 1;

                    // Potential next start.
                    exitIndex = enterIndex + 1;
                }

                // Move to `Exit:Content`.
                index = exitIndex;
            }

            index += 1;
        }

        tokenizer.map.consume(tokenizer.events);

        var result = Subtokenize.subtokenize(tokenizer.events, tokenizer.parseState, Content.Content);

        return result;
    }

}
