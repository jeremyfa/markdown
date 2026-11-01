// Ported from markdown 1.0.0: src/construct/gfm_table.rs
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
 * GFM: table occurs in the flow content type (`gfm_table.rs`).
 */
class GfmTable {

    /** Start of a GFM table. */
    public static function start(tokenizer:Tokenizer):State {
        if (tokenizer.parseState.options.constructs.gfmTable) {
            if (!tokenizer.pierce && tokenizer.events.length > 0 && {
                var name = tokenizer.events[Skip.optBack(tokenizer.events, tokenizer.events.length - 1, [Name.LineEnding, Name.SpaceOrTab])].name;
                name == Name.GfmTableHead || name == Name.GfmTableRow;
            }) {
                return State.Retry(StateName.GfmTableBodyRowStart);
            }
            else {
                return State.Retry(StateName.GfmTableHeadRowBefore);
            }
        }
        else {
            return State.Nok;
        }
    }

    /** Before table head row. */
    public static function headRowBefore(tokenizer:Tokenizer):State {
        tokenizer.enter(Name.GfmTableHead);
        tokenizer.enter(Name.GfmTableRow);
        if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            tokenizer.attempt(State.Next(StateName.GfmTableHeadRowStart), State.Nok);
            return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 0,
                tokenizer.parseState.options.constructs.codeIndented ? Constant.TAB_SIZE - 1 : PartialSpaceOrTab.MAX));
        }
        else {
            return State.Retry(StateName.GfmTableHeadRowStart);
        }
    }

    /** Before table head row, after whitespace. */
    public static function headRowStart(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            // 4+ spaces.
            case '\t'.code | ' '.code:
                return State.Nok;
            case '|'.code:
                return State.Retry(StateName.GfmTableHeadRowBreak);
            default:
                tokenizer.tokenizeState.seen = true;
                // Count the first character, that isn't a pipe, double.
                tokenizer.tokenizeState.sizeB += 1;
                return State.Retry(StateName.GfmTableHeadRowBreak);
        }
    }

    /** At break in table head row. */
    public static function headRowBreak(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1:
                tokenizer.tokenizeState.seen = false;
                tokenizer.tokenizeState.size = 0;
                tokenizer.tokenizeState.sizeB = 0;
                return State.Nok;
            case '\n'.code:
                // If anything other than one pipe (ignoring whitespace) was used, it's fine.
                if (tokenizer.tokenizeState.sizeB > 1) {
                    tokenizer.tokenizeState.sizeB = 0;
                    // Feel free to interrupt:
                    tokenizer.interrupt = true;
                    tokenizer.exit(Name.GfmTableRow);
                    tokenizer.enter(Name.LineEnding);
                    tokenizer.consume();
                    tokenizer.exit(Name.LineEnding);
                    return State.Next(StateName.GfmTableHeadDelimiterStart);
                }
                else {
                    tokenizer.tokenizeState.seen = false;
                    tokenizer.tokenizeState.size = 0;
                    tokenizer.tokenizeState.sizeB = 0;
                    return State.Nok;
                }
            case '\t'.code | ' '.code:
                tokenizer.attempt(State.Next(StateName.GfmTableHeadRowBreak), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
            default:
                tokenizer.tokenizeState.sizeB += 1;

                // Whether a delimiter was seen.
                if (tokenizer.tokenizeState.seen) {
                    tokenizer.tokenizeState.seen = false;
                    // Header cell count.
                    tokenizer.tokenizeState.size += 1;
                }

                if (tokenizer.current == '|'.code) {
                    tokenizer.enter(Name.GfmTableCellDivider);
                    tokenizer.consume();
                    tokenizer.exit(Name.GfmTableCellDivider);
                    // Whether a delimiter was seen.
                    tokenizer.tokenizeState.seen = true;
                    return State.Next(StateName.GfmTableHeadRowBreak);
                }
                else {
                    // Anything else is cell data.
                    tokenizer.enter(Name.Data);
                    return State.Retry(StateName.GfmTableHeadRowData);
                }
        }
    }

    /** In table head row data. */
    public static function headRowData(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\t'.code | '\n'.code | ' '.code | '|'.code:
                tokenizer.exit(Name.Data);
                return State.Retry(StateName.GfmTableHeadRowBreak);
            default:
                var name = tokenizer.current == '\\'.code ? StateName.GfmTableHeadRowEscape : StateName.GfmTableHeadRowData;
                tokenizer.consume();
                return State.Next(name);
        }
    }

    /** In table head row escape. */
    public static function headRowEscape(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\\'.code | '|'.code:
                tokenizer.consume();
                return State.Next(StateName.GfmTableHeadRowData);
            default:
                return State.Retry(StateName.GfmTableHeadRowData);
        }
    }

    /** Before delimiter row. */
    public static function headDelimiterStart(tokenizer:Tokenizer):State {
        // Reset `interrupt`.
        tokenizer.interrupt = false;

        if (tokenizer.lazy || tokenizer.pierce) {
            tokenizer.tokenizeState.size = 0;
            return State.Nok;
        }
        else {
            tokenizer.enter(Name.GfmTableDelimiterRow);
            // Track if we've seen a `:` or `|`.
            tokenizer.tokenizeState.seen = false;

            switch tokenizer.current {
                case '\t'.code | ' '.code:
                    tokenizer.attempt(State.Next(StateName.GfmTableHeadDelimiterBefore), State.Next(StateName.GfmTableHeadDelimiterNok));
                    return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 0,
                        tokenizer.parseState.options.constructs.codeIndented ? Constant.TAB_SIZE - 1 : PartialSpaceOrTab.MAX));
                default:
                    return State.Retry(StateName.GfmTableHeadDelimiterBefore);
            }
        }
    }

    /** Before delimiter row, after optional whitespace. */
    public static function headDelimiterBefore(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '-'.code | ':'.code:
                return State.Retry(StateName.GfmTableHeadDelimiterValueBefore);
            case '|'.code:
                tokenizer.tokenizeState.seen = true;
                // If we start with a pipe, we open a cell marker.
                tokenizer.enter(Name.GfmTableCellDivider);
                tokenizer.consume();
                tokenizer.exit(Name.GfmTableCellDivider);
                return State.Next(StateName.GfmTableHeadDelimiterCellBefore);
            // More whitespace / empty row not allowed at start.
            default:
                return State.Retry(StateName.GfmTableHeadDelimiterNok);
        }
    }

    /** After `|`, before delimiter cell. */
    public static function headDelimiterCellBefore(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\t'.code | ' '.code:
                tokenizer.attempt(State.Next(StateName.GfmTableHeadDelimiterValueBefore), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
            default:
                return State.Retry(StateName.GfmTableHeadDelimiterValueBefore);
        }
    }

    /** Before delimiter cell value. */
    public static function headDelimiterValueBefore(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                return State.Retry(StateName.GfmTableHeadDelimiterCellAfter);
            case ':'.code:
                // Align: left.
                tokenizer.tokenizeState.sizeB += 1;
                tokenizer.tokenizeState.seen = true;
                tokenizer.enter(Name.GfmTableDelimiterMarker);
                tokenizer.consume();
                tokenizer.exit(Name.GfmTableDelimiterMarker);
                return State.Next(StateName.GfmTableHeadDelimiterLeftAlignmentAfter);
            case '-'.code:
                // Align: none.
                tokenizer.tokenizeState.sizeB += 1;
                return State.Retry(StateName.GfmTableHeadDelimiterLeftAlignmentAfter);
            default:
                return State.Retry(StateName.GfmTableHeadDelimiterNok);
        }
    }

    /** After delimiter cell left alignment marker. */
    public static function headDelimiterLeftAlignmentAfter(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '-'.code:
                tokenizer.enter(Name.GfmTableDelimiterFiller);
                return State.Retry(StateName.GfmTableHeadDelimiterFiller);
            // Anything else is not ok after the left-align colon.
            default:
                return State.Retry(StateName.GfmTableHeadDelimiterNok);
        }
    }

    /** In delimiter cell filler. */
    public static function headDelimiterFiller(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '-'.code:
                tokenizer.consume();
                return State.Next(StateName.GfmTableHeadDelimiterFiller);
            case ':'.code:
                // Align is `center` if it was `left`, `right` otherwise.
                tokenizer.tokenizeState.seen = true;
                tokenizer.exit(Name.GfmTableDelimiterFiller);
                tokenizer.enter(Name.GfmTableDelimiterMarker);
                tokenizer.consume();
                tokenizer.exit(Name.GfmTableDelimiterMarker);
                return State.Next(StateName.GfmTableHeadDelimiterRightAlignmentAfter);
            default:
                tokenizer.exit(Name.GfmTableDelimiterFiller);
                return State.Retry(StateName.GfmTableHeadDelimiterRightAlignmentAfter);
        }
    }

    /** After delimiter cell right alignment marker. */
    public static function headDelimiterRightAlignmentAfter(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\t'.code | ' '.code:
                tokenizer.attempt(State.Next(StateName.GfmTableHeadDelimiterCellAfter), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
            default:
                return State.Retry(StateName.GfmTableHeadDelimiterCellAfter);
        }
    }

    /** After delimiter cell. */
    public static function headDelimiterCellAfter(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                // Exit when:
                // * there was no `:` or `|` at all (it's a thematic break or setext underline instead)
                // * the header cell count is not the delimiter cell count
                if (!tokenizer.tokenizeState.seen || tokenizer.tokenizeState.size != tokenizer.tokenizeState.sizeB) {
                    return State.Retry(StateName.GfmTableHeadDelimiterNok);
                }
                else {
                    // Reset.
                    tokenizer.tokenizeState.seen = false;
                    tokenizer.tokenizeState.size = 0;
                    tokenizer.tokenizeState.sizeB = 0;
                    tokenizer.exit(Name.GfmTableDelimiterRow);
                    tokenizer.exit(Name.GfmTableHead);
                    tokenizer.registerResolver(ResolveName.GfmTable);
                    return State.Ok;
                }
            case '|'.code:
                return State.Retry(StateName.GfmTableHeadDelimiterBefore);
            default:
                return State.Retry(StateName.GfmTableHeadDelimiterNok);
        }
    }

    /** In delimiter row, at a disallowed byte. */
    public static function headDelimiterNok(tokenizer:Tokenizer):State {
        // Reset.
        tokenizer.tokenizeState.seen = false;
        tokenizer.tokenizeState.size = 0;
        tokenizer.tokenizeState.sizeB = 0;
        return State.Nok;
    }

    /** Before table body row. */
    public static function bodyRowStart(tokenizer:Tokenizer):State {
        if (tokenizer.lazy) {
            return State.Nok;
        }
        else {
            tokenizer.enter(Name.GfmTableRow);

            switch tokenizer.current {
                case '\t'.code | ' '.code:
                    tokenizer.attempt(State.Next(StateName.GfmTableBodyRowBreak), State.Nok);
                    // We're parsing a body row.
                    // If we're here, we already attempted blank lines and indented code.
                    // So parse as much whitespace as needed:
                    return State.Retry(PartialSpaceOrTab.spaceOrTabMinMax(tokenizer, 0, PartialSpaceOrTab.MAX));
                default:
                    return State.Retry(StateName.GfmTableBodyRowBreak);
            }
        }
    }

    /** At break in table body row. */
    public static function bodyRowBreak(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\n'.code:
                tokenizer.exit(Name.GfmTableRow);
                return State.Ok;
            case '\t'.code | ' '.code:
                tokenizer.attempt(State.Next(StateName.GfmTableBodyRowBreak), State.Nok);
                return State.Retry(PartialSpaceOrTab.spaceOrTab(tokenizer));
            case '|'.code:
                tokenizer.enter(Name.GfmTableCellDivider);
                tokenizer.consume();
                tokenizer.exit(Name.GfmTableCellDivider);
                return State.Next(StateName.GfmTableBodyRowBreak);
            // Anything else is cell content.
            default:
                tokenizer.enter(Name.Data);
                return State.Retry(StateName.GfmTableBodyRowData);
        }
    }

    /** In table body row data. */
    public static function bodyRowData(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1 | '\t'.code | '\n'.code | ' '.code | '|'.code:
                tokenizer.exit(Name.Data);
                return State.Retry(StateName.GfmTableBodyRowBreak);
            default:
                var name = tokenizer.current == '\\'.code ? StateName.GfmTableBodyRowEscape : StateName.GfmTableBodyRowData;
                tokenizer.consume();
                return State.Next(name);
        }
    }

    /** In table body row escape. */
    public static function bodyRowEscape(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case '\\'.code | '|'.code:
                tokenizer.consume();
                return State.Next(StateName.GfmTableBodyRowData);
            default:
                return State.Retry(StateName.GfmTableBodyRowData);
        }
    }

    /** Resolve GFM table. */
    public static function resolve(tokenizer:Tokenizer):Null<Subresult> {
        var index = 0;
        var inFirstCellAwaitingPipe = true;
        var inRow = false;
        var inDelimiterRow = false;
        var lastCell = [0, 0, 0, 0];
        var cell = [0, 0, 0, 0];
        var afterHeadAwaitingFirstBodyRow = false;
        var lastTableEnd = 0;
        var lastTableHasBody = false;

        while (index < tokenizer.events.length) {
            var event = tokenizer.events[index];

            if (event.kind == Kind.Enter) {
                // Start of head.
                if (event.name == Name.GfmTableHead) {
                    afterHeadAwaitingFirstBodyRow = false;

                    // Inject previous (body end and) table end.
                    if (lastTableEnd != 0) {
                        flushTableEnd(tokenizer, lastTableEnd, lastTableHasBody);
                        lastTableHasBody = false;
                        lastTableEnd = 0;
                    }

                    // Inject table start.
                    tokenizer.map.add(index, 0, [new Event(Kind.Enter, Name.GfmTable, tokenizer.events[index].point.clone(), null)]);
                }
                // Start of row.
                else if (event.name == Name.GfmTableRow || event.name == Name.GfmTableDelimiterRow) {
                    inDelimiterRow = event.name == Name.GfmTableDelimiterRow;
                    inRow = true;
                    inFirstCellAwaitingPipe = true;
                    lastCell = [0, 0, 0, 0];
                    cell = [0, index + 1, 0, 0];

                    // Inject table body start.
                    if (afterHeadAwaitingFirstBodyRow) {
                        afterHeadAwaitingFirstBodyRow = false;
                        lastTableHasBody = true;
                        tokenizer.map.add(index, 0, [new Event(Kind.Enter, Name.GfmTableBody, tokenizer.events[index].point.clone(), null)]);
                    }
                }
                // Cell data.
                else if (inRow && (event.name == Name.Data || event.name == Name.GfmTableDelimiterMarker || event.name == Name.GfmTableDelimiterFiller)) {
                    inFirstCellAwaitingPipe = false;

                    // First value in cell.
                    if (cell[2] == 0) {
                        if (lastCell[1] != 0) {
                            cell[0] = cell[1];
                            flushCell(tokenizer, lastCell, inDelimiterRow, -1);
                            lastCell = [0, 0, 0, 0];
                        }

                        cell[2] = index;
                    }
                }
                else if (event.name == Name.GfmTableCellDivider) {
                    if (inFirstCellAwaitingPipe) {
                        inFirstCellAwaitingPipe = false;
                    }
                    else {
                        if (lastCell[1] != 0) {
                            cell[0] = cell[1];
                            flushCell(tokenizer, lastCell, inDelimiterRow, -1);
                        }

                        lastCell = cell.copy();
                        cell = [lastCell[1], index, 0, 0];
                    }
                }
            }
            // Exits.
            else if (event.name == Name.GfmTableHead) {
                afterHeadAwaitingFirstBodyRow = true;
                lastTableEnd = index;
            }
            else if (event.name == Name.GfmTableRow || event.name == Name.GfmTableDelimiterRow) {
                inRow = false;
                lastTableEnd = index;
                if (lastCell[1] != 0) {
                    cell[0] = cell[1];
                    flushCell(tokenizer, lastCell, inDelimiterRow, index);
                }
                else if (cell[1] != 0) {
                    flushCell(tokenizer, cell, inDelimiterRow, index);
                }
            }
            else if (inRow && (event.name == Name.Data || event.name == Name.GfmTableDelimiterMarker || event.name == Name.GfmTableDelimiterFiller)) {
                cell[3] = index;
            }

            index += 1;
        }

        if (lastTableEnd != 0) {
            flushTableEnd(tokenizer, lastTableEnd, lastTableHasBody);
        }

        tokenizer.map.consume(tokenizer.events);
        return null;
    }

    /** Generate a cell. */
    static function flushCell(tokenizer:Tokenizer, range:Array<Int>, inDelimiterRow:Bool, rowEnd:Int):Void {
        var groupName = inDelimiterRow ? Name.GfmTableDelimiterCell : Name.GfmTableCell;
        var valueName = inDelimiterRow ? Name.GfmTableDelimiterCellValue : Name.GfmTableCellText;

        // Insert an exit for the previous cell, if there is one.
        if (range[0] != 0) {
            tokenizer.map.add(range[0], 0, [new Event(Kind.Exit, groupName, tokenizer.events[range[0]].point.clone(), null)]);
        }

        // Insert enter of this cell.
        tokenizer.map.add(range[1], 0, [new Event(Kind.Enter, groupName, tokenizer.events[range[1]].point.clone(), null)]);

        // Insert text start at first data start and end at last data end, and remove events between.
        if (range[2] != 0) {
            tokenizer.map.add(range[2], 0, [new Event(Kind.Enter, valueName, tokenizer.events[range[2]].point.clone(), null)]);

            if (!inDelimiterRow) {
                tokenizer.events[range[2]].link = new Link(-1, -1, Content.Text);

                // To do: positional info of the remaining `data` nodes likely have to be fixed.
                if (range[3] > range[2] + 1) {
                    var a = range[2] + 1;
                    var b = range[3] - range[2] - 1;
                    tokenizer.map.add(a, b, []);
                }
            }

            tokenizer.map.add(range[3] + 1, 0, [new Event(Kind.Exit, valueName, tokenizer.events[range[3]].point.clone(), null)]);
        }

        // Insert an exit for the last cell, if at the row end.
        if (rowEnd != -1) {
            tokenizer.map.add(rowEnd, 0, [new Event(Kind.Exit, groupName, tokenizer.events[rowEnd].point.clone(), null)]);
        }
    }

    /** Generate table end (and table body end). */
    static function flushTableEnd(tokenizer:Tokenizer, index:Int, body:Bool):Void {
        var exits:Array<Event> = [];

        if (body) {
            exits.push(new Event(Kind.Exit, Name.GfmTableBody, tokenizer.events[index].point.clone(), null));
        }

        exits.push(new Event(Kind.Exit, Name.GfmTable, tokenizer.events[index].point.clone(), null));

        tokenizer.map.add(index + 1, 0, exits);
    }

}
