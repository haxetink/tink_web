package tink.web;

@:genericBuild(tink.web.macros.QueryComposerBuilder.build())
class QueryComposer<T> {
  macro static public function query(e) {
    var ct = haxe.macro.TypeTools.toComplexType(haxe.macro.Context.typeof(e));
    return macro @:pos(e.pos) new tink.web.QueryComposer<$ct>().compose($e);
  }
}