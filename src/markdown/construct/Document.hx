// Ported from markdown 1.0.0: src/construct/document.rs
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
import markdown.message.Message;
import markdown.util.Skip;

/** Phases where we can exit containers. */
private enum abstract Phase(Int) {
    /** After parsing a line of lazy flow which resulted in something that exits containers before the line. */
    var After = 0;
    /** When a new container replaces an existing container. */
    var Prefix = 1;
    /** After everything. */
    var Eof = 2;
}

/**
 * The document content type (`document.rs`).
 */
class Document {

    /** Start of document, at an optional BOM. */
    public static function start(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.documentChild = new Tokenizer(tokenizer.point.clone(), tokenizer.parseState);

        tokenizer.attempt(State.Next(StateName.DocumentBeforeFrontmatter), State.Next(StateName.DocumentBeforeFrontmatter));

        return State.Retry(StateName.BomStart);
    }

    /** At optional frontmatter. */
    public static function beforeFrontmatter(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.DocumentContainerNewBefore), State.Next(StateName.DocumentContainerNewBefore));
        return State.Retry(StateName.FrontmatterStart);
    }

    /** At optional existing containers. */
    public static function containerExistingBefore(tokenizer:Tokenizer):State {
        // If there are more existing containers, check whether the next one continues.
        if (tokenizer.tokenizeState.documentContinued < tokenizer.tokenizeState.documentContainerStack.length) {
            var container = tokenizer.tokenizeState.documentContainerStack[tokenizer.tokenizeState.documentContinued];

            var name = switch container.kind {
                case BlockQuote: StateName.BlockQuoteContStart;
                case GfmFootnoteDefinition: StateName.GfmFootnoteDefinitionContStart;
                case ListItem: StateName.ListItemContStart;
            };

            tokenizer.attempt(State.Next(StateName.DocumentContainerExistingAfter), State.Next(StateName.DocumentContainerNewBefore));

            return State.Retry(name);
        }
        // Otherwise, check new containers.
        else {
            return State.Retry(StateName.DocumentContainerNewBefore);
        }
    }

    /** After continued existing container. */
    public static function containerExistingAfter(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.documentContinued += 1;
        return State.Retry(StateName.DocumentContainerExistingBefore);
    }

    /** At new containers. */
    public static function containerNewBefore(tokenizer:Tokenizer):State {
        // If we have completely continued, restore the flow's past `interrupt` status.
        if (tokenizer.tokenizeState.documentContinued == tokenizer.tokenizeState.documentContainerStack.length) {
            var child = tokenizer.tokenizeState.documentChild;

            tokenizer.interrupt = child.interrupt;

            // …and if we're in a concrete construct, new containers can't "pierce" into them.
            if (child.concrete) {
                return State.Retry(StateName.DocumentContainersAfter);
            }
        }

        // Check for a new container.
        // Block quote?
        // Add a new container at the end of the stack.
        var stack = tokenizer.tokenizeState.documentContainerStack;
        var tail = stack.length;
        stack.push(new ContainerState(Container.BlockQuote, false, 0));
        // Swap the existing container with the new one.
        var a = tokenizer.tokenizeState.documentContinued;
        var tmp = stack[a];
        stack[a] = stack[tail];
        stack[tail] = tmp;

        tokenizer.attempt(State.Next(StateName.DocumentContainerNewAfter), State.Next(StateName.DocumentContainerNewBeforeNotBlockQuote));
        return State.Retry(StateName.BlockQuoteStart);
    }

    /** At new container, but not a block quote. */
    public static function containerNewBeforeNotBlockQuote(tokenizer:Tokenizer):State {
        // List item?
        // We replace the empty block quote container for this new list one.
        tokenizer.tokenizeState.documentContainerStack[tokenizer.tokenizeState.documentContinued] = new ContainerState(Container.ListItem, false, 0);

        tokenizer.attempt(State.Next(StateName.DocumentContainerNewAfter), State.Next(StateName.DocumentContainerNewBeforeNotList));
        return State.Retry(StateName.ListItemStart);
    }

    /** At new container, but not a block quote or list item. */
    public static function containerNewBeforeNotList(tokenizer:Tokenizer):State {
        // Footnote definition?
        // We replace the empty list item container for this new footnote one.
        tokenizer.tokenizeState.documentContainerStack[tokenizer.tokenizeState.documentContinued] = new ContainerState(Container.GfmFootnoteDefinition, false, 0);

        tokenizer.attempt(State.Next(StateName.DocumentContainerNewAfter), State.Next(StateName.DocumentContainerNewBeforeNotGfmFootnoteDefinition));
        return State.Retry(StateName.GfmFootnoteDefinitionStart);
    }

    /** At new container, but not a block quote, list item, or footnote definition. */
    public static function containerNewBeforeNotFootnoteDefinition(tokenizer:Tokenizer):State {
        // It wasn't a new block quote, list item, or footnote definition.
        // Swap the new container (in the middle) with the existing one (at the end).
        // Take the last container.
        swapRemove(tokenizer.tokenizeState.documentContainerStack, tokenizer.tokenizeState.documentContinued);

        return State.Retry(StateName.DocumentContainersAfter);
    }

    /** After new container. */
    public static function containerNewAfter(tokenizer:Tokenizer):State {
        // It was a new block quote, list item, or footnote definition.
        // Swap the new container (in the middle) with the existing one (at the end).
        var container = swapRemove(tokenizer.tokenizeState.documentContainerStack, tokenizer.tokenizeState.documentContinued);

        // If we did not continue all existing containers, and there is a new one, close the flow and those containers.
        if (tokenizer.tokenizeState.documentContinued != tokenizer.tokenizeState.documentContainerStack.length) {
            try {
                exitContainers(tokenizer, Phase.Prefix);
            }
            catch (message:Message) {
                return State.error(message);
            }
        }

        // We are "piercing" into the flow with a new container.
        tokenizer.tokenizeState.documentChild.pierce = true;

        tokenizer.tokenizeState.documentContainerStack.push(container);
        tokenizer.tokenizeState.documentContinued += 1;
        tokenizer.interrupt = false;
        return State.Retry(StateName.DocumentContainerNewBefore);
    }

    /** After containers, at flow. */
    public static function containersAfter(tokenizer:Tokenizer):State {
        var child = tokenizer.tokenizeState.documentChild;

        child.lazy = tokenizer.tokenizeState.documentContinued != tokenizer.tokenizeState.documentContainerStack.length;
        child.defineSkip(tokenizer.point.clone());

        if (tokenizer.current == -1) {
            return State.Retry(StateName.DocumentFlowEnd);
        }
        else {
            var current = tokenizer.events.length;
            var previous = tokenizer.tokenizeState.documentDataIndex;
            if (previous != -1) {
                tokenizer.events[previous].link.next = current;
            }
            tokenizer.tokenizeState.documentDataIndex = current;
            tokenizer.enterLink(Name.Data, new Link(previous, -1, Content.Flow));
            return State.Retry(StateName.DocumentFlowInside);
        }
    }

    /** In flow. */
    public static function flowInside(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1:
                tokenizer.exit(Name.Data);
                return State.Retry(StateName.DocumentFlowEnd);
            // Note: EOL is part of data.
            case '\n'.code:
                tokenizer.consume();
                tokenizer.exit(Name.Data);
                return State.Next(StateName.DocumentFlowEnd);
            default:
                tokenizer.consume();
                return State.Next(StateName.DocumentFlowInside);
        }
    }

    /** After flow (after eol or at eof). */
    public static function flowEnd(tokenizer:Tokenizer):State {
        var child = tokenizer.tokenizeState.documentChild;
        var state = tokenizer.tokenizeState.documentChildState;
        tokenizer.tokenizeState.documentChildState = null;
        if (state == null)
            state = State.Next(StateName.FlowStart);

        tokenizer.tokenizeState.documentExits.push(null);

        var state = child.push(child.point.index, child.point.vs, tokenizer.point.index, tokenizer.point.vs, state);

        tokenizer.tokenizeState.documentChildState = state;

        var documentLazyContinuationCurrent = false;
        var stackIndex = child.stack.length;

        // Use two algo's: one for when we're suspended or in multiline things like definitions, another for when we fed the line ending and closed.
        while (!documentLazyContinuationCurrent && stackIndex > 0) {
            stackIndex -= 1;
            var name = child.stack[stackIndex];
            if (name == Name.Content || name == Name.GfmTableHead) {
                documentLazyContinuationCurrent = true;
            }
        }

        // …another because we parse each "rest" line as a paragraph, and we passed a EOL already.
        if (!documentLazyContinuationCurrent && child.events.length > 0) {
            var before = Skip.optBack(child.events, child.events.length - 1, [Name.LineEnding]);
            var name = child.events[before].name;
            if (name == Name.Content || name == Name.HeadingSetextUnderline) {
                documentLazyContinuationCurrent = true;
            }
        }

        // Reset "piercing".
        child.pierce = false;

        if (child.lazy && tokenizer.tokenizeState.documentLazyAcceptingBefore && documentLazyContinuationCurrent) {
            tokenizer.tokenizeState.documentContinued = tokenizer.tokenizeState.documentContainerStack.length;
        }

        if (tokenizer.tokenizeState.documentContinued != tokenizer.tokenizeState.documentContainerStack.length) {
            exitContainers(tokenizer, Phase.After);
        }

        if (tokenizer.current == -1) {
            tokenizer.tokenizeState.documentContinued = 0;
            try {
                exitContainers(tokenizer, Phase.Eof);
            }
            catch (message:Message) {
                return State.error(message);
            }
            resolve(tokenizer);
            return State.Ok;
        }
        else {
            tokenizer.tokenizeState.documentContinued = 0;
            tokenizer.tokenizeState.documentLazyAcceptingBefore = documentLazyContinuationCurrent;
            // Containers would only be interrupting if we've continued.
            tokenizer.interrupt = false;
            return State.Retry(StateName.DocumentContainerExistingBefore);
        }
    }

    /** `Vec::swap_remove`. */
    static function swapRemove<T>(list:Array<T>, index:Int):T {
        var value = list[index];
        var last = list.pop();
        if (index < list.length)
            list[index] = last;
        return value;
    }

    /** Close containers (and flow if needed). Throws a `Message` on error. */
    static function exitContainers(tokenizer:Tokenizer, phase:Phase):Void {
        var stack = tokenizer.tokenizeState.documentContainerStack;
        var continued = tokenizer.tokenizeState.documentContinued;
        var stackClose = stack.splice(continued, stack.length - continued);
        var child = tokenizer.tokenizeState.documentChild;

        // Flush if needed.
        if (phase != Phase.After) {
            var state = tokenizer.tokenizeState.documentChildState;
            tokenizer.tokenizeState.documentChildState = null;
            if (state == null)
                state = State.Next(StateName.FlowStart);

            child.flush(state, false);
        }

        if (stackClose.length > 0) {
            var index = tokenizer.tokenizeState.documentExits.length - (phase == Phase.After ? 2 : 1);
            var exits:Array<Event> = [];

            while (stackClose.length > 0) {
                var container = stackClose.pop();
                var name = switch container.kind {
                    case BlockQuote: Name.BlockQuote;
                    case GfmFootnoteDefinition: Name.GfmFootnoteDefinition;
                    case ListItem: Name.ListItem;
                };

                exits.push(new Event(Kind.Exit, name, tokenizer.point.clone(), null));

                var stackIndex = tokenizer.stack.length;
                while (stackIndex > 0) {
                    stackIndex -= 1;

                    if (tokenizer.stack[stackIndex] == name) {
                        tokenizer.stack.splice(stackIndex, 1);
                        break;
                    }
                }
            }

            tokenizer.tokenizeState.documentExits[index] = exits;
        }

        child.interrupt = false;
    }

    /** Inject everything together. */
    static function resolve(tokenizer:Tokenizer):Void {
        var child = tokenizer.tokenizeState.documentChild;

        // First, add the container exits into `child`.
        var childIndex = 0;
        var line = 0;

        while (childIndex < child.events.length) {
            if (child.events[childIndex].kind == Kind.Exit
                && (child.events[childIndex].name == Name.LineEnding || child.events[childIndex].name == Name.BlankLineEnding)) {
                // Inject before `Enter:LineEnding`.
                var injectIndex = childIndex - 1;
                var point = child.events[injectIndex].point;

                while (childIndex + 1 < child.events.length && child.events[childIndex + 1].kind == Kind.Exit) {
                    childIndex += 1;
                    point = child.events[childIndex].point;
                    // Inject after `Exit:*`.
                    injectIndex = childIndex + 1;
                }

                if (line < tokenizer.tokenizeState.documentExits.length) {
                    var exits = tokenizer.tokenizeState.documentExits[line];
                    if (exits != null) {
                        tokenizer.tokenizeState.documentExits[line] = null;
                        for (exit in exits) {
                            exit.point = point.clone();
                        }

                        child.map.add(injectIndex, 0, exits);
                    }
                }

                line += 1;
            }

            childIndex += 1;
        }

        child.map.consume(child.events);

        var flowIndex = Skip.to(tokenizer.events, 0, [Name.Data]);
        // To do: share this code with `subtokenize`.
        // Now, add all child events into our parent document tokenizer.
        while (flowIndex < tokenizer.events.length
            && (tokenizer.events[flowIndex].link == null || tokenizer.events[flowIndex].link.content != Content.Flow)) {
            flowIndex = Skip.to(tokenizer.events, flowIndex + 1, [Name.Data]);
        }

        Subtokenize.divideEvents(tokenizer.map, tokenizer.events, flowIndex, child.events, 0, 0);

        // Replace the flow data with actual events.
        tokenizer.map.consume(tokenizer.events);

        // Now, add some final container exits due to the EOF.
        // We can't inject them into the child earlier, as they are "outside" its linked data.
        if (line < tokenizer.tokenizeState.documentExits.length) {
            var exits = tokenizer.tokenizeState.documentExits[line];
            if (exits != null) {
                tokenizer.tokenizeState.documentExits[line] = null;
                for (exit in exits) {
                    exit.point = tokenizer.point.clone();
                }

                for (exit in exits)
                    tokenizer.events.push(exit);
            }
        }

        // Add the resolvers from child.
        for (r in child.resolvers)
            tokenizer.resolvers.push(r);
        child.resolvers = [];
        for (d in child.tokenizeState.definitions)
            tokenizer.tokenizeState.definitions.push(d);
        child.tokenizeState.definitions = [];
    }

}
