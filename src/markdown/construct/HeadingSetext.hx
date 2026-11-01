// Ported from markdown 1.0.0: src/construct/heading_setext.rs
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
import markdown.util.Skip;

/**
 * Heading (setext) occurs in the flow content type (`heading_setext.rs`).
 */
class HeadingSetext {

    /** At start of heading (setext) underline. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.headingSetext
            && !tokenizer.lazy
            && !tokenizer.pierce
            // Require a paragraph before.
            && (tokenizer.events.length > 0 && {
                var name = tokenizer.events[Skip.optBack(tokenizer.events, tokenizer.events.length - 1, [Name.LineEnding, Name.SpaceOrTab])].name;
                name == Name.Content || name == Name.HeadingSetextUnderline;
            })) {
            tokenizer.enter(Name.HeadingSetextUnderline);

            if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
                tokenizer.attempt(State.Next(StateName.HeadingSetextBefore), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 0,
                    tokenizer.parseState.options.constructs.codeIndented ? Constant.TAB_SIZE - 1 : PartialSpaceOrTab.MAX));
            }
            else {
                return State.Retry(StateName.HeadingSetextBefore);
            }
        }
        else {
            return State.Nok;
        }
    }

    /** After optional whitespace, at `-` or `=`. */
    public static function before(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '-'.code | '='.code:
                tokenizer.tokenizeState.marker = tokenizer.current;
                tokenizer.enter(Name.HeadingSetextUnderlineSequence);
                return State.Retry(StateName.HeadingSetextInside);
            default:
                return State.Nok;
        }
    }

    /** In sequence. */
    public static function inside(tokenizer:Tokenizer):State {
        if (tokenizer.current == tokenizer.tokenizeState.marker) {
            tokenizer.consume();
            return State.Next(StateName.HeadingSetextInside);
        }
        else {
            tokenizer.tokenizeState.marker = 0;
            tokenizer.exit(Name.HeadingSetextUnderlineSequence);

            if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
                tokenizer.attempt(State.Next(StateName.HeadingSetextAfter), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
            }
            else {
                return State.Retry(StateName.HeadingSetextAfter);
            }
        }
    }

    /** After sequence, after optional whitespace. */
    public static function after(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                // Feel free to interrupt.
                tokenizer.interrupt = false;
                tokenizer.registerResolver(ResolveName.HeadingSetext);
                tokenizer.exit(Name.HeadingSetextUnderline);
                return State.Ok;
            default:
                return State.Nok;
        }
    }

    /** Resolve heading (setext). */
    public static function resolve(tokenizer:Tokenizer):Null<Subresult> {
        var enter = Skip.to(tokenizer.events, 0, [Name.HeadingSetextUnderline]);

        while (enter < tokenizer.events.length) {
            var exit = Skip.to(tokenizer.events, enter + 1, [Name.HeadingSetextUnderline]);

            // Find paragraph before
            var paragraphExitBefore = Skip.optBack(tokenizer.events, enter - 1, [Name.SpaceOrTab, Name.LineEnding, Name.BlockQuotePrefix]);

            // There's a paragraph before: this is a setext heading.
            if (tokenizer.events[paragraphExitBefore].name == Name.Paragraph) {
                var paragraphEnter = Skip.toBack(tokenizer.events, paragraphExitBefore - 1, [Name.Paragraph]);

                // Change types of Enter:Paragraph, Exit:Paragraph.
                tokenizer.events[paragraphEnter].name = Name.HeadingSetextText;
                tokenizer.events[paragraphExitBefore].name = Name.HeadingSetextText;

                // Add Enter:HeadingSetext, Exit:HeadingSetext.
                var headingEnter = tokenizer.events[paragraphEnter].clone();
                headingEnter.name = Name.HeadingSetext;
                tokenizer.map.add(paragraphEnter, 0, [headingEnter]);
                var headingExit = tokenizer.events[exit].clone();
                headingExit.name = Name.HeadingSetext;
                tokenizer.map.add(exit + 1, 0, [headingExit]);
            }
            // There's a following paragraph, move this underline inside it.
            else if (exit + 3 < tokenizer.events.length
                && tokenizer.events[exit + 1].name == Name.LineEnding
                && tokenizer.events[exit + 3].name == Name.Paragraph) {
                // Swap type, HeadingSetextUnderline:Enter -> Paragraph:Enter.
                tokenizer.events[enter].name = Name.Paragraph;
                // Swap type, LineEnding -> Data.
                tokenizer.events[exit + 1].name = Name.Data;
                tokenizer.events[exit + 2].name = Name.Data;
                // Move new data (was line ending) back to include whole line, and link data together.
                tokenizer.events[exit + 1].point = tokenizer.events[enter].point.clone();
                tokenizer.events[exit + 1].link = new Link(-1, exit + 4, Content.Text);
                tokenizer.events[exit + 4].link.previous = exit + 1;
                // Remove *including* HeadingSetextUnderline:Exit, until the line ending.
                tokenizer.map.add(enter + 1, exit - enter, []);
                // Remove old Paragraph:Enter.
                tokenizer.map.add(exit + 3, 1, []);
            }
            else {
                // Swap type.
                tokenizer.events[enter].name = Name.Paragraph;
                tokenizer.events[exit].name = Name.Paragraph;
                // Replace what's inside the underline (whitespace, sequence).
                tokenizer.map.add(enter + 1, exit - enter - 1, [
                    new Event(Kind.Enter, Name.Data, tokenizer.events[enter].point.clone(), new Link(-1, -1, Content.Text)),
                    new Event(Kind.Exit, Name.Data, tokenizer.events[exit].point.clone(), null),
                ]);
            }

            enter = Skip.to(tokenizer.events, exit + 1, [Name.HeadingSetextUnderline]);
        }

        tokenizer.map.consume(tokenizer.events);
        return null;
    }

}
