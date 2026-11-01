import markdown.CompileOptions;
import markdown.Constructs;
import markdown.Markdown;
import markdown.Options;
import markdown.ParseOptions;
import markdown.mdast.Node;
import markdown.mdast.NodeJson;
import markdown.message.Message;
import markdown.unist.Point;
import markdown.unist.Position;
import markdown.util.CharUtil;
import markdown.util.LineEnding;
import markdown.util.Location;
import markdown.util.Mdx;

/**
 * Tests that are not calls recorded from `tests/*.rs`:
 *
 * - the `#[cfg(test)]` modules of the crate sources that check behavior
 *   (`unist.rs`, `util/char.rs`, `util/line_ending.rs`, `util/location.rs`,
 *   `configuration.rs`, `mdast.rs`), without the ones that only check Rust's
 *   `Debug` formatting;
 * - the option tests of `tests/serde.rs` (`Constructs`, `CompileOptions`,
 *   `ParseOptions` serialized by serde_json);
 * - deserialization (`NodeJson.fromJson`) of every mdast recorded in the
 *   fixtures, like `assert_serde` does, and `serde_json::to_string_pretty`
 *   outputs recorded from the crate;
 * - the MDX ESM case of `tests/mdx_swc.rs` with a parse function that
 *   accepts everything (swc accepts that input too), and errors signaled by
 *   parse functions (expected messages checked against the crate).
 */
class ExtraTests {

    static var passed = 0;
    static var failures:Array<String> = [];

    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        if (actual == expected) {
            passed++;
        }
        else {
            failures.push('extra: ' + message + '\n    expected: ' + Std.string(expected) + '\n    actual:   ' + Std.string(actual));
        }
    }

    static function ok(value:Bool, message:String):Void {
        eq(value, true, message);
    }

    public static function run():{passed:Int, failures:Array<String>} {
        unist();
        char();
        lineEnding();
        location();
        configuration();
        serdeOptions();
        serdeNodes();
        mdastNodes();
        mdxParse();
        return {passed: passed, failures: failures};
    }

    static function unist() {
        eq(new Point(1, 1, 0).toString(), '1:1 (0)', 'should support `Debug` on unist points');
        eq(Position.of(1, 1, 0, 1, 3, 2).toString(), '1:1-1:3 (0-2)', 'should support `Debug` on unist positions');
    }

    static function char() {
        eq(CharUtil.classify(' '.code), CharKind.Whitespace, 'should classify whitespace');
        eq(CharUtil.classify('.'.code), CharKind.Punctuation, 'should classify punctuation');
        eq(CharUtil.classify('a'.code), CharKind.Other, 'should classify other');
        eq(CharUtil.formatOpt(-1), 'end of file', 'should format an optional char: none -> eof');
        eq(CharUtil.formatOpt('!'.code), 'character `!` (U+0021)', 'should format an optional char: char -> pretty');
        eq(CharUtil.format('`'.code), '`` ` `` (U+0060)', 'should format a char: grave accent');
        eq(CharUtil.format('!'.code), '`!` (U+0021)', 'should format a char: regular');
        eq(CharUtil.format(' '.code), 'U+0020', 'should format a char: unprintable');
        eq(CharUtil.formatByte('`'.code), '`` ` `` (U+0060)', 'should format a byte: grave accent');
        eq(CharUtil.formatByte('!'.code), '`!` (U+0021)', 'should format a byte: regular');
        eq(CharUtil.formatByte(' '.code), 'U+0020', 'should format a byte: unprintable');
    }

    static function lineEnding() {
        eq(LineEnding.fromStr('\r'), LineEnding.CarriageReturn, 'should support turning a string into a carriage return');
        eq(LineEnding.CarriageReturn.asStr(), '\r', 'should support turning a carriage return into a string');
        eq(LineEnding.fromStr('\n'), LineEnding.LineFeed, 'should support turning a string into a line feed');
        eq(LineEnding.LineFeed.asStr(), '\n', 'should support turning a line feed into a string');
        eq(LineEnding.fromStr('\r\n'), LineEnding.CarriageReturnLineFeed, 'should support turning a string into a carriage return + line feed');
        eq(LineEnding.CarriageReturnLineFeed.asStr(), '\r\n', 'should support turning a carriage return + line feed into a string');
        var error = null;
        try {
            LineEnding.fromStr('aaa');
        }
        catch (e:String) {
            error = e;
        }
        eq(error, 'Expected CR, LF, or CRLF', 'should error when parsing a non-eol');
    }

    static function point(p:Null<Point>):String {
        return p == null ? 'None' : p.toString();
    }

    static function location() {
        var location = new Location(markdown.util.Utf8.bytesOf('ab\nc'));
        eq(point(location.toPoint(0)), '1:1 (0)', 'should support some points (1)');
        eq(point(location.toPoint(1)), '1:2 (1)', 'should support some points (2)');
        eq(point(location.toPoint(2)), '1:3 (2)', 'should support some points (3)');
        eq(point(location.toPoint(3)), '2:1 (3)', 'should support some points (4)');
        eq(point(location.toPoint(4)), '2:2 (4)', 'should support some points (5)');
        eq(point(location.toPoint(5)), 'None', 'should support some points (6)');

        var location = new Location(markdown.util.Utf8.bytesOf('a\rb'));
        eq(point(location.toPoint(0)), '1:1 (0)', 'should support some points (cr 1)');
        eq(point(location.toPoint(1)), '1:2 (1)', 'should support some points (cr 2)');
        eq(point(location.toPoint(2)), '2:1 (2)', 'should support some points (cr 3)');

        var location = new Location(markdown.util.Utf8.bytesOf('a\r\nb'));
        eq(point(location.toPoint(0)), '1:1 (0)', 'should support some points (crlf 1)');
        eq(point(location.toPoint(1)), '1:2 (1)', 'should support some points (crlf 2)');
        eq(point(location.toPoint(2)), '1:3 (2)', 'should support some points (crlf 3)');
        eq(point(location.toPoint(3)), '2:1 (3)', 'should support some points (crlf 4)');

        var location = new Location(markdown.util.Utf8.bytesOf(''));
        eq(point(location.toPoint(0)), '1:1 (0)', 'to_point');
        eq(point(location.relativeToPoint([], 0)), 'None', 'relative_to_point');
        eq(Location.relativeToAbsolute([], 0), -1, 'relative_to_absolute');
    }

    static function configuration() {
        var constructs = new Constructs();
        ok(constructs.attention, 'should default to `CommonMark` (1)');
        ok(!constructs.gfmAutolinkLiteral, 'should default to `CommonMark` (2)');
        ok(!constructs.mdxJsxFlow, 'should default to `CommonMark` (3)');
        ok(!constructs.frontmatter, 'should default to `CommonMark` (4)');
        var constructs = Constructs.gfm();
        ok(constructs.attention, 'should support `gfm` shortcut (1)');
        ok(constructs.gfmAutolinkLiteral, 'should support `gfm` shortcut (2)');
        ok(!constructs.mdxJsxFlow, 'should support `gfm` shortcut (3)');
        ok(!constructs.frontmatter, 'should support `gfm` shortcut (4)');
        var constructs = Constructs.mdx();
        ok(constructs.attention, 'should support `mdx` shortcut (1)');
        ok(!constructs.gfmAutolinkLiteral, 'should support `mdx` shortcut (2)');
        ok(constructs.mdxJsxFlow, 'should support `mdx` shortcut (3)');
        ok(!constructs.frontmatter, 'should support `mdx` shortcut (4)');

        var options = new ParseOptions();
        ok(options.constructs.attention, 'should default to `CommonMark` (parse 1)');
        ok(!options.constructs.gfmAutolinkLiteral, 'should default to `CommonMark` (parse 2)');
        ok(!options.constructs.mdxJsxFlow, 'should default to `CommonMark` (parse 3)');
        var options = ParseOptions.gfm();
        ok(options.constructs.attention, 'should support `gfm` shortcut (parse 1)');
        ok(options.constructs.gfmAutolinkLiteral, 'should support `gfm` shortcut (parse 2)');
        ok(!options.constructs.mdxJsxFlow, 'should support `gfm` shortcut (parse 3)');
        var options = ParseOptions.mdx();
        ok(options.constructs.attention, 'should support `mdx` shortcut (parse 1)');
        ok(!options.constructs.gfmAutolinkLiteral, 'should support `mdx` shortcut (parse 2)');
        ok(options.constructs.mdxJsxFlow, 'should support `mdx` shortcut (parse 3)');

        var options = new CompileOptions();
        ok(!options.allowDangerousHtml, 'should default to safe (compile 1)');
        ok(!options.gfmTagfilter, 'should default to safe (compile 2)');
        var options = CompileOptions.gfm();
        ok(!options.allowDangerousHtml, 'should support `gfm` shortcut (compile 1)');
        ok(options.gfmTagfilter, 'should support `gfm` shortcut (compile 2)');

        var options = new Options();
        ok(options.parse.constructs.attention, 'should default to `CommonMark` (options 1)');
        ok(!options.parse.constructs.gfmAutolinkLiteral, 'should default to `CommonMark` (options 2)');
        ok(!options.parse.constructs.mdxJsxFlow, 'should default to `CommonMark` (options 3)');
        ok(!options.compile.allowDangerousHtml, 'should default to safe (options 4)');
        var options = Options.gfm();
        ok(options.parse.constructs.attention, 'should support `gfm` shortcut (options 1)');
        ok(options.parse.constructs.gfmAutolinkLiteral, 'should support `gfm` shortcut (options 2)');
        ok(!options.parse.constructs.mdxJsxFlow, 'should support `gfm` shortcut (options 3)');
        ok(!options.compile.allowDangerousHtml, 'should support `gfm` shortcut (options 4)');
    }

    static function serdeOptions() {
        eq(new Constructs().toJson(),
            '{"attention":true,"autolink":true,"blockQuote":true,"characterEscape":true,"characterReference":true,"codeIndented":true,"codeFenced":true,"codeText":true,"definition":true,"frontmatter":false,"gfmAutolinkLiteral":false,"gfmFootnoteDefinition":false,"gfmLabelStartFootnote":false,"gfmStrikethrough":false,"gfmTable":false,"gfmTaskListItem":false,"hardBreakEscape":true,"hardBreakTrailing":true,"headingAtx":true,"headingSetext":true,"htmlFlow":true,"htmlText":true,"labelStartImage":true,"labelStartLink":true,"labelEnd":true,"listItem":true,"mathFlow":false,"mathText":false,"mdxEsm":false,"mdxExpressionFlow":false,"mdxExpressionText":false,"mdxJsxFlow":false,"mdxJsxText":false,"thematicBreak":true}',
            'serde_constructs');
        eq(CompileOptions.gfm().toJson(),
            '{"allowAnyImgSrc":false,"allowDangerousHtml":false,"allowDangerousProtocol":false,"defaultLineEnding":"\\n","gfmFootnoteBackLabel":null,"gfmFootnoteClobberPrefix":null,"gfmFootnoteLabelAttributes":null,"gfmFootnoteLabelTagName":null,"gfmFootnoteLabel":null,"gfmTaskListItemCheckable":false,"gfmTagfilter":true}',
            'serde_compile_options');
        eq(ParseOptions.gfm().toJson(),
            '{"constructs":{"attention":true,"autolink":true,"blockQuote":true,"characterEscape":true,"characterReference":true,"codeIndented":true,"codeFenced":true,"codeText":true,"definition":true,"frontmatter":false,"gfmAutolinkLiteral":true,"gfmFootnoteDefinition":true,"gfmLabelStartFootnote":true,"gfmStrikethrough":true,"gfmTable":true,"gfmTaskListItem":true,"hardBreakEscape":true,"hardBreakTrailing":true,"headingAtx":true,"headingSetext":true,"htmlFlow":true,"htmlText":true,"labelStartImage":true,"labelStartLink":true,"labelEnd":true,"listItem":true,"mathFlow":false,"mathText":false,"mdxEsm":false,"mdxExpressionFlow":false,"mdxExpressionText":false,"mdxJsxFlow":false,"mdxJsxText":false,"thematicBreak":true},"gfmStrikethroughSingleTilde":true,"mathTextSingleDollar":true}',
            'serde_parse_options');
    }

    static function serdeNodes() {
        // Deserialization: every mdast of the fixtures reads back to the same tree.
        for (name in Fixtures.embed()) {
            for (line in haxe.Resource.getString('fixture-' + name).split('\n')) {
                if (line.length == 0)
                    continue;
                var record:Dynamic = haxe.Json.parse(line);
                if (record.t != 'mdast' || record.ok == null)
                    continue;
                var json:String = record.ok;
                eq(NodeJson.toJson(NodeJson.fromJson(json)), json, 'deserialize ' + name + ' ' + haxe.Json.stringify(record.input));
            }
        }

        // Pretty output (`serde_json::to_string_pretty`), recorded from the crate.
        var list:Array<Dynamic> = haxe.Json.parse(haxe.Resource.getString('serde_pretty'));
        for (item in list) {
            var options = item.mdx ? ParseOptions.mdx() : ParseOptions.gfm();
            eq(NodeJson.toJson(Markdown.toMdast(item.input, options), true), item.pretty, 'to_string_pretty ' + haxe.Json.stringify(item.input));
        }
    }

    static function mdastNodes() {
        var position = Position.of(1, 1, 0, 1, 2, 1);

        // Literals.
        var literals:Array<Node> = [
            Text(new markdown.mdast.Node.Text('a', null)),
            InlineCode(new markdown.mdast.Node.InlineCode('a', null)),
            Code(new markdown.mdast.Node.Code('a', null, null, null)),
            InlineMath(new markdown.mdast.Node.InlineMath('a', null)),
            Math(new markdown.mdast.Node.Math('a', null, null)),
            Html(new markdown.mdast.Node.Html('a', null)),
            MdxTextExpression(new markdown.mdast.Node.MdxTextExpression('a', null, [])),
            MdxFlowExpression(new markdown.mdast.Node.MdxFlowExpression('a', null, [])),
            MdxjsEsm(new markdown.mdast.Node.MdxjsEsm('a', null, [])),
            Toml(new markdown.mdast.Node.Toml('a', null)),
            Yaml(new markdown.mdast.Node.Yaml('a', null)),
        ];
        for (node in literals) {
            var label = Std.string(node).split('(')[0];
            eq(node.toString(), 'a', label + ': should support `ToString`');
            ok(node.children() == null, label + ': should support `children`');
            ok(node.position() == null, label + ': should support `position`');
            node.positionSet(position);
            eq(Std.string(node.position()), '1:1-1:2 (0-1)', label + ': should support `position_set`');
        }

        // Voids.
        var voids:Array<Node> = [
            Break(new markdown.mdast.Node.Break(null)),
            ThematicBreak(new markdown.mdast.Node.ThematicBreak(null)),
            FootnoteReference(new markdown.mdast.Node.FootnoteReference(null, 'a', null)),
            ImageReference(new markdown.mdast.Node.ImageReference(null, 'a', ReferenceKind.Full, 'a', null)),
            Image(new markdown.mdast.Node.Image(null, 'a', 'b', null)),
            Definition(new markdown.mdast.Node.Definition(null, 'a', null, 'a', null)),
        ];
        for (node in voids) {
            var label = Std.string(node).split('(')[0];
            eq(node.toString(), '', label + ': should support `ToString`');
            ok(node.children() == null, label + ': should support `children`');
            ok(node.position() == null, label + ': should support `position`');
            node.positionSet(position);
            eq(Std.string(node.position()), '1:1-1:2 (0-1)', label + ': should support `position_set`');
        }

        // Parents.
        function text():Node {
            return Text(new markdown.mdast.Node.Text('a', null));
        }
        var parents:Array<Node> = [
            Root(new markdown.mdast.Node.Root([text()], null)),
            Blockquote(new markdown.mdast.Node.Blockquote([text()], null)),
            FootnoteDefinition(new markdown.mdast.Node.FootnoteDefinition([text()], null, 'a', null)),
            MdxJsxFlowElement(new markdown.mdast.Node.MdxJsxFlowElement([text()], null, null, [])),
            List(new markdown.mdast.Node.List([text()], null, false, null, false)),
            Delete(new markdown.mdast.Node.Delete([text()], null)),
            Emphasis(new markdown.mdast.Node.Emphasis([text()], null)),
            MdxJsxTextElement(new markdown.mdast.Node.MdxJsxTextElement([text()], null, null, [])),
            Link(new markdown.mdast.Node.Link([text()], null, 'b', null)),
            LinkReference(new markdown.mdast.Node.LinkReference([text()], null, ReferenceKind.Full, 'b', null)),
            Strong(new markdown.mdast.Node.Strong([text()], null)),
            Heading(new markdown.mdast.Node.Heading([text()], null, 1)),
            Table(new markdown.mdast.Node.Table([text()], null, [])),
            TableRow(new markdown.mdast.Node.TableRow([text()], null)),
            TableCell(new markdown.mdast.Node.TableCell([text()], null)),
            ListItem(new markdown.mdast.Node.ListItem([text()], null, false, null)),
            Paragraph(new markdown.mdast.Node.Paragraph([text()], null)),
        ];
        for (node in parents) {
            var label = Std.string(node).split('(')[0];
            eq(node.toString(), 'a', label + ': should support `ToString`');
            eq(node.children().length, 1, label + ': should support `children`');
            ok(node.position() == null, label + ': should support `position`');
            node.positionSet(position);
            eq(Std.string(node.position()), '1:1-1:2 (0-1)', label + ': should support `position_set`');
        }
    }

    static function mdxParse() {
        // From `tests/mdx_swc.rs`: swc accepts this ESM, so does a parse
        // function that accepts everything.
        var options = new Options(ParseOptions.mdx());
        options.parse.mdxEsmParse = (value:String) -> MdxSignal.Ok;
        options.parse.mdxExpressionParse = (value:String, kind:MdxExpressionKind) -> MdxSignal.Ok;
        eq(Markdown.toHtmlWithOptions('import a from \'b\'\n\nexport {a}\n\n# c', options), '<h1>c</h1>',
            'should support JavaScript-aware ESM w/ `mdx_esm_parse`');

        // Errors signaled by the parse functions get a place in the document.
        options.parse.mdxEsmParse = (value:String) -> MdxSignal.Error('Could not parse esm', 7, 'test', 'esm');
        var message = null;
        try {
            Markdown.toHtmlWithOptions('a\n\nimport a', options);
        }
        catch (e:Message) {
            message = e.toString();
        }
        eq(message, '3:8: Could not parse esm (test:esm)', 'should place errors from `mdx_esm_parse`');

        options.parse.mdxExpressionParse = (value:String, kind:MdxExpressionKind) -> MdxSignal.Error('Could not parse expression', 1, 'test', 'expression');
        var message = null;
        try {
            Markdown.toHtmlWithOptions('a {b}', options);
        }
        catch (e:Message) {
            message = e.toString();
        }
        eq(message, '1:5: Could not parse expression (test:expression)', 'should place errors from `mdx_expression_parse`');
    }

}
