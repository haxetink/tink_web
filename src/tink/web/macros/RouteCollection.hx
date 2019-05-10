package tink.web.macros;

import haxe.macro.Expr;
import haxe.macro.Type;
using tink.MacroApi;

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
    
    for(f in type.getFields().sure()) {
      if(Route.hasWebMeta(f)) routes.push(new Route(f, consumes, produces));
    }
    
    restricts = Route.getRestricts(type.getMeta());
  }
  
  public inline function iterator() return routes.iterator();
}