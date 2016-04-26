package tink;

import tink.web.*;
import haxe.macro.Expr;
import tink.web.RoutingContext in Ctx;

using tink.CoreApi;

class Web { 

  macro static public function route<T:{}>(req:ExprOf<Request>, target:ExprOf<T>, ?onFailure:ExprOf<Ctx<T>->Response>, ?depth:ExprOf<Int>):ExprOf<Response> {
    var path = tink.web.macros.Routing.buildContext(haxe.macro.Context.typeof(target)).path;    
    depth = tink.macro.Exprs.ifNull(depth, macro 0);
    return macro new $path($target, $req, $onFailure, $depth).route();
  }
  
}