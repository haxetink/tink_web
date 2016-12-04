package tink.web.macros;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import tink.macro.BuildCache;
import tink.http.Method;
import tink.web.macros.Route;
import tink.url.Portion;

using tink.MacroApi;

class Proxify { 
  
  static function makeEndpoint(from:RoutePath, sig:RouteSignature):Expr {
    
    function val(p:RoutePathPart)
      return switch p {
        case PCapture(name): macro (($i{name} : tink.Stringly) : tink.url.Portion);
        case PConst(s): macro $s;
      }
      
    var path = from.parts.map(val),
        query = [for (name in from.query.keys()) 
          macro new tink.CoreApi.NamedWith(${(name:Portion)}, ${val(from.query[name])})
        ];
    
    return macro this.endpoint.sub({
      path: $a{path},
      query: $a{query},
    });
  }
  
  static function seekVariant<V:Variant>(variants:Array<V>, pos:Position) {
    for (v in variants)
      if (v.path.deviation.surplus.length == 0)
        return v;
        
    return pos.error('Cannot process route. See warnings.');
  }
  
  static function build(ctx:BuildContext):TypeDefinition {
    var routes = RouteSyntax.read(ctx.type, ['application/json'], ['application/json']);
    return {
      pos: ctx.pos,
      pack: ['tink', 'web'],
      name: ctx.name,
      fields: [for (f in routes) {
        pos: f.field.pos,
        name: f.field.name,
        kind: FFun({
          args: [for (arg in f.signature) { name: arg.name, type: arg.type.toComplex(), opt: arg.optional }],
          expr: {
            
            var call = [];
            
            switch f.kind {
              case KCall(call):
                
                var v = seekVariant(call.variants, f.field.pos);
                
                var method = switch v.method {
                  case Some(m): m;
                  default: GET;
                }
                
                macro @:pos(f.field.pos) return ${makeEndpoint(v.path, f.signature)}.request(
                  this.client, 
                  cast $v{method}, 
                  '', 
                  ${switch call.response {
                    case RData(t): MimeType.readers.get(f.produces, t, f.field.pos);
                    default: macro function (header, body) return new tink.http.Response.IncomingResponse(header, body);
                  }}
                );
                
              case KSub(sub):
                
                var target = sub.target.toComplex(),
                    v = seekVariant(sub.variants, f.field.pos);
                
                macro @:pos(f.field.pos) return new tink.web.proxy.Remote<$target>(this.client, ${makeEndpoint(v.path, f.signature)});
            }
          },
          ret: null,
        }),
        access: [APublic],
      }],
      kind: TDClass('tink.web.proxy.Remote.RemoteBase'.asTypePath([TPType(ctx.type.toComplex())])),
    }
  }
  
  static function remote():Type 
    return BuildCache.getType('tink.web.proxy.Remote', build);
      
}