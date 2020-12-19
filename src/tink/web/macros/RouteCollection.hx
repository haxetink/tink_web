package tink.web.macros;

#if macro
class RouteCollection {

  public var routes(default, null):Array<Route> = [];
  public var type(default, null):Type;
  public var restricts(default, null):Array<Expr>;

  public function new(type:Type, consumes:Array<MimeType>, produces:Array<MimeType>) {
    this.type = type;
    // override default mimes if corresponding meta specified
    switch type {
      case TInst(_.get().meta => m, _) | TAbstract(_.get().meta => m, _) | TType(_.get().meta => m, _):
        consumes = MimeType.fromMeta(m, 'consumes', consumes);
        produces = MimeType.fromMeta(m, 'produces', produces);
      default:
    }

    var placeholder = type.toComplex({ direct: true });
    function getType(f:ClassField) {
      var name = f.name;
      return (macro @:pos(f.pos) (null:$placeholder).$name).typeof().sure();
    }

    for(f in type.getFields(false).sure())
      if(Route.hasWebMeta(f))
        routes.push(new Route(f, consumes, produces, getType(f)));

    restricts = Route.getRestricts(type.getMeta());
  }

  public inline function iterator() return routes.iterator();
}
#end