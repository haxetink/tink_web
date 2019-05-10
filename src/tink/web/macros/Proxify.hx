package tink.web.macros;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import tink.macro.BuildCache;
import tink.http.Method;
import tink.url.Portion;
import tink.web.macros.Route;
import tink.web.macros.RoutePath;
import tink.web.macros.Variant;
import tink.web.macros.MimeType;
import tink.web.macros.RouteSignature;

using tink.CoreApi;
using tink.MacroApi;

class Proxify { 
  
  static function combine(pos:Position, payload:RoutePayload, write:Expr->ComplexType->Expr) 
    return switch payload {
      case Empty: 
        None;
      case SingleCompound(name, type):
        Some(write(macro $i{name}, type.toComplex()));
      case Mixed(sep, com, res):
        var ret = [];
        EObjectDecl(ret);//just for type inference
        for (f in sep)
          ret.push({ field: f.name, expr: macro $i{f.name} });
          
        for (c in com)
          switch c.value.reduce() {
            case TAnonymous(_.get() => { fields: fields } ):
              for (f in fields)
                ret.push({ field: f.name, expr: [c.name, f.name].drill() });
            default:
              throw 'assert';
          }
        Some(write(EObjectDecl(ret).at(pos), res));
    }
  
  static function makeEndpoint(from:RoutePath, route:Route):Expr {
    
    var sig = route.signature;
    
    function val(p:RoutePathPart)
      return switch p {
        case PCapture(name): macro (($i{name} : tink.Stringly) : tink.url.Portion);
        case PConst(s): macro $s;
      }
      
    var path = from.parts.map(val),
        query = [for (name in from.query.keys()) 
          macro new tink.CoreApi.NamedWith(${(name:Portion)}, ${val(from.query[name])})
        ].toArray();
        
    var combinedQuery = combine(route.field.pos, route.getPayload(PQuery), function (e, t) {
      return macro @:pos(e.pos) new tink.querystring.Builder<$t->tink.web.proxy.Remote.QueryParams>().stringify($e);
    });
    
    switch combinedQuery {
      case Some(v):
        query = macro @:pos(v.pos) $query.concat($v);
      case None:
    }
        
    var combinedHeader = combine(route.field.pos, route.getPayload(PHeader), function (e, t) {
      return macro @:pos(e.pos) new tink.querystring.Builder<$t->tink.web.proxy.Remote.HeaderParams>().stringify($e);
    });
    
    var headers = combinedHeader.or(macro null);
    
    return macro this.endpoint.sub({
      path: $a{path},
      query: $query,
      headers: $headers
    });
  }
  
  static function build(ctx:BuildContext):TypeDefinition {
    var routes = new RouteCollection(ctx.type, ['application/json'], ['application/json']);
    return {
      pos: ctx.pos,
      pack: ['tink', 'web'],
      name: ctx.name,
      meta: [{name: ':pure', pos: ctx.pos}],
      fields: [for (f in routes) {
        pos: f.field.pos,
        name: f.field.name,
        kind: FFun({
          args: {
            var args = [];
            for (arg in f.signature.args) switch arg.kind {
              case AUser(_) | AContext: // don't generate these args into proxy function signature
              case _: args.push({ name: arg.name, type: arg.type.toComplex(), opt: arg.optional });
            }
            args;
          },
          expr: {
            
            var call = [];
            
            switch f.kind {
              case KCall(c):
                
                var v = Variant.seek(c.variants, f.field.pos);
                
                var method = switch v.method {
                  case Some(m): m;
                  default: GET;
                }
                
                var contentType = None;
                
                var body = combine(f.field.pos, f.getPayload(PBody), function (expr, type) {
                  var w = MimeType.writers.get(f.consumes, type.toType().sure(), f.field.pos);
                  contentType = Some(w.type);
                  var writer = w.generator;
                  return macro @:pos(expr.pos) ${writer}($expr);
                }).or(macro '');
                
                var endPoint = makeEndpoint(v.path, f);
                
                switch contentType {
                  case Some(v):
                    endPoint = macro $endPoint.sub({ headers: [
                      new tink.http.Header.HeaderField('content-type', $v{v}),
                      new tink.http.Header.HeaderField('content-length', __body__.length),
                    ]});
                  case None:
                }
                
                macro @:pos(f.field.pos) {
                  var __body__:tink.Chunk = $body;
                  return $endPoint.request(
                    this.client, 
                    cast $v{method}, 
                    __body__, 
                    ${switch f.signature.result.asCallResponse() {
                      case RNoise:
                        macro function(header, body):tink.core.Promise<tink.core.Noise> {
                          return 
                            if(header.statusCode >= 400)  
                              tink.io.Source.RealSourceTools.all(body)
                                .next(function(chunk) return new tink.core.Error(header.statusCode, chunk))
                            else
                              tink.core.Promise.NOISE;
                        }
                      case RData(t):
                        MimeType.readers.get(f.produces, t, f.field.pos).generator;
                        
                      case ROpaque(OParsed(res, t)):
                        var ct = res.toComplex();
                        macro function(header, body) 
                          return tink.io.Source.RealSourceTools.all(body)
                            .next(function(chunk) return ${MimeType.readers.get(f.produces, t, f.field.pos).generator}(chunk))
                            .next(function(parsed):$ct return new tink.web.Response(header, parsed));
                      
                      case ROpaque(ORaw(t)):
                        if (Context.getType('tink.http.Response.IncomingResponse').unifiesWith(t)) {
                          var ct = t.toComplex();
                          macro function (header, body):tink.core.Promise<$ct> return (new tink.http.Response.IncomingResponse(header, body):$ct);
                        }
                        else
                          macro function (header, body) return new tink.http.Response.IncomingResponse(header, body);
                      
                    }}
                  );
                };
                
              case KSub(variants):
                
                var target = f.signature.result.asSubTarget().toComplex(),
                    v = Variant.seek(variants, f.field.pos);
                
                macro @:pos(f.field.pos) return new tink.web.proxy.Remote<$target>(this.client, ${makeEndpoint(v.path, f)});
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
