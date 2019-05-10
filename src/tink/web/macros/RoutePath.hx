package tink.web.macros;

import haxe.macro.Expr;
import haxe.macro.Type;
import tink.url.Portion;

using tink.MacroApi;

@:structInit
class RoutePath {
  public var pos(default, null):Position;
  public var parts(default, null):Array<RoutePathPart>;
  public var query(default, null):Map<String, RoutePathPart>;
  public var rest(default, null):RoutePathRest;
  public var deviation(default, null):{
    var surplus(default, null):Array<String>;
    var missing(default, null):Array<String>;
  }
  
  public static function make(fieldName:String, sig:RouteSignature, m:MetadataEntry):RoutePath 
    return switch m.params {
      case []: 
        
        make(fieldName, sig, { pos: m.pos, name: m.name, params: [fieldName.toExpr(m.pos)] });
        
      case [v]: 
        //TODO: check path against signature
        var sigMap = [for (s in sig.args) s.name => s];
        var url = tink.Url.parse(v.getString().sure());
        
        var parts = url.path.parts();
        
        var last = parts[parts.length - 1].raw;
        
        function capture(name) 
          return 
            switch sigMap[name] {
              case null | { kind: ACapture }: name;
              default: 
                m.pos.error(
                  'Cannot capture `$name` in URI because ' + 
                    if (RouteSignature.reserved.exists(name)) 
                      'it is reserved';
                    else
                      'its role was already determined in a @:params directive'
                );
            }
        
        var rest = 
          if (last == null) RNotAllowed;//TODO: report issue: having a null-case runs into a null-pointer exception because of the split below
          else switch last {                
            case '*': 
              parts.pop();
              RIgnore;
            case _.split('*') => ['', v]: 
              parts.pop();
              RCapture(capture(v));
            default:
              RNotAllowed;
          }
          
        if (!Route.metas.exists(m.name)) {
          switch rest {
            case RCapture(_):
              v.reject('cannot capture path rest in @${m.name}');
            case RIgnore:
              v.pos.warning('Path rest is always allowed for @${m.name}');
            default:
              rest = RIgnore;
          }
          
        }
        
        function part(of:Portion) 
          return switch of {
            case _.raw.split('$') => ['', name]:
              PCapture(capture(name));
            default:
              PConst(of);
          }
          
        var parts = [for (p in parts) part(p)],
            query = [for (q in url.query) q.name => part(q.value)];    
            
        var optional = new Map();
        var captured = [for (a in sig.args) switch a.kind {
          case ACapture: 
            if (a.optional)
              optional[a.name] = true;
            a.name;
          default: 
            continue;
        }];
        
        var surplus = [for (c in getCaptured(parts).concat(getCaptured(query))) if (!captured.remove(c)) c];
        var missing = [for (c in captured) if (!optional[c]) c];
        
        {
          pos: v.pos,
          parts: parts,
          query: query,
          deviation: { surplus: surplus, missing: missing, },
          rest: rest,
        }
        
      case v: 
        v[1].reject('only one path per route allowed');
    }
    
  static function getCaptured(a:Iterable<RoutePathPart>)
    return [for (p in a) switch p {
      case PConst(_): continue;
      case PCapture(name): name;
    }];
}


enum RoutePathRest {
  RIgnore;
  RCapture(name:String);
  RNotAllowed;
}

enum RoutePathPart {
  PConst(s:Portion);
  PCapture(name:String);
}