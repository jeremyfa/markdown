// Ported from markdown 1.0.0: src/util/infer.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown.util;

import markdown.event.Event;
import markdown.event.Kind;
import markdown.event.Name;
import markdown.mdast.AlignKind;

/**
 * Infer things from events (`infer.rs`).
 */
class Infer {

    /** Figure out if a list is spread or not. */
    public static function listLoose(events:Array<Event>, index:Int, includeItems:Bool):Bool {
        var balance = 0;
        var name = events[index].name;

        while (index < events.length) {
            var event = events[index];

            if (event.kind == Kind.Enter) {
                balance += 1;

                if (includeItems && balance == 2 && event.name == Name.ListItem && listItemLoose(events, index)) {
                    return true;
                }
            }
            else {
                balance -= 1;

                if (balance == 1 && event.name == Name.BlankLineEnding) {
                    // Blank line directly after a prefix:
                    var atEmptyListItem = false;
                    var atEmptyBlockQuote = false;
                    var before = index - 2;

                    if (events[before].name == Name.ListItem) {
                        before -= 1;

                        if (events[before].name == Name.SpaceOrTab) {
                            before -= 2;
                        }

                        if (events[before].name == Name.BlockQuote && events[before - 1].name == Name.BlockQuotePrefix) {
                            atEmptyBlockQuote = true;
                        }
                        else if (events[before].name == Name.ListItemPrefix) {
                            atEmptyListItem = true;
                        }
                    }

                    if (!atEmptyListItem && !atEmptyBlockQuote) {
                        return true;
                    }
                }

                // Done.
                if (balance == 0 && event.name == name) {
                    break;
                }
            }

            index += 1;
        }

        return false;
    }

    /** Figure out if an item is spread or not. */
    public static function listItemLoose(events:Array<Event>, index:Int):Bool {
        var balance = 0;

        while (index < events.length) {
            var event = events[index];

            if (event.kind == Kind.Enter) {
                balance += 1;
            }
            else {
                balance -= 1;

                if (balance == 1 && event.name == Name.BlankLineEnding) {
                    // Blank line directly after a prefix:
                    var atPrefix = false;
                    var before = index - 2;

                    if (events[before].name == Name.SpaceOrTab) {
                        before -= 2;
                    }

                    if (events[before].name == Name.ListItemPrefix) {
                        atPrefix = true;
                    }

                    if (!atPrefix) {
                        return true;
                    }
                }

                // Done.
                if (balance == 0 && event.name == Name.ListItem) {
                    break;
                }
            }

            index += 1;
        }

        return false;
    }

    /** Figure out the alignment of a GFM table. */
    public static function gfmTableAlign(events:Array<Event>, index:Int):Array<AlignKind> {
        var inDelimiterRow = false;
        var align:Array<AlignKind> = [];

        while (index < events.length) {
            var event = events[index];

            if (inDelimiterRow) {
                if (event.kind == Kind.Enter) {
                    // Start of alignment value: set a new column.
                    if (event.name == Name.GfmTableDelimiterCellValue) {
                        align.push(events[index + 1].name == Name.GfmTableDelimiterMarker ? AlignKind.Left : AlignKind.None);
                    }
                }
                else {
                    // End of alignment value: change the column.
                    if (event.name == Name.GfmTableDelimiterCellValue) {
                        if (events[index - 1].name == Name.GfmTableDelimiterMarker) {
                            var alignIndex = align.length - 1;
                            align[alignIndex] = align[alignIndex] == AlignKind.Left ? AlignKind.Center : AlignKind.Right;
                        }
                    }
                    // Done!
                    else if (event.name == Name.GfmTableDelimiterRow) {
                        break;
                    }
                }
            }
            else if (event.kind == Kind.Enter && event.name == Name.GfmTableDelimiterRow) {
                inDelimiterRow = true;
            }

            index += 1;
        }

        return align;
    }

}
