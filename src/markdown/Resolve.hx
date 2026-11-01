// Ported from markdown 1.0.0: src/resolve.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown;

import markdown.construct.ContentConstruct;
import markdown.construct.LabelEnd;
import markdown.construct.PartialData;
import markdown.construct.StringConstruct;

/** Names of resolvers (`Name` in `resolve.rs`). */
enum abstract ResolveName(Int) {
    var Label = 0;
    var Attention = 1;
    var GfmTable = 2;
    var HeadingAtx = 3;
    var HeadingSetext = 4;
    var ListItem = 5;
    var Content = 6;
    var Data = 7;
    var String = 8;
    var Text = 9;
}

class Resolve {

    /** Call the corresponding resolver. Throws a `Message` on error. */
    public static function call(tokenizer:Tokenizer, name:ResolveName):Null<Subresult> {
        return switch name {
            case Label: LabelEnd.resolve(tokenizer);
            case Attention: markdown.construct.Attention.resolve(tokenizer);
            case GfmTable: markdown.construct.GfmTable.resolve(tokenizer);
            case HeadingAtx: markdown.construct.HeadingAtx.resolve(tokenizer);
            case HeadingSetext: markdown.construct.HeadingSetext.resolve(tokenizer);
            case ListItem: markdown.construct.ListItem.resolve(tokenizer);
            case Content: ContentConstruct.resolve(tokenizer);
            case Data: PartialData.resolve(tokenizer);
            case String: StringConstruct.resolve(tokenizer);
            case Text: markdown.construct.Text.resolve(tokenizer);
        }
    }

}
