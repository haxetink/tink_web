package tink;

import tink.web.*;
import haxe.macro.Expr;
import tink.web.RoutingContext in Ctx;

using tink.CoreApi;

class Web { 

  //macro static public function route<User, Session:tink.web.Session<User>, Target:{}>(req:ExprOf<Request>, target:ExprOf<Target>, ?onFailure:ExprOf<Ctx<Session, Target>->Response>, ?depth:ExprOf<Int>, ?session:ExprOf<Session>):ExprOf<Response> {
    //var routing = tink.web.macros.Routing.buildContext(haxe.macro.Context.typeof(target));
    ////trace(routing.type);
    ////trace(session);
    //var path = routing.path;    
    //depth = tink.macro.Exprs.ifNull(depth, macro 0);
    //session = tink.macro.Exprs.ifNull(session, macro (null : { } ));
    //return macro new $path({}, $target, $req, $onFailure, $depth).route();
  //}
  
}