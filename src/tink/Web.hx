package tink;

#if macro
import haxe.macro.Context;
#end

import tink.web.*;
import haxe.macro.Expr;
import tink.web.RoutingContext in Ctx;

using tink.CoreApi;

class Web { 

  macro static public function route<User, Target:{}>(req:ExprOf<Request>, target:ExprOf<Target>, ?onFailure:ExprOf<Ctx<User, Target>->Response>, ?depth:ExprOf<Int>, ?session:ExprOf<Session<User>>):ExprOf<Response> {
    session = tink.macro.Exprs.ifNull(session, macro tink.web.Session.BASIC);
    var user = 
      Context.typeof(macro @:pos(session.pos) { 
        var ret = null;
        $session.getUser().handle(function (o) switch o {
          case Success(Some(v)):
            ret = v;
          case _:
        }); 
        ret;
      });
      
    var routing = tink.web.macros.Routing.buildContext(user, Context.typeof(target));
    
    var path = routing.path;    
    depth = tink.macro.Exprs.ifNull(depth, macro 0);
    
    return macro new $path($session, $target, $req, $onFailure, $depth).route();
  }
  
}