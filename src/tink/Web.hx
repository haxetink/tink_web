package tink;

#if macro
import haxe.macro.Context;
#end

import tink.web.*;
import haxe.macro.Expr;
import tink.web.RoutingContext in Ctx;

using tink.CoreApi;

class Web { 

  macro static public function route<Session:tink.web.Session, Target:{}>(req:ExprOf<Request>, target:ExprOf<Target>, ?onFailure:ExprOf<Ctx<Session, Target>->Response>, ?depth:ExprOf<Int>, ?session:ExprOf<Session>):ExprOf<Response> {
    session = tink.macro.Exprs.ifNull(session, macro tink.web.Session.BasicSession.inst);
    var routing = tink.web.macros.Routing.buildContext(Context.typeof(session), Context.typeof(target));
    //trace(routing.type);
    //trace(session);
    var path = routing.path;    
    depth = tink.macro.Exprs.ifNull(depth, macro 0);
    
    return macro new $path($session, $target, $req, $onFailure, $depth).route();
  }
  
}