// Ported from markdown 1.0.0: src/construct/partial_mdx_expression.rs
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
import markdown.message.Message;
import markdown.message.Place;
import markdown.util.MdxCollect;
import markdown.util.Mdx;

/**
 * MDX expression occurs in MDX expression (flow, text) and MDX JSX
 * (`partial_mdx_expression.rs`).
 */
class PartialMdxExpression {

    /** Start of an MDX expression. */
    public static function start(tokenizer:Tokenizer):State {
        tokenizer.enter(tokenizer.tokenizeState.token1);
        tokenizer.enter(Name.MdxExpressionMarker);
        tokenizer.consume();
        tokenizer.exit(Name.MdxExpressionMarker);
        tokenizer.tokenizeState.start = tokenizer.events.length - 1;
        return State.Next(StateName.MdxExpressionBefore);
    }

    /** Before data. */
    public static function before(tokenizer:Tokenizer):State {
        switch tokenizer.current {
            case -1:
                var problem = tokenizer.tokenizeState.mdxLastParseError;
                tokenizer.tokenizeState.mdxLastParseError = null;
                if (problem == null)
                    problem = ['Unexpected end of file in expression, expected a corresponding closing brace for `{`', 'markdown-rs', 'unexpected-eof'];

                return State.error(new Message(Place.Point(tokenizer.point.toUnist()), problem[0], problem[2], problem[1]));
            case '\n'.code:
                tokenizer.enter(Name.LineEnding);
                tokenizer.consume();
                tokenizer.exit(Name.LineEnding);
                return State.Next(StateName.MdxExpressionEolAfter);
            case '}'.code if (tokenizer.tokenizeState.size == 0):
                var parse = tokenizer.parseState.options.mdxExpressionParse;
                var state = parse != null ? parseExpression(tokenizer, parse) : State.Ok;

                if (state == State.Ok) {
                    tokenizer.tokenizeState.start = 0;
                    tokenizer.enter(Name.MdxExpressionMarker);
                    tokenizer.consume();
                    tokenizer.exit(Name.MdxExpressionMarker);
                    tokenizer.exit(tokenizer.tokenizeState.token1);
                }

                return state;
            default:
                tokenizer.enter(Name.MdxExpressionData);
                return State.Retry(StateName.MdxExpressionInside);
        }
    }

    /** In data. */
    public static function inside(tokenizer:Tokenizer):State {
        if (tokenizer.current == -1 || tokenizer.current == '\n'.code || (tokenizer.current == '}'.code && tokenizer.tokenizeState.size == 0)) {
            tokenizer.exit(Name.MdxExpressionData);
            return State.Retry(StateName.MdxExpressionBefore);
        }
        else {
            // Don't count if gnostic.
            if (tokenizer.current == '{'.code && tokenizer.parseState.options.mdxExpressionParse == null) {
                tokenizer.tokenizeState.size += 1;
            }
            else if (tokenizer.current == '}'.code) {
                tokenizer.tokenizeState.size -= 1;
            }

            tokenizer.consume();
            return State.Next(StateName.MdxExpressionInside);
        }
    }

    /** After eol. */
    public static function eolAfter(tokenizer:Tokenizer):State {
        // Lazy continuation in a flow expression (or flow tag) is a syntax error.
        if ((tokenizer.tokenizeState.token1 == Name.MdxFlowExpression || tokenizer.tokenizeState.token2 == Name.MdxJsxFlowTag) && tokenizer.lazy) {
            return State.error(new Message(Place.Point(tokenizer.point.toUnist()),
                'Unexpected lazy line in expression in container, expected line to be prefixed with `>` when in a block quote, whitespace when in a list, etc',
                'unexpected-lazy', 'markdown-rs'));
        }
        else if (tokenizer.current == '\t'.code || tokenizer.current == ' '.code) {
            // Idea: investigate if we'd need to use more complex stripping.
            // Take this example:
            //
            // ```markdown
            // >  aaa <b c={`
            // >      d
            // >  `} /> eee
            // ```
            //
            // Currently, the "paragraph" starts at `> | aaa`, so for the next line
            // here we split it into `>␠|␠␠|␠␠␠d` (prefix, this indent here,
            // expression data).
            tokenizer.enter(Name.LinePrefix);
            return State.Retry(StateName.MdxExpressionPrefix);
        }
        else {
            return State.Retry(StateName.MdxExpressionBefore);
        }
    }

    /** In line prefix. */
    public static function prefix(tokenizer:Tokenizer):State {
        // Tab-size to eat has to be the same as what we serialize as.
        // While in some places in markdown that's 4, in JS it's more common as 2.
        // Which is what's also in `mdast-util-mdx-jsx`:
        // <https://github.com/syntax-tree/mdast-util-mdx-jsx/blob/40b951b/lib/index.js#L52>
        // <https://github.com/micromark/micromark-extension-mdx-expression/blob/7c305ff/packages/micromark-extension-mdx-expression/dev/lib/syntax.js#L57>
        if ((tokenizer.current == '\t'.code || tokenizer.current == ' '.code) && tokenizer.tokenizeState.sizeC < 2) {
            tokenizer.tokenizeState.sizeC += 1;
            tokenizer.consume();
            return State.Next(StateName.MdxExpressionPrefix);
        }

        tokenizer.exit(Name.LinePrefix);
        tokenizer.tokenizeState.sizeC = 0;
        return State.Retry(StateName.MdxExpressionBefore);
    }

    /** Parse an expression with a given function. */
    static function parseExpression(tokenizer:Tokenizer, parse:MdxExpressionParse):State {
        // Collect the body of the expression and positional info for each run of it.
        var result = MdxCollect.collect(tokenizer.events, tokenizer.parseState.bytes, tokenizer.tokenizeState.start, [Name.MdxExpressionData, Name.LineEnding], []);

        // Turn the name of the expression into a kind.
        var kind = switch tokenizer.tokenizeState.token1 {
            case Name.MdxFlowExpression | Name.MdxTextExpression: MdxExpressionKind.Expression;
            case Name.MdxJsxTagAttributeExpression: MdxExpressionKind.AttributeExpression;
            case Name.MdxJsxTagAttributeValueExpression: MdxExpressionKind.AttributeValueExpression;
            default: throw 'cannot handle unknown expression name';
        };

        // Parse and handle what was signaled back.
        switch parse(result.value, kind) {
            case Ok:
                return State.Ok;
            case Error(reason, relative, source, ruleId):
                var point = tokenizer.parseState.location.relativeToPoint(result.stops, relative);
                if (point == null)
                    point = tokenizer.point.toUnist();
                return State.error(new Message(Place.Point(point), reason, ruleId, source));
            case Eof(reason, source, ruleId):
                tokenizer.tokenizeState.mdxLastParseError = [reason, source, ruleId];
                tokenizer.enter(Name.MdxExpressionData);
                tokenizer.consume();
                return State.Next(StateName.MdxExpressionInside);
        }
    }

}
