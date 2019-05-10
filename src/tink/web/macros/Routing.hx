package tink.web.macros;

import haxe.ds.Option;
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;
import tink.macro.BuildCache;
import tink.http.Method;
import tink.web.macros.Route;
import tink.web.macros.RouteCollection;
import tink.web.macros.RoutePath;
import tink.web.macros.RouteSignature;
import tink.web.macros.Variant;
import tink.web.macros.MimeType;
import tink.web.routing.Response;

using tink.MacroApi;
using tink.CoreApi;
using Lambda;

class Routing { 
  
  var routes:RouteCollection;
  var auth:Option<{ user: Type, session: Type }>;
  
  var cases:Array<Case> = [];
  var fields:Array<Field> = [];
  
  var depth:Int = 0;
  var named:Array<String> = [];
  var nameIndex:Map<String, Int> = new Map();
  var ctx:ComplexType;
  
  function new(routes, auth) {
    
    this.routes = routes;
    this.auth = auth;
    firstPass();
    ctx = 
      switch auth {
        case Some(a):
          var user = a.user.toComplex(),
              session = a.session.toComplex();
          macro : tink.web.routing.Context.AuthedContext<$user, $session>;
        case None:
          macro : tink.web.routing.Context;
      }
  }
  
  function firstPass() {
    //during the first pass we skim all routes to map out their depths and named parameters
    for (route in routes) {
      
      function skim(variants:Iterable<Variant>) 
        for (v in variants) {
          
          switch v.path.parts.length {
            case sup if (sup > depth):
              depth = sup;
            default:
          }
          
          for (name in v.path.query.keys())
            if (!nameIndex.exists(name))
              nameIndex[name] = named.push(name) - 1;
        }
      
      switch route.kind {
        case KSub(variants):
          skim(variants);
        case KCall(c):
          skim(c.variants);
      }
      
    } 
    
  }
  
  function makeCase(field:String, funcArgs:Array<FunctionArg>, v:Variant, method:Option<Method>):Case {
    if (v.path.deviation.missing.length > 0)
      v.path.pos.error('Route does not capture all required variables. See warnings.');
      
    var pattern = [
      switch method {
        case Some(m): macro $i{m};
        case None: IGNORE;
      },
    ];
    
    for (i in 0...depth * 2 + named.length * 2 + 1)
      pattern.push(IGNORE);
      
    for (i in 0...v.path.parts.length)
      pattern[i + 1 + depth] = macro true;
      
    if (v.path.rest == RNotAllowed)
      pattern[depth + 1 + v.path.parts.length] = macro false;
      
    var captured = new Map();
      
    function part(p)
      return switch p {
        case PConst(v): 
          macro $v{v.toString()};                
        case PCapture(name): 
          captured[name] = true;
          macro $i{name};
      }
      
    for (i in 0...v.path.parts.length)
      pattern[i + 1] = part(v.path.parts[i]);
      
    for (name in v.path.query.keys()) {
      
      var index = nameIndex[name];
      
      pattern[2 + index + depth * 2] = macro true;
      pattern[2 + index + depth * 2 + named.length] = part(v.path.query[name]);
    }
    
    var callArgs = [for (a in funcArgs) 
      switch a.name {
        case '__depth__': 
          macro $v{v.path.parts.length};
        case 'user' | 'session': 
          macro $i{a.name};
        default:
          if (a == funcArgs[0] || captured[a.name]) 
            macro $i{a.name}
          else 
            macro null;
      }
    ];

    return { 
      values: [pattern.toArray(v.path.pos)],
      expr: macro @:pos(v.path.pos) this.$field($a{callArgs}),
    } 
  }  

  function switchTarget() {
    var ret = [macro ctx.header.method];
    
    for (i in 0...depth) 
      ret.push(macro ctx.part($v { i } ));
      
    for (i in 0...depth+1) 
      ret.push(macro l > $v{i});
      
    for (name in named) 
      ret.push(macro ctx.hasParam($v{name}));
    
    for (name in named) 
      ret.push(macro ctx.param($v{name}));
      
    return ret.toArray();
  }
  
  function restrict(restricts:Array<Expr>, e:Expr) 
    return 
      switch [restricts, auth] {
        case [[], _]: 
          e;
        case [v, None]:
          v[0].pos.error('restriction cannot be applied because no session handling is provided');
        case [restricts, Some(_)]: 
          
          for (v in restricts)
            e = macro @:pos(v.pos) (${substituteThis(v)} : tink.core.Promise<Bool>).next(
              function (authorized)
                return 
                  if (authorized) $e;
                  else new tink.core.Error(Forbidden, 'forbidden')
            );    
            
          macro ctx.user.get().next(function (o) return switch o {
            case Some(user):
              $e;
            case None:
              new tink.core.Error(Unauthorized, 'not authorized');
          });
      }
  
  function generate(name:String, pos:Position) {
    
    secondPass();

    var theSwitch = ESwitch(
      switchTarget(), 
      cases, 
      macro @:pos(pos) new tink.core.Error(NotFound, 'Not Found: [' + ctx.header.method + '] ' + ctx.header.url.pathWithQuery)
    ).at(pos);
    
    theSwitch = restrict(routes.restricts, theSwitch);
      
    var target = routes.type.toComplex();
    
    var ret = 
      macro class $name {
        
        var target:$target;
        
        public function new(target) {
          this.target = target;
        }
        
        public function route(ctx:$ctx):tink.core.Promise<tink.http.Response.OutgoingResponse> {
          var l = ctx.pathLength;
          return $theSwitch;
        }
      };
    
    for (f in fields)
      ret.fields.push(f);
    
    return ret;    
  }
  
  function routeMethod(route:Route) {
    var separate = new Map<ParamLocation, Array<Field>>(),
        compound = new Map<ParamLocation, Array<Named<Type>>>(),
        pos = route.field.pos,
        callArgs = [],
        funcArgs:Array<FunctionArg> = [{
          name: 'ctx',
          type: ctx,
        }];
        
    var field = route.field.name;
            
    var beforeBody = [function (e) return restrict(route.restricts, e)];
    
    for (arg in route.signature.args) {
      
      var argExpr = arg.name.resolve();

      switch arg.kind {
        case ACapture:

          var expected = arg.type.toComplex();
          var enumAbstract = switch arg.type {
            case TAbstract(_.get() => {module: module, name: name, type: underlying, meta: meta, impl: impl}, _) if(meta.has(':enum')):
              var path = ('$module.$name').split('.');
              Some({
                underlying: underlying, 
                fields: impl.get().statics.get()
                  .filter(function(s) return s.meta.has(':enum') && s.meta.has(':impl'))
                  .map(function(s) return macro $p{path.concat([s.name])})
              });
            case _:
              None;
          }
          
          var parsed = switch enumAbstract {
            case Some({fields: fields, underlying: underlying}):
              var ct = underlying.toComplex();
              ESwitch(
                macro (s:$ct), 
                [{expr: macro cast s, values: fields}],
                macro throw 'Invalid value "' + s + '" for field: ' + $v{arg.name}
              ).at(route.field.pos);
            case None:
              macro @:pos(route.field.pos) s;
          }
          
          argExpr = macro @:pos(route.field.pos) switch $argExpr.parse(function (s:tink.Stringly):$expected return $parsed) {
            case Success(v): v;
            case Failure(e): return tink.core.Promise.lift(e);
          }

          funcArgs.push({
            name: arg.name,
            type: macro : tink.Stringly,
            opt: arg.optional,
          });
          
        case AParam(t, loc, PCompound):
          
          if (!compound.exists(loc))
            compound[loc] = [];
            
          compound[loc].push(new Named(arg.name, t));
          
        case AParam(t, loc, PSeparate):
          
          if (!separate.exists(loc))
            separate[loc] = [];
            
          separate[loc].push({
            name: arg.name,
            pos: route.field.pos,
            kind: FVar(t.toComplex()),
          });
          
        case AUser(u):        

          beforeBody.push(function (e:Expr) {
            
            switch u.getID() {
              case 'haxe.ds.Option':
              default:
                e = macro @:pos(e.pos) switch user {
                  case Some(user): $e;
                  case None: new tink.core.Error(Unauthorized, 'unauthorized');
                }
            }          
            
            return macro @:pos(e.pos) ctx.user.get().next(function (user) return $e);
          });
        case AContext:
          var name = arg.name;
          beforeBody.push(function (e:Expr) return macro @:pos(e.pos) {
            var $name = ctx;
            $e;
          });
        default:
          
          throw 'not implemented: '+arg.kind;
      }
      
      callArgs.push(
        if (arg.optional) 
          macro switch $i{arg.name} {
            case null: null;
            default: $argExpr;
          }
        else argExpr
      );        
    }
     
    var result = macro @:pos(pos) this.target.$field;
    
    if (route.field.type.reduce().match(TFun(_, _)))
      result = macro @:pos(pos) $result($a{callArgs});
    
    result = 
      switch route.kind {
        case KSub(s):
          funcArgs.push({
            name: '__depth__',
            type: macro : Int,
          });
          
          var target = route.signature.result.asSubTarget().toComplex();
          
          var router = switch auth {
            case None:
              macro @:pos(pos) new tink.web.routing.Router<$target>(__target__);
            case Some(_.session.toComplex() => s):
              macro @:pos(pos) new tink.web.routing.Router<$s, $target>(__target__);
          }
          beforeBody.push(function (e) return macro {
            var ctx = ctx.sub(__depth__);
            $e;
          });
          //trace(result.toString());
          macro @:pos(pos) {
            
            tink.core.Promise.lift($result)
              .next(function (__target__:$target) 
                return $router.route(ctx)
              );
          }
        case KCall({variants: c, statusCode: statusCode, headers: headers, html: html}):
          var headers = [for(h in headers) macro new tink.http.Header.HeaderField(${h.name}, ${h.value})];
          switch route.signature.result.asCallResponse() {
            case RNoise:
              macro @:pos(pos) tink.core.Promise.lift($result).next(
                function (_):tink.core.Promise<tink.web.routing.Response> {
                  return tink.web.routing.Response.empty();
                }
              );
            case RData(t):
              var ct = t.toComplex();
              var formats = [];
              
              switch html {
                case Some(v):
                  formats.push(
                    macro @:pos(v.pos) if (ctx.accepts('text/html')) 
                      return tink.core.Promise.lift(${substituteThis(v)}(__data__)).next(
                        function (d) return tink.web.routing.Response.textual('text/html', d)
                      )
                  );
                case None:
              }
              
              for (fmt in route.produces) 
                formats.push(
                  macro @:pos(pos) if (ctx.accepts($v{fmt}))
                    return tink.web.routing.Response.textual(
                      $statusCode,
                      $v{fmt},
                      ${MimeType.writers.get([fmt], t, pos).generator}(__data__),
                      $a{headers}
                    )
                );
                
              macro @:pos(pos) tink.core.Promise.lift($result).next(
                function (__data__:$ct):tink.core.Promise<tink.web.routing.Response> {
                  $b{formats};
                  return new tink.core.Error(UnsupportedMediaType, 'Unsupported Media Type');
                }
              );
            
            case ROpaque(OParsed(res, t)):
              // @:statusCode and @:header is ignored here, we should probably error/warn
              var ct = res.toComplex();
              var formats = [];
              
              switch html {
                case Some(v):
                  formats.push(
                    macro @:pos(v.pos) if (ctx.accepts('text/html')) 
                      return tink.core.Promise.lift(${substituteThis(v)}(__data__)).next(
                        function (d) return tink.web.routing.Response.textual('text/html', d)
                      )
                  );
                case None:
              }
              
              for (fmt in route.produces) 
                formats.push(
                  macro @:pos(pos) if (ctx.accepts($v{fmt})) return ${{
                    macro new tink.http.Response.OutgoingResponse(
                      __data__.header.concat([new tink.http.Header.HeaderField(CONTENT_TYPE, $v{fmt})]),
                      ${MimeType.writers.get([fmt], t, pos).generator}(__data__.body)
                    );
                  }});
                
              macro @:pos(pos) tink.core.Promise.lift($result).next(
                function (__data__:$ct):tink.core.Promise<tink.web.routing.Response> {
                  $b{formats};
                  return new tink.core.Error(UnsupportedMediaType, 'Unsupported Media Type');
                }
              );
              
            case ROpaque(ORaw(_.toComplex() => t)):
              var e = macro @:pos(pos) tink.core.Promise.lift($result)
                .next(function (v:$t):tink.web.routing.Response return v);
              switch [statusCode, headers] {
                case [macro 200, []]:
                  e;
                case [macro 200, _]:
                  macro $e.next(function(res) return new tink.http.Response.OutgoingResponse(
                    res.header.concat(${macro $a{headers}}),
                    res.body
                  ));
                case [_, []]:
                  macro $e.next(function (res) return new tink.http.Response.OutgoingResponse(
                    new tink.http.Response.ResponseHeader($statusCode, $statusCode, @:privateAccess res.header.fields, res.header.protocol),
                    res.body
                  ));
                case _: 
                  macro $e.next(function (res) return new tink.http.Response.OutgoingResponse(
                    new tink.http.Response.ResponseHeader($statusCode, $statusCode, @:privateAccess res.header.fields.concat(${macro $a{headers}}), res.header.protocol),
                    res.body
                  ));
              }
          }
      }
      
    for (loc in [PBody, PQuery, PHeader]) {
      
      var locName = loc.getName().substr(1).toLowerCase();
      var locVar = '__${locName}__';
      
      result = 
        switch [loc, route.getPayload(loc)] {
          case [_, Empty]:
            
            result;
            
          case [PBody, SingleCompound(name, is(_, 'haxe.io.Bytes') => true)]:
            
            macro @:pos(pos) 
              ctx.allRaw()
                .next(function ($name:tink.Chunk) 
                  return $result
                );            
                
          case [PBody, SingleCompound(name, is(_, 'String') => true)]:
            
            macro @:pos(pos) 
              ctx.allRaw()
                .next(function ($name:tink.Chunk) {
                  var $name = $i{name}.toString();
                  return $result;
                });
                
          case [PBody, SingleCompound(name, is(_, 'tink.io.Source') => true)]:
            
            macro @:pos(pos) {
              var $name = ctx.rawBody;
              $result;
            }
            
          case [_, SingleCompound(name, _.toComplex() => t)]:
            
            macro @:pos(pos) return ${parse(loc, route, t)}.next(function ($name) {
              return $result;
            });
            
          case [_, Mixed(separate, compound, t)]:
            
            function dissect() {
              var target = locVar.resolve();
              var parts:Array<Var> = [];
              
              if (separate != null)
                for (s in separate)
                  parts.push({ name: s.name, type: null, expr: target.field(s.name) });
              
              for (c in compound) 
                if (c.name != '')
                  switch c.value.reduce().toComplex() {//TODO: deduplicate - we're getting this above already
                    case TAnonymous(fields):
                      parts.push({ 
                        name: c.name, 
                        type: TAnonymous(fields),
                        expr: EObjectDecl([for (f in fields) {
                          field: f.name,
                          expr: target.field(f.name)
                        }]).at(),
                      });
                    case v:
                      throw 'assert';
                  };
                
              return EVars(parts).at();
            }  
            
            macro @:pos(pos) return ${parse(loc, route, t)}.next(function ($locVar:$t) {
              ${dissect()};
              return $result;
            });
        }
        
      if (loc == PBody) 
        for (f in beforeBody)
          result = f(result);
    }    
    
    var f:Function = {
      args: funcArgs,
      expr: macro @:pos(result.pos) return $result,
      ret: null,
    }
    
    fields.push({
      pos: pos,
      name: route.field.name,
      kind: FFun(f),
    });
    
    return funcArgs;
  }
  
  function secondPass() 
    for (route in routes) {
      var args = routeMethod(route);
            
      switch route.kind {
        case KCall(c):
          for (v in c.variants)
            cases.push(makeCase(route.field.name, args, v, v.method));
        case KSub(variants):
          for (v in variants)  
            cases.push(makeCase(route.field.name, args, v, None));
      }
    }
  
  static var IGNORE = macro _;
  
  static function substituteThis(e:Expr)
    return switch e {
      case macro this.$field: 
        macro @:pos(e.pos) (@:privateAccess this.target.$field);
      case macro this: 
        macro @:pos(e.pos) (@:privateAccess this.target);
      default:
        e.map(substituteThis);
    }
  
  static function is(t:Type, name:String)
    return Context.getType(name).unifiesWith(t);//This is odd ... https://github.com/haxetink/tink_web/issues/69
    
  static function parse(loc:ParamLocation, route:Route, payload:ComplexType):Expr 
    return
      switch loc {
        case PBody:
          
          bodyParser(payload, route);
          
        case PHeader:
          
          macro @:pos(route.field.pos) tink.core.Promise.lift(
            new tink.querystring.Parser<tink.http.Header.HeaderValue->$payload>().tryParse(ctx.headers())
          );
          
        case PQuery:
          
          macro @:pos(route.field.pos) tink.core.Promise.lift(
            new tink.querystring.Parser<$payload>().tryParse(ctx.header.url.query)
          );
      }     
      
  static function bodyParser(payload:ComplexType, route:Route) {
    var cases:Array<Case> = [],
        structured = [],
        pos = route.field.pos;
    
    for (type in route.consumes) 
      switch type {
        case 'application/x-www-form-urlencoded' #if tink_multipart | 'multipart/form-data' #end: 
          structured.push(macro @:pos(pos) $v{type});
        default: 
          cases.push({ 
            values: [macro $v{type}],
            expr: macro @:pos(pos) ctx.allRaw().next(
              function (b) return ${MimeType.readers.get([type], payload.toType(pos).sure(), pos).generator}(b.toString())
            )
          });
      }
    
    switch structured {
      case []:
      case v:
        cases.unshift({ 
          values: structured, 
          expr: macro @:pos(pos) ctx.parse().next(function (pairs)
            return new tink.querystring.Parser<tink.web.forms.FormField->$payload>().tryParse(pairs)
          ),
        });
    }
    
    var contentType = macro @:pos(pos) switch ctx.header.contentType() {
      case Success(v): v.fullType;
      default: 'application/json';
    }
    
    cases.push({ 
      values: [macro invalid],
      expr: macro new tink.core.Error(NotAcceptable, 'Cannot process Content-Type '+invalid),
    });
    
    return macro @:pos(pos) (
      ${ESwitch(contentType, cases, null).at(pos)} 
        : 
      tink.core.Promise<$payload>
    );  
  }
  
  static function build(ctx:BuildContextN) {
    
    var auth = None;
    
    var target = switch ctx.types {
      case []:
        switch Context.getCallArguments() {
          case null | []:
            ctx.pos.error('You must either specify a target type as type parameter or a target object as constructor argument');
          case [v]:
            v.typeof().sure();
          case _:
            ctx.pos.error('too many arguments - only one expected');
        }
      case [t]: t;
      case [s, t]:
        var sc = s.toComplex();
        
        var user = 
          (macro @:pos(ctx.pos) {
            var x:$sc = null;
            function test<U>(s:tink.web.Session<U>):U {
              return null;
            }
            test(x);
          }).typeof().sure();
        
        auth = Some({ session: s, user: user });
        t;
      default:
        ctx.pos.error('Invalid usage');
    }
    
    return new Routing(
      new RouteCollection(
        target,
        [
          #if tink_multipart 'multipart/form-data', #end
          'application/x-www-form-urlencoded', 
          'application/json'
        ], 
        ['application/json']
      ),
      auth
    ).generate(ctx.name, ctx.pos);
  }
  
  static function apply() {
    return BuildCache.getTypeN('tink.web.routing.Router', build);
  }
  
}
