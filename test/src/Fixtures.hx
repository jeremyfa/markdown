#if macro
import haxe.macro.Context;
#end

/**
 * Embeds the fixtures (`test/fixtures/*.jsonl`) as resources at compile time,
 * so the runner works the same on every target.
 */
class Fixtures {

    public static macro function embed():haxe.macro.Expr {
        var dir = haxe.io.Path.join([haxe.io.Path.directory(Context.getPosInfos(Context.currentPos()).file), '..', 'fixtures']);
        var names = [];
        for (file in sys.FileSystem.readDirectory(dir)) {
            if (StringTools.endsWith(file, '.jsonl')) {
                var name = file.substr(0, file.length - 6);
                Context.addResource('fixture-' + name, sys.io.File.getBytes(haxe.io.Path.join([dir, file])));
                names.push(name);
            }
        }
        names.sort((a, b) -> a < b ? -1 : a > b ? 1 : 0);
        return macro $v{names};
    }

}
