import markdown.Markdown;
import markdown.Options;
import markdown.ParseOptions;
import markdown.message.Message;
import markdown.mdast.NodeJson;

/**
 * Runs the ported markdown-rs tests.
 *
 * The fixtures were recorded from the upstream test suite (`tests/*.rs` of
 * markdown-rs 1.0.0): every call to `to_html`, `to_html_with_options` and
 * `to_mdast` made by the upstream tests, with its input, its options and the
 * result of the real crate (HTML, the mdast serialized by serde_json, or the
 * error message). Calls that need the swc JavaScript parser (MDX with
 * `mdx_esm_parse` / `mdx_expression_parse`) are skipped.
 *
 * An optional first argument filters suites by substring.
 */
class Main {

    static function main() {
        var names:Array<String> = Fixtures.embed();
        var filter = getFilter();
        var totalPassed = 0;
        var totalFailed = 0;
        var totalSkipped = 0;
        var failures = [];
        var start = haxe.Timer.stamp();

        for (name in names) {
            if (filter != null && name.indexOf(filter) == -1)
                continue;
            var passed = 0;
            var failed = 0;
            var skipped = 0;
            var lines = haxe.Resource.getString('fixture-' + name).split('\n');
            var message = '';
            for (line in lines) {
                if (line.length == 0)
                    continue;
                var record:Dynamic = haxe.Json.parse(line);
                var kind:String = record.t;
                if (kind == 'assert') {
                    message = record.msg;
                    continue;
                }
                if (record.o != null && (record.o.esmParse || record.o.expressionParse)) {
                    skipped++;
                    continue;
                }
                var expectedOk:Null<String> = record.ok;
                var expectedErr:Null<String> = record.err;
                var actualOk:Null<String> = null;
                var actualErr:Null<String> = null;
                try {
                    switch kind {
                        case 'html':
                            actualOk = Markdown.toHtml(record.input);
                        case 'htmlOptions':
                            actualOk = Markdown.toHtmlWithOptions(record.input, Options.fromDynamic(record.o.options));
                        case 'mdast':
                            actualOk = NodeJson.toJson(Markdown.toMdast(record.input, ParseOptions.fromDynamic(record.o.options)));
                        default:
                            throw 'unknown record ' + kind;
                    }
                }
                catch (e:Message) {
                    actualErr = e.toString();
                }
                catch (e:Dynamic) {
                    actualErr = 'CRASH: ' + Std.string(e);
                }
                if (actualOk == expectedOk && actualErr == expectedErr) {
                    passed++;
                }
                else {
                    failed++;
                    failures.push(name + ' (' + kind + ') ' + haxe.Json.stringify(record.input) + '\n    expected: '
                        + (expectedErr != null ? 'ERR ' + expectedErr : haxe.Json.stringify(expectedOk)) + '\n    actual:   '
                        + (actualErr != null ? 'ERR ' + actualErr : haxe.Json.stringify(actualOk)));
                }
            }
            totalPassed += passed;
            totalFailed += failed;
            totalSkipped += skipped;
            log(StringTools.rpad(name, ' ', 28) + ' ' + passed + ' passed, ' + failed + ' failed' + (skipped > 0 ? ', ' + skipped + ' skipped (swc)' : ''));
        }

        var extra = ExtraTests.run();
        totalPassed += extra.passed;
        totalFailed += extra.failures.length;
        for (f in extra.failures)
            failures.push(f);
        log(StringTools.rpad('extra', ' ', 28) + ' ' + extra.passed + ' passed, ' + extra.failures.length + ' failed');

        for (f in failures.slice(0, 40))
            log('FAIL ' + f);
        log('Total: ' + totalPassed + ' passed, ' + totalFailed + ' failed, ' + totalSkipped + ' skipped (' + Std.int((haxe.Timer.stamp() - start) * 1000) + ' ms)');
        exit(totalFailed == 0 ? 0 : 1);
    }

    static function getFilter():Null<String> {
        #if (sys || hxnodejs)
        var args = Sys.args();
        return args.length > 0 ? args[0] : null;
        #elseif js
        var argv:Array<String> = js.Syntax.code('typeof process !== "undefined" ? process.argv.slice(2) : []');
        return argv.length > 0 ? argv[0] : null;
        #else
        return null;
        #end
    }

    public static function log(s:String):Void {
        #if js
        js.Syntax.code('console.log({0})', s);
        #elseif sys
        Sys.println(s);
        #else
        trace(s);
        #end
    }

    static function exit(code:Int):Void {
        #if js
        js.Syntax.code('if (typeof process !== "undefined") process.exitCode = {0}', code);
        #elseif sys
        Sys.exit(code);
        #end
    }

}
