package tink.web.v2;

import haxe.macro.Type;
using tink.MacroApi;

class RouteCollection {
  
  public var routes(default, null):Array<Route> = [];
  
  public function new(type:Type, consumes:Array<MimeType>, produces:Array<MimeType>) {
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
  }
  
  public inline function iterator() return routes.iterator();
}