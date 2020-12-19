package tink.web.macros;

#if macro
class Signature {

  static var CONTEXT:Lazy<Type> = Context.getType.bind('tink.web.routing.Context');

  public var paths(default, null):Paths;
  public var params(default, null):Parameters;
  public var args(default, null):Arguments;
  public var result(default, null):Result;

  public function new(f:ClassField, type:Type) {
    switch type.reduce() {
      case TFun(args, ret):
        this.paths = new Paths(f.name, args, f.meta);
        this.params = new Parameters(f.meta, [for(a in args) a.name => a.t]);
        this.args = new Arguments(args, paths, params, f.pos);
        this.result = new Result(lift(ret, f.pos));
      case t:
        this.paths = new Paths(f.name, [], f.meta);
        this.params = new Parameters(f.meta, new Map());
        this.args = new Arguments([], paths, params, f.pos);
        this.result = new Result(lift(t, f.pos));
    }
  }

  static function lift(t:Type, pos:Position) {
    var ct = t.toComplex();
    return (macro @:pos(pos) {
      function get<A>(p:tink.core.Promise<A>):A throw 'whatever';
      get((null : $ct));
    }).typeof().sure();
  }

}
#end