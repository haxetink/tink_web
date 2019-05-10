package tink.web.macros;

import haxe.macro.Expr;
import tink.http.Method;

using tink.CoreApi;
using tink.MacroApi;

@:structInit
class Variant {
  public var path(default, null):RoutePath;
	
  public static function checkVariants<V:Variant>(pos:Position, variants:Iterable<V>) {
    function warn(prefix, pos:Position, args:Array<String>) {
      var names = switch args {
        case [single]: '`$single`';
        default: 
          's `${args.slice(0, -1).join("`, `")}` and `${args[args.length - 1]}`';
      }
      pos.warning(prefix + names);
    }
    
    if (!Lambda.exists(variants, function (v) return v.path.deviation.missing.length == 0)) {
      pos.warning('All defined routes are incomplete');
      for (v in variants)
        warn('Route does not capture argument', v.path.pos, v.path.deviation.missing);
    }
      
    if (!Lambda.exists(variants, function (v) return v.path.deviation.surplus.length == 0)) {
      pos.warning('All defined routes are overdetermined');
      for (v in variants)
        warn('Route captures surplus portion', v.path.pos, v.path.deviation.surplus);
    }
      
  }
  
  public static function seek<V:Variant>(variants:Array<V>, pos:Position) {
    for (v in variants)
      if (v.path.deviation.surplus.length == 0)
        return v;
        
    return pos.error('Cannot process route. See warnings.');
  }
}

@:structInit
class CallVariant extends Variant {
  public var method(default, null):Option<Method>;
}