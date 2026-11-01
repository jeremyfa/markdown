// Ported from markdown 1.0.0: src/configuration.rs
// Original code Copyright (c) 2022 Titus Wormer <tituswormer@gmail.com>, licensed under MIT.
// Modified: translated from Rust to Haxe. See README.md.

package markdown;

/**
 * Configuration (optional): `parse` and `compile` options (`Options`).
 */
class Options {

    /** Configuration that describes how to parse from markdown. */
    public var parse:ParseOptions;
    /** Configuration that describes how to compile to HTML. */
    public var compile:CompileOptions;

    /** `Options::default()`, or the given parts. */
    public function new(?parse:ParseOptions, ?compile:CompileOptions) {
        this.parse = parse != null ? parse : new ParseOptions();
        this.compile = compile != null ? compile : new CompileOptions();
    }

    /** GFM. */
    public static function gfm():Options {
        return new Options(ParseOptions.gfm(), CompileOptions.gfm());
    }

    /** Same JSON as serde_json. */
    public function toJson():String {
        return '{"parse":' + parse.toJson() + ',"compile":' + compile.toJson() + '}';
    }

    /** Read the JSON written by serde (missing fields keep their default). */
    public static function fromDynamic(value:Dynamic):Options {
        return new Options(
            Reflect.hasField(value, 'parse') ? ParseOptions.fromDynamic(Reflect.field(value, 'parse')) : null,
            Reflect.hasField(value, 'compile') ? CompileOptions.fromDynamic(Reflect.field(value, 'compile')) : null
        );
    }

}
