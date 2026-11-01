// Ported from markdown 1.0.0: src/construct/frontmatter.rs
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
import markdown.util.Constant;

/**
 * Frontmatter occurs at the start of the document (`frontmatter.rs`).
 */
class Frontmatter {

    /** Start of frontmatter. */
    public static function start(tokenizer:Tokenizer):State {
        // Indent not allowed.
        if (tokenizer.parseState.options.constructs.frontmatter && (tokenizer.current == '+'.code || tokenizer.current == '-'.code)) {
            tokenizer.tokenizeState.marker = tokenizer.current;
            tokenizer.enter(Name.Frontmatter);
            tokenizer.enter(Name.FrontmatterFence);
            tokenizer.enter(Name.FrontmatterSequence);
            return State.Retry(StateName.FrontmatterOpenSequence);
        }
        else {
            return State.Nok;
        }
    }

    /** In open sequence. */
    public static function openSequence(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.marker) {
            tokenizer.tokenizeState.size += 1;
            tokenizer.consume();
            return State.Next(StateName.FrontmatterOpenSequence);
        }
        else if (tokenizer.tokenizeState.size == Constant.FRONTMATTER_SEQUENCE_SIZE) {
            tokenizer.tokenizeState.size = 0;
            tokenizer.exit(Name.FrontmatterSequence);

            if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
                tokenizer.attempt(State.Next(StateName.FrontmatterOpenAfter), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
            }
            else {
                return State.Retry(StateName.FrontmatterOpenAfter);
            }
        }
        else {
            tokenizer.tokenizeState.marker = 0;
            tokenizer.tokenizeState.size = 0;
            return State.Nok;
        }
    }

    /** After open sequence. */
    public static function openAfter(tokenizer:Tokenizer):State {
        if (tokenizer.current == '\n'.code) {
            tokenizer.exit(Name.FrontmatterFence);
            tokenizer.enter(Name.LineEnding);
            tokenizer.consume();
            tokenizer.exit(Name.LineEnding);
            tokenizer.attempt(State.Next(StateName.FrontmatterAfter), State.Next(StateName.FrontmatterContentStart));
            return State.Next(StateName.FrontmatterCloseStart);
        }
        else {
            tokenizer.tokenizeState.marker = 0;
            return State.Nok;
        }
    }

    /** Start of close sequence. */
    public static function closeStart(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.marker) {
            tokenizer.enter(Name.FrontmatterFence);
            tokenizer.enter(Name.FrontmatterSequence);
            return State.Retry(StateName.FrontmatterCloseSequence);
        }
        else {
            return State.Nok;
        }
    }

    /** In close sequence. */
    public static function closeSequence(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.marker) {
            tokenizer.tokenizeState.size += 1;
            tokenizer.consume();
            return State.Next(StateName.FrontmatterCloseSequence);
        }
        else if (tokenizer.tokenizeState.size == Constant.FRONTMATTER_SEQUENCE_SIZE) {
            tokenizer.tokenizeState.size = 0;
            tokenizer.exit(Name.FrontmatterSequence);

            if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
                tokenizer.attempt(State.Next(StateName.FrontmatterCloseAfter), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
            }
            else {
                return State.Retry(StateName.FrontmatterCloseAfter);
            }
        }
        else {
            tokenizer.tokenizeState.size = 0;
            return State.Nok;
        }
    }

    /** After close sequence. */
    public static function closeAfter(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                tokenizer.exit(Name.FrontmatterFence);
                return State.Ok;
            default:
                return State.Nok;
        }
    }

    /** Start of content chunk. */
    public static function contentStart(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                return State.Retry(StateName.FrontmatterContentEnd);
            default:
                tokenizer.enter(Name.FrontmatterChunk);
                return State.Retry(StateName.FrontmatterContentInside);
        }
    }

    /** In content chunk. */
    public static function contentInside(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                tokenizer.exit(Name.FrontmatterChunk);
                return State.Retry(StateName.FrontmatterContentEnd);
            default:
                tokenizer.consume();
                return State.Next(StateName.FrontmatterContentInside);
        }
    }

    /** End of content chunk. */
    public static function contentEnd(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1:
                tokenizer.tokenizeState.marker = 0;
                return State.Nok;
            case '\n'.code:
                tokenizer.enter(Name.LineEnding);
                tokenizer.consume();
                tokenizer.exit(Name.LineEnding);
                tokenizer.attempt(State.Next(StateName.FrontmatterAfter), State.Next(StateName.FrontmatterContentStart));
                return State.Next(StateName.FrontmatterCloseStart);
            default:
                throw 'expected eof/eol';
        }
    }

    /** After frontmatter. */
    public static function after(tokenizer:Tokenizer):State {
        tokenizer.exit(Name.Frontmatter);
        return State.Ok;
    }

}
