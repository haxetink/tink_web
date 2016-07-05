package tink;

#if macro
import haxe.macro.Context;
using tink.MacroApi;
#end

import tink.web.*;
import haxe.macro.Expr;
import tink.web.RoutingContext in Ctx;

using tink.CoreApi;

typedef WebRoutingOptions<User, Target> = {
  ?onFailure:Ctx<User, Target>->Response, 
  ?depth:Int, 
  ?session:Session<User>  
}

class Web { 

  macro static public function route<User, Target:{}>(req:ExprOf<Request>, target:ExprOf<Target>, ?options:ExprOf<WebRoutingOptions<User, Target>>):ExprOf<Response> {
    
    options = options.ifNull(macro { session: tink.web.Session.BASIC, depth: 0, onFailure: null });
    
    var userType = 
      Context.typeof(macro @:pos(options.pos) { 
        
        var ret = null;
        
        $options.session.getUser().handle(function (o) switch o {
          case Success(Some(v)):
            ret = v;
          case _:
        });
        
        ret;
        
      });
      
    var targetType = Context.typeof(target);
      
    var routing = tink.web.macros.Routing.buildContext(userType, targetType);
    
    var path = routing.path,
        userType = userType.toComplex(),
        targetType = targetType.toComplex();
    
    return macro {
      var __o:tink.Web.WebRoutingOptions<$userType, $targetType> = $options;
      new $path(__o.session, $target, $req, __o.onFailure, __o.depth).route();
    }
  }
  
}