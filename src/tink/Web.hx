package tink;

import tink.web.*;
import haxe.macro.Expr;
import tink.web.Router.RoutingContext in Ctx;

using tink.CoreApi;

class Web { 

  macro static public function route<T:{}>(req:ExprOf<Request>, target:ExprOf<T>, ?depth:ExprOf<Int>, ?onFailure:ExprOf<Ctx<T>->Response>):ExprOf<Response> {
    var path = tink.web.macros.Routing.buildContext(haxe.macro.Context.typeof(target)).path;    
    return macro new $path($target, $req, $depth, $onFailure).route();
  }
  
}