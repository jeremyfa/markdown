// Ported from markdown 1.0.0: src/subtokenize.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown;

import markdown.event.Event;
import markdown.event.Kind;
import markdown.event.Name;
import markdown.state.State;
import markdown.state.StateName;
import markdown.event.Content;
import markdown.util.EditMap;
import markdown.Parser;
import markdown.util.Skip;

/**
 * Deal with content in other content (`subtokenize.rs`).
 */
class Subtokenize {

    /** Link two `Event`s. */
    public static inline function link(events:Array<Event>, index:Int):Void {
        linkTo(events, index - 2, index);
    }

    /** Link two arbitrary `Event`s together. */
    public static function linkTo(events:Array<Event>, previous:Int, next:Int):Void {
        events[previous].link.next = next;
        events[next].link.previous = previous;
    }

    /** Parse linked events. Throws a `Message` on error. */
    public static function subtokenize(events:Array<Event>, parseState:ParseState, filter:Null<Content>):Subresult {
        var map = new EditMap();
        var index = 0;
        var value = new Subresult(true, [], []);
        var acc0 = 0;
        var acc1 = 0;

        while (index < events.length) {
            var event = events[index];

            // Find each first opening chunk.
            if (event.link != null) {
                var link = event.link;
                // No need to enter linked events again.
                if (link.previous == -1 && (filter == null || link.content == filter)) {
                    // Index into `events` pointing to a chunk.
                    var linkIndex = index;
                    // Subtokenizer.
                    var tokenizer = new Tokenizer(event.point.clone(), parseState);
                    // Substate.
                    var state = State.Next(switch link.content {
                        case Content.Content: StateName.ContentDefinitionBefore;
                        case Content.String: StateName.StringStart;
                        default: StateName.TextStart;
                    });

                    // Check if this is the first paragraph, after list item prefix.
                    if (tokenizer.parseState.options.constructs.gfmTaskListItem
                        && index > 2
                        && events[index - 1].kind == Kind.Enter
                        && events[index - 1].name == Name.Paragraph) {
                        var before = Skip.optBack(events, index - 2, [Name.BlankLineEnding, Name.Definition, Name.LineEnding, Name.SpaceOrTab]);

                        if (events[before].kind == Kind.Exit && events[before].name == Name.ListItemPrefix) {
                            tokenizer.tokenizeState.documentAtFirstParagraphOfListItem = true;
                        }
                    }

                    // Loop through links to pass them in order to the subtokenizer.
                    while (linkIndex != -1) {
                        var enter = events[linkIndex];
                        var linkCurr = enter.link;

                        if (linkCurr.previous != -1) {
                            tokenizer.defineSkip(enter.point);
                        }

                        var end = events[linkIndex + 1].point;

                        state = tokenizer.push(enter.point.index, enter.point.vs, end.index, end.vs, state);

                        linkIndex = linkCurr.next;
                    }

                    var result = tokenizer.flush(state, true);
                    for (d in result.gfmFootnoteDefinitions)
                        value.gfmFootnoteDefinitions.push(d);
                    for (d in result.definitions)
                        value.definitions.push(d);
                    value.done = false;

                    var acc = divideEvents(map, events, index, tokenizer.events, acc0, acc1);
                    acc0 = acc[0];
                    acc1 = acc[1];
                }
            }

            index += 1;
        }

        map.consume(events);

        return value;
    }

    /** Divide `child_events` over links in `events`, the first of which is at `link_index`. */
    public static function divideEvents(map:EditMap, events:Array<Event>, linkIndex:Int, childEvents:Array<Event>, accBefore0:Int, accBefore1:Int):Array<Int> {
        var childIndex = 0;
        var slices:Array<Int> = []; // Pairs of (link index, slice start), flattened.
        var sliceStart = 0;
        var oldPrev = -1;
        var len = childEvents.length;

        while (childIndex < len) {
            var current = childEvents[childIndex].point;
            var end = events[linkIndex + 1].point;

            // Find the first event that starts after the end we're looking for.
            if (current.index > end.index || (current.index == end.index && current.vs > end.vs)) {
                slices.push(linkIndex);
                slices.push(sliceStart);
                sliceStart = childIndex;
                linkIndex = events[linkIndex].link.next;
            }

            // Fix sublinks.
            var sublinkCurr = childEvents[childIndex].link;
            if (sublinkCurr != null) {
                if (sublinkCurr.previous != -1) {
                    var prevEvent = childEvents[oldPrev];
                    // The `index` in `events` where the current link is, minus 2 events (the enter and exit) for each removed link.
                    var newLink = slices.length == 0 ? oldPrev + linkIndex + 2 : oldPrev + linkIndex - (Std.int(slices.length / 2) - 1) * 2;
                    prevEvent.link.next = newLink + accBefore1 - accBefore0;
                }
            }

            // If there is a `next` link in the subevents, we have to change its `previous` index to account for the shifted events.
            if (sublinkCurr != null) {
                var next = sublinkCurr.next;
                if (next != -1) {
                    var sublinkNext = childEvents[next].link;
                    oldPrev = sublinkNext.previous;
                    if (sublinkNext.previous != -1) {
                        sublinkNext.previous = sublinkNext.previous + linkIndex - (Std.int(slices.length / 2) * 2) + accBefore1 - accBefore0;
                    }
                }
            }

            childIndex += 1;
        }

        if (childEvents.length > 0) {
            slices.push(linkIndex);
            slices.push(sliceStart);
        }

        // Finally, inject the subevents.
        var index = Std.int(slices.length / 2);

        while (index > 0) {
            index -= 1;
            var start = slices[index * 2 + 1];
            map.add(slices[index * 2], 2, childEvents.splice(start, childEvents.length - start));
        }

        return [accBefore0 + (Std.int(slices.length / 2) * 2), accBefore1 + len];
    }

}
