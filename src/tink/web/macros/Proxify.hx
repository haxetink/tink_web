package tink.web.macros;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import tink.macro.BuildCache;
import tink.http.Method;
import tink.web.macros.Route;
import tink.url.Portion;
import tink.web.macros.RouteSyntax;

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
        
    var combinedQuery = combine(route.field.pos, RouteSyntax.getPayload(route, PQuery), function (e, t) {
      return macro @:pos(e.pos) new tink.querystring.Builder<$t->tink.web.proxy.Remote.QueryParams>().stringify($e);
    });
    
    switch combinedQuery {
      case Some(v):
        query = macro @:pos(v.pos) $query.concat($v);
      case None:
    }
        
    var combinedHeader = combine(route.field.pos, RouteSyntax.getPayload(route, PHeader), function (e, t) {
      return macro @:pos(e.pos) new tink.querystring.Builder<$t->tink.web.proxy.Remote.HeaderParams>().stringify($e);
    });
    
    var headers = combinedHeader.or(macro null);
    
    return macro this.endpoint.sub({
      path: $a{path},
      query: $query,
      headers: $headers
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
      meta: [{name: ':pure', pos: ctx.pos}],
      fields: [for (f in routes) {
        pos: f.field.pos,
        name: f.field.name,
        kind: FFun({
          args: [for (arg in f.signature) if(arg.name != 'user') { name: arg.name, type: arg.type.toComplex(), opt: arg.optional }],
          expr: {
            var call = [];
            
            switch f.kind {
              case KCall(call):
                
                var v = seekVariant(call.variants, f.field.pos);
                
                var method = switch v.method {
                  case Some(m): m;
                  default: GET;
                }
                
                var contentType = None;
                
                var body = combine(f.field.pos, RouteSyntax.getPayload(f, PBody), function (expr, type) {
                  var ret = 
                    switch f.consumes {
                      case ['application/x-www-form-urlencoded']:
                        contentType = Some('application/x-www-form-urlencoded');
                        macro new tink.querystring.Builder<$type>().stringify(expr);
                      case v: 
                        var w = MimeType.writers.get(v, type.toType().sure(), f.field.pos);
                        contentType = Some(w.type);
                        w.generator(expr);
                    }
                    
                  return macro @:pos(expr.pos) $ret;
                }).or(macro '');
                
                var endPoint = makeEndpoint(v.path, f);
                
                switch contentType {
                  case Some(v):
                    var headers = [macro new tink.http.Header.HeaderField('content-type', $v{v})];
                    if(v != 'application/octet-stream') headers.push(macro new tink.http.Header.HeaderField('content-length', (__body__:Chunk).length));
                    endPoint = macro $endPoint.sub({ headers: $a{headers} });
                  case None:
                }
                
                var bodyType = contentType == None ? macro:tink.io.RealSource : macro:tink.Chunk;
                
                macro @:pos(f.field.pos) {
                  var __body__ = $body;
                  return $endPoint.request(
                    this.client, 
                    cast $v{method}, 
                    __body__, 
                    ${switch call.response {
                      case RData(t) if(t.unifiesWith(Context.getType('tink.io.Source.RealSource'))):
                        macro function (header, body):tink.core.Promise<tink.io.Source.RealSource> {
                          return 
                            if(header.statusCode >= 400)  
                              tink.io.Source.RealSourceTools.all(body)
                                .next(function(chunk) return new tink.core.Error(header.statusCode, chunk))
                            else
                              tink.core.Future.sync(tink.core.Outcome.Success(body));
                        }
                      case RData(_.reduce() => TEnum(_.get() => {pack: ['tink', 'core'], name: 'Noise'}, _)):
                        macro function(_) return Noise;
                      case RData(t):
                        switch RouteSyntax.asWebResponse(t) {
                          case Some(t):
                            macro function(header, body) 
                              return tink.io.Source.RealSourceTools.all(body)
                                .next(function(chunk) return ${MimeType.readers.get(f.produces, t, f.field.pos).generator(macro chunk)})
                                .next(function(parsed) return new tink.web.Response(header, parsed));
                          case None:
                            macro function(e) return ${MimeType.readers.get(f.produces, t, f.field.pos).generator(macro e)};
                        }
                      case ROpaque(t):
                        if (Context.getType('tink.http.Response.IncomingResponse').unifiesWith(t)) {
                          var ct = t.toComplex();
                          macro function (header, body):tink.core.Promise<$ct> return (new tink.http.Response.IncomingResponse(header, body):$ct);
                        }
                        else
                          macro function (header, body) return new tink.http.Response.IncomingResponse(header, body);
                    }}
                  );
                };
                
              case KSub(sub):
                
                var target = sub.target.toComplex(),
                    v = seekVariant(sub.variants, f.field.pos);
                
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
