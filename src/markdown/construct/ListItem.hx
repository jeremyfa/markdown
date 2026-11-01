// Ported from markdown 1.0.0: src/construct/list_item.rs
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
import markdown.util.Slice;

/**
 * List item occurs in the document content type (`list_item.rs`).
 */
class ListItem {

    /** Start of list item. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.listItem) {
            tokenizer.enter(Name.ListItem);

            if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
                tokenizer.attempt(State.Next(StateName.ListItemBefore), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 0,
                    tokenizer.parseState.options.constructs.codeIndented ? Constant.TAB_SIZE - 1 : PartialSpaceOrTab.MAX));
            }
            else {
                return State.Retry(StateName.ListItemBefore);
            }
        }
        else {
            return State.Nok;
        }
    }

    /** After optional whitespace, at list item prefix. */
    public static function before(tokenizer:Tokenizer):State {
        // Unordered.
        if (tokenizer.current == '*'.code || tokenizer.current == '-'.code) {
            tokenizer.check(State.Nok, State.Next(StateName.ListItemBeforeUnordered));
            return State.Retry(StateName.ThematicBreakStart);
        }
        else if (tokenizer.current == '+'.code) {
            return State.Retry(StateName.ListItemBeforeUnordered);
        }
        // Ordered.
        else if (tokenizer.current == '1'.code || (tokenizer.current >= '0'.code && tokenizer.current <= '9'.code && !tokenizer.interrupt)) {
            return State.Retry(StateName.ListItemBeforeOrdered);
        }
        else {
            return State.Nok;
        }
    }

    /** At unordered list item marker. */
    public static function beforeUnordered(tokenizer:Tokenizer):State {
        tokenizer.enter(Name.ListItemPrefix);
        return State.Retry(StateName.ListItemMarker);
    }

    /** At ordered list item value. */
    public static function beforeOrdered(tokenizer:Tokenizer):State {
        tokenizer.enter(Name.ListItemPrefix);
        tokenizer.enter(Name.ListItemValue);
        return State.Retry(StateName.ListItemValue);
    }

    /** In ordered list item value. */
    public static function value(tokenizer:Tokenizer):State {
        if ((tokenizer.current == '.'.code || tokenizer.current == ')'.code) && (!tokenizer.interrupt || tokenizer.tokenizeState.size < 2)) {
            tokenizer.exit(Name.ListItemValue);
            return State.Retry(StateName.ListItemMarker);
        }
        else if (tokenizer.current >= '0'.code && tokenizer.current <= '9'.code && tokenizer.tokenizeState.size + 1 < Constant.LIST_ITEM_VALUE_SIZE_MAX) {
            tokenizer.tokenizeState.size += 1;
            tokenizer.consume();
            return State.Next(StateName.ListItemValue);
        }
        else {
            tokenizer.tokenizeState.size = 0;
            return State.Nok;
        }
    }

    /** At list item marker. */
    public static function marker(tokenizer:Tokenizer):State {
        tokenizer.enter(Name.ListItemMarker);
        tokenizer.consume();
        tokenizer.exit(Name.ListItemMarker);
        return State.Next(StateName.ListItemMarkerAfter);
    }

    /** After list item marker. */
    public static function markerAfter(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.size = 1;
        tokenizer.check(State.Next(StateName.ListItemAfter), State.Next(StateName.ListItemMarkerAfterFilled));
        return State.Retry(StateName.BlankLineStart);
    }

    /** After list item marker, not followed by a blank line. */
    public static function markerAfterFilled(tokenizer:Tokenizer):State {
        tokenizer.tokenizeState.size = 0;

        // Attempt to parse up to the largest allowed indent, `nok` if there is more whitespace.
        tokenizer.attempt(State.Next(StateName.ListItemAfter), State.Next(StateName.ListItemPrefixOther));
        return State.Retry(StateName.ListItemWhitespace);
    }

    /** After marker, at whitespace. */
    public static function whitespace(tokenizer:Tokenizer):State {
        tokenizer.attempt(State.Next(StateName.ListItemWhitespaceAfter), State.Nok);
        return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 1, Constant.TAB_SIZE));
    }

    /** After acceptable whitespace. */
    public static function whitespaceAfter(tokenizer:Tokenizer):State {
        return tokenizer.current == '\t'.code || tokenizer.current == ' '.code ? State.Nok : State.Ok;
    }

    /** After marker, followed by no indent or more indent that needed. */
    public static function prefixOther(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\t'.code | ' '.code:
                tokenizer.enter(Name.SpaceOrTab);
                tokenizer.consume();
                tokenizer.exit(Name.SpaceOrTab);
                return State.Next(StateName.ListItemAfter);
            default:
                return State.Nok;
        }
    }

    /** After list item prefix. */
    public static function after(tokenizer:Tokenizer):State {
        var blank = tokenizer.tokenizeState.size == 1;
        tokenizer.tokenizeState.size = 0;

        if (blank && tokenizer.interrupt) {
            return State.Nok;
        }
        else {
            var start = Skip.toBack(tokenizer.events, tokenizer.events.length - 1, [Name.ListItem]);
            var prefix = Slice.fromPoints(tokenizer.parseState.bytes, tokenizer.events[start].point, tokenizer.point).len();

            if (blank) {
                prefix += 1;
            }

            var container = tokenizer.tokenizeState.documentContainerStack[tokenizer.tokenizeState.documentContinued];

            container.blankInitial = blank;
            container.size = prefix;

            tokenizer.exit(Name.ListItemPrefix);
            tokenizer.registerResolverBefore(ResolveName.ListItem);
            return State.Ok;
        }
    }

    /** Start of list item continuation. */
    public static function contStart(tokenizer:Tokenizer):State {
        tokenizer.check(State.Next(StateName.ListItemContBlank), State.Next(StateName.ListItemContFilled));
        return State.Retry(StateName.BlankLineStart);
    }

    /** Start of blank list item continuation. */
    public static function contBlank(tokenizer:Tokenizer):State {
        var container = tokenizer.tokenizeState.documentContainerStack[tokenizer.tokenizeState.documentContinued];
        var size = container.size;

        if (container.blankInitial) {
            return State.Nok;
        }
        else if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            // Consume, optionally, at most `size`.
            return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 0, size));
        }
        else {
            return State.Ok;
        }
    }

    /** Start of non-blank list item continuation. */
    public static function contFilled(tokenizer:Tokenizer):State {
        var container = tokenizer.tokenizeState.documentContainerStack[tokenizer.tokenizeState.documentContinued];
        var size = container.size;

        container.blankInitial = false;

        if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            // Consume exactly `size`.
            return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, size, size));
        }
        else {
            return State.Nok;
        }
    }

    /** Find adjacent list items with the same marker. */
    public static function resolve(tokenizer:Tokenizer):Null<Subresult> {
        // Each list: marker, balance, start index, end index (flattened by 4).
        var listsWip:Array<Array<Int>> = [];
        var lists:Array<Array<Int>> = [];
        var index = 0;
        var balance = 0;

        // Merge list items.
        while (index < tokenizer.events.length) {
            var event = tokenizer.events[index];

            if (event.name == Name.ListItem) {
                if (event.kind == Kind.Enter) {
                    var end = Skip.opt(tokenizer.events, index, [Name.ListItem]) - 1;
                    var marker = Skip.to(tokenizer.events, index, [Name.ListItemMarker]);
                    // Guaranteed to be a valid ASCII byte.
                    var marker = tokenizer.parseState.bytes.get(tokenizer.events[marker].point.index);
                    var current = [marker, balance, index, end];

                    var listIndex = listsWip.length;
                    var matched = false;

                    while (listIndex > 0) {
                        listIndex -= 1;
                        var previous = listsWip[listIndex];
                        var before = Skip.opt(tokenizer.events, previous[3] + 1, [
                            Name.SpaceOrTab,
                            Name.LineEnding,
                            Name.BlankLineEnding,
                            Name.BlockQuotePrefix,
                        ]);

                        if (previous[0] == current[0] && previous[1] == current[1] && before == current[2]) {
                            previous[3] = current[3];
                            for (l in listsWip.splice(listIndex + 1, listsWip.length - listIndex - 1))
                                lists.push(l);
                            matched = true;
                            break;
                        }
                    }

                    if (!matched) {
                        var index = listsWip.length;
                        var exit = -1;

                        while (index > 0) {
                            index -= 1;

                            // If the current (new) item starts after where this item on the stack ends, we can remove it from the stack.
                            if (current[2] > listsWip[index][3]) {
                                exit = index;
                            }
                            else {
                                break;
                            }
                        }

                        if (exit != -1) {
                            for (l in listsWip.splice(exit, listsWip.length - exit))
                                lists.push(l);
                        }

                        listsWip.push(current);
                    }

                    balance += 1;
                }
                else {
                    balance -= 1;
                }
            }

            index += 1;
        }

        for (l in listsWip)
            lists.push(l);

        // Inject events.
        var index = 0;
        while (index < lists.length) {
            var listItem = lists[index];
            var listStart = tokenizer.events[listItem[2]].clone();
            var listEnd = tokenizer.events[listItem[3]].clone();
            var name = listItem[0] == '.'.code || listItem[0] == ')'.code ? Name.ListOrdered : Name.ListUnordered;
            listStart.name = name;
            listEnd.name = name;

            tokenizer.map.add(listItem[2], 0, [listStart]);
            tokenizer.map.add(listItem[3] + 1, 0, [listEnd]);

            index += 1;
        }

        tokenizer.map.consume(tokenizer.events);
        return null;
    }

}
